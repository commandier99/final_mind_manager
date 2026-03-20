import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../features/notifications/datasources/models/notification_model.dart';
import '../../features/notifications/datasources/services/notification_service.dart';
import '../../features/tasks/datasources/models/task_model.dart';
import '../../features/thoughts/datasources/models/thought_model.dart';
import '../../features/thoughts/datasources/services/thought_service.dart';

class TaskDeadlineReminderService {
  TaskDeadlineReminderService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ThoughtService? thoughtService,
    NotificationService? notificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _thoughtService = thoughtService ?? ThoughtService(),
       _notificationService = notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ThoughtService _thoughtService;
  final NotificationService _notificationService;

  static Timer? _periodicTimer;

  void startPeriodicReminders({Duration interval = const Duration(minutes: 1)}) {
    if (_periodicTimer != null) return;
    checkAndCreateReminders();
    _scheduleNextCheck(interval);
  }

  void stopPeriodicReminders() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  void _scheduleNextCheck(Duration interval) {
    final now = DateTime.now();
    final nextCheckTime = now.add(interval).subtract(
      Duration(
        milliseconds: now.millisecondsSinceEpoch % interval.inMilliseconds,
      ),
    );
    final timeUntilNextCheck = nextCheckTime.difference(now);

    _periodicTimer = Timer(timeUntilNextCheck, () async {
      await checkAndCreateReminders();
      _scheduleNextCheck(interval);
    });
  }

  Future<void> checkAndCreateReminders() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final now = DateTime.now();
      final userId = currentUser.uid;
      final snapshot = await _firestore
          .collection('tasks')
          .where('taskAssignedTo', isEqualTo: userId)
          .where('taskIsDone', isEqualTo: false)
          .where('taskIsDeleted', isEqualTo: false)
          .where(
            'taskDeadline',
            isGreaterThan: Timestamp.fromDate(
              now.subtract(const Duration(days: 7)),
            ),
          )
          .get();

      for (final doc in snapshot.docs) {
        try {
          final task = Task.fromMap(doc.data(), doc.id);
          if (task.taskDeadline == null) continue;
          await _processTask(task, now);
        } catch (e) {
          debugPrint(
            '[TaskDeadlineReminderService] Failed to process task ${doc.id}: $e',
          );
        }
      }
    } catch (e) {
      debugPrint(
        '[TaskDeadlineReminderService] Failed to check reminders: $e',
      );
    }
  }

  Future<void> _processTask(Task task, DateTime now) async {
    final deadline = task.taskDeadline;
    if (deadline == null || task.taskAssignedTo.trim().isEmpty) return;

    final difference = deadline.difference(now);

    if (difference.isNegative) {
      await _createDeadlineReminder(task: task, window: 'missed', now: now);
      return;
    }

    if (difference.inHours <= 1 && difference.inMinutes > 0) {
      await _createDeadlineReminder(task: task, window: '1h', now: now);
      return;
    }

    if (difference.inHours <= 24 && difference.inHours > 1) {
      await _createDeadlineReminder(task: task, window: '24h', now: now);
    }
  }

  Future<void> _createDeadlineReminder({
    required Task task,
    required String window,
    required DateTime now,
  }) async {
    final assigneeId = task.taskAssignedTo.trim();
    if (assigneeId.isEmpty || assigneeId == 'None') return;

    final eventKey = 'deadline_reminder:${task.taskId}:$window:$assigneeId';
    final boardTitle = (task.taskBoardTitle ?? '').trim();
    final title = _reminderTitle(window);
    final message = _reminderMessage(task: task, boardTitle: boardTitle, window: window);

    final thought = Thought(
      thoughtId: '',
      type: Thought.typeReminder,
      status: Thought.statusOpen,
      scopeType: Thought.scopeTask,
      boardId: task.taskBoardId,
      taskId: task.taskId,
      authorId: assigneeId,
      authorName: task.taskAssignedToName.trim().isEmpty
          ? 'Unknown'
          : task.taskAssignedToName.trim(),
      targetUserId: assigneeId,
      targetUserName: task.taskAssignedToName.trim().isEmpty
          ? 'Unknown'
          : task.taskAssignedToName.trim(),
      title: title,
      message: message,
      createdAt: now,
      updatedAt: now,
      metadata: {
        'source': 'task_deadline_reminder_service',
        'systemGenerated': true,
        'reminderKind': 'deadline',
        'reminderWindow': window,
        'eventKey': eventKey,
        'boardTitle': boardTitle,
        'taskTitle': task.taskTitle,
        if (task.taskDeadline != null)
          'deadline': task.taskDeadline!.toIso8601String(),
      },
    );

    try {
      final thoughtId = await _thoughtService.createThought(thought);
      await _notificationService.createNotification(
        AppNotification(
          notificationId: '',
          recipientUserId: assigneeId,
          title: title,
          message: message,
          type: 'thought_reminder_deadline_$window',
          deliveryStatus: AppNotification.deliveryPending,
          isRead: false,
          isDeleted: false,
          createdAt: now,
          updatedAt: now,
          actorUserId: assigneeId,
          actorUserName: thought.authorName,
          boardId: task.taskBoardId.isEmpty ? null : task.taskBoardId,
          taskId: task.taskId,
          thoughtId: thoughtId,
          eventKey: eventKey,
          metadata: {
            'thoughtType': Thought.typeReminder,
            'systemGenerated': true,
            'reminderKind': 'deadline',
            'reminderWindow': window,
          },
        ),
      );

      if (window == 'missed') {
        await _markTaskDeadlineMissed(task);
      }
    } catch (_) {
      // Duplicate or transient failures should not break the reminder loop.
    }
  }

  Future<void> _markTaskDeadlineMissed(Task task) async {
    if (task.taskDeadlineMissed) return;
    try {
      await _firestore.collection('tasks').doc(task.taskId).update({
        'taskDeadlineMissed': true,
        'taskReminderSentAt': Timestamp.now(),
      });
    } catch (_) {
      // Deadline reminder can still exist even if the task flag update fails.
    }
  }

  String _reminderTitle(String window) {
    switch (window) {
      case '1h':
        return 'Task Due In 1 Hour';
      case 'missed':
        return 'Task Deadline Missed';
      case '24h':
      default:
        return 'Task Due In 24 Hours';
    }
  }

  String _reminderMessage({
    required Task task,
    required String boardTitle,
    required String window,
  }) {
    final taskTitle = task.taskTitle.trim().isEmpty ? 'Task' : task.taskTitle.trim();
    final boardLabel = boardTitle.isEmpty ? 'your board' : boardTitle;
    switch (window) {
      case '1h':
        return '"$taskTitle" from $boardLabel is due in 1 hour.';
      case 'missed':
        return 'You missed the deadline for "$taskTitle" from $boardLabel.';
      case '24h':
      default:
        return '"$taskTitle" from $boardLabel is due in 24 hours.';
    }
  }
}
