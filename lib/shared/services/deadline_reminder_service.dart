import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../features/tasks/datasources/models/task_model.dart';
import 'notification_dispatch_service.dart';

class DeadlineReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final NotificationDispatchService _dispatchService;

  DeadlineReminderService(FlutterLocalNotificationsPlugin localNotifications) {
    _dispatchService = NotificationDispatchService(localNotifications);
  }

  static Timer? _periodicTimer;

  /// Start periodic checks based on actual clock time
  void startPeriodicReminders({Duration interval = const Duration(minutes: 1)}) {
    if (_periodicTimer != null) return;

    print(
      '[DeadlineReminder] Starting periodic reminders (every ${interval.inMinutes} min)',
    );

    // Run once immediately when starting
    checkAndSendReminders();

    // Schedule the first check to align with clock time
    _scheduleNextCheck(interval);
  }

  /// Schedule the next check based on actual clock time
  void _scheduleNextCheck(Duration interval) {
    final now = DateTime.now();

    // Calculate next check time aligned to the interval
    final nextCheckTime = now.add(interval).subtract(
      Duration(
        milliseconds: now.millisecondsSinceEpoch % interval.inMilliseconds,
      ),
    );

    final timeUntilNextCheck = nextCheckTime.difference(now);

    print(
      '[DeadlineReminder] Next check scheduled in ${timeUntilNextCheck.inSeconds}s',
    );

    _periodicTimer = Timer(timeUntilNextCheck, () async {
      await checkAndSendReminders();
      _scheduleNextCheck(interval);
    });
  }

  /// Stop periodic checks (optional when app goes to background)
  void stopPeriodicReminders() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    print('[DeadlineReminder] Stopped periodic reminders');
  }

  /// Check for upcoming deadlines and send reminders
  /// Sends reminders at: 1 day before, 1 hour before, and when deadline is missed
  Future<void> checkAndSendReminders() async {
    try {
      print('[DeadlineReminder] Starting deadline reminder check...');

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('[DeadlineReminder] No user logged in');
        return;
      }

      final userId = currentUser.uid;
      print('[DeadlineReminder] Checking reminders for user: $userId');

      final now = DateTime.now();
      final allTasksSnapshot = await _firestore
          .collection('tasks')
          .where('taskAssignedTo', isEqualTo: userId)
          .where('taskIsDone', isEqualTo: false)
          .where('taskIsDeleted', isEqualTo: false)
          .where(
            'taskDeadline',
            isGreaterThan: Timestamp.fromDate(now.subtract(const Duration(days: 7))),
          )
          .get();

      print('[DeadlineReminder] Found ${allTasksSnapshot.docs.length} incomplete tasks');

      var remindersCount = 0;

      for (final doc in allTasksSnapshot.docs) {
        try {
          final taskData = Task.fromMap(doc.data(), doc.id);

          if (taskData.taskDeadline == null) {
            print('[DeadlineReminder] Skipping ${taskData.taskTitle} (${taskData.taskId}): no deadline');
            continue;
          }

          final timeUntilDeadline = taskData.taskDeadline!.difference(now);
          final isPastDeadline = timeUntilDeadline.isNegative;

          print(
            '[DeadlineReminder] Task ${taskData.taskTitle} (${taskData.taskId}) | '
            'deadline=${taskData.taskDeadline} | timeUntil=${timeUntilDeadline.inMinutes}m | '
            'reminderSentAt=${taskData.taskReminderSentAt} | pastDue=$isPastDeadline',
          );

          // Check 1: Missed deadline
          if (isPastDeadline) {
            final lastReminder = taskData.taskReminderSentAt;
            final deadline = taskData.taskDeadline!;
            final shouldSendMissed =
                lastReminder == null || lastReminder.isBefore(deadline);

            if (shouldSendMissed) {
              await _sendMissedDeadlineNotification(taskData);
              await _firestore.collection('tasks').doc(doc.id).update({
                'taskReminderSentAt': FieldValue.serverTimestamp(),
                'taskDeadlineMissed': true,
              });
              remindersCount++;
              print('[DeadlineReminder] Missed deadline notification sent for: ${taskData.taskTitle}');
            }
            continue;
          }

          // Check 2: 1 hour before deadline
          if (timeUntilDeadline.inHours <= 1 && timeUntilDeadline.inMinutes > 0) {
            if (taskData.taskReminderSentAt == null ||
                !_wasReminderSentWithinHour(taskData.taskReminderSentAt!)) {
              await _sendOneHourReminderNotification(taskData, timeUntilDeadline);
              await _firestore.collection('tasks').doc(doc.id).update({
                'taskReminderSentAt': FieldValue.serverTimestamp(),
              });
              remindersCount++;
              print('[DeadlineReminder] 1-hour reminder sent for: ${taskData.taskTitle}');
            }
            continue;
          }

          // Check 3: 1 day before deadline
          if (timeUntilDeadline.inHours <= 24 &&
              timeUntilDeadline.inHours > 1 &&
              (taskData.taskReminderSentAt == null ||
                  !_isSameDay(taskData.taskReminderSentAt!, now))) {
            await _sendOneDayReminderNotification(taskData, timeUntilDeadline);
            await _firestore.collection('tasks').doc(doc.id).update({
              'taskReminderSentAt': FieldValue.serverTimestamp(),
            });
            remindersCount++;
            print('[DeadlineReminder] 1-day reminder sent for: ${taskData.taskTitle}');
          }
        } catch (e) {
          print('[DeadlineReminder] Error processing task: $e');
        }
      }

      print('[DeadlineReminder] Completed - sent $remindersCount reminders');
    } catch (e) {
      print('[DeadlineReminder] Error checking reminders: $e');
    }
  }

  bool _isSameDay(DateTime sentTime, DateTime now) {
    return sentTime.year == now.year &&
        sentTime.month == now.month &&
        sentTime.day == now.day;
  }

  bool _wasReminderSentWithinHour(DateTime sentTime) {
    final now = DateTime.now();
    return now.difference(sentTime).inMinutes < 60;
  }

  Future<void> _sendMissedDeadlineNotification(Task task) async {
    try {
      final timeOverdue = DateTime.now().difference(task.taskDeadline!);
      final formattedTime = _formatTimeOverdue(timeOverdue);
      final boardContext = await _resolveBoardContext(task);
      final boardTitle = boardContext['boardTitle'] ?? 'Unknown Board';
      final boardManagerName =
          boardContext['boardManagerName'] ?? 'Unknown Manager';
      final taskSummary = _buildTaskSummary(task.taskDescription);
      final message =
          '${task.taskTitle} from $boardTitle by $boardManagerName was due $formattedTime ago.';

      await _dispatchService.sendNotificationToUser(
        userId: task.taskAssignedTo,
        title: 'Missed Deadline',
        body: message,
        category: 'task_deadline',
        data: {
          'taskId': task.taskId,
          'taskTitle': task.taskTitle,
          'deadline': task.taskDeadline?.toIso8601String() ?? '',
          'boardTitle': boardTitle,
          'boardManagerName': boardManagerName,
          'taskPriorityLevel': task.taskPriorityLevel,
          if (taskSummary.isNotEmpty) 'taskSummary': taskSummary,
          'reminderType': 'missed_deadline',
          'timeOverdue': timeOverdue.inHours.toString(),
        },
      );

      print('[DeadlineReminder] Missed deadline notification sent for ${task.taskTitle}');
    } catch (e) {
      print('[DeadlineReminder] Error sending missed deadline notification: $e');
    }
  }

  Future<void> _sendOneHourReminderNotification(
    Task task,
    Duration timeUntilDeadline,
  ) async {
    try {
      final minutes = timeUntilDeadline.inMinutes;
      final timeText = minutes < 1 ? 'a few moments' : '$minutes minutes';
      final boardContext = await _resolveBoardContext(task);
      final boardTitle = boardContext['boardTitle'] ?? 'Unknown Board';
      final boardManagerName =
          boardContext['boardManagerName'] ?? 'Unknown Manager';
      final taskSummary = _buildTaskSummary(task.taskDescription);
      final message =
          '${task.taskTitle} from $boardTitle by $boardManagerName is due in $timeText.';

      await _dispatchService.sendNotificationToUser(
        userId: task.taskAssignedTo,
        title: 'Task Due Soon',
        body: message,
        category: 'task_deadline',
        data: {
          'taskId': task.taskId,
          'taskTitle': task.taskTitle,
          'deadline': task.taskDeadline?.toIso8601String() ?? '',
          'boardTitle': boardTitle,
          'boardManagerName': boardManagerName,
          'taskPriorityLevel': task.taskPriorityLevel,
          if (taskSummary.isNotEmpty) 'taskSummary': taskSummary,
          'reminderType': 'one_hour_before',
          'minutesUntil': minutes.toString(),
        },
      );

      print('[DeadlineReminder] 1-hour reminder sent for ${task.taskTitle}');
    } catch (e) {
      print('[DeadlineReminder] Error sending 1-hour reminder: $e');
    }
  }

  Future<void> _sendOneDayReminderNotification(
    Task task,
    Duration timeUntilDeadline,
  ) async {
    try {
      final remainingTime = _formatTimeOverdue(timeUntilDeadline);
      final boardContext = await _resolveBoardContext(task);
      final boardTitle = boardContext['boardTitle'] ?? 'Unknown Board';
      final boardManagerName =
          boardContext['boardManagerName'] ?? 'Unknown Manager';
      final taskSummary = _buildTaskSummary(task.taskDescription);
      final message =
          '${task.taskTitle} from $boardTitle by $boardManagerName is due in $remainingTime.';

      await _dispatchService.sendNotificationToUser(
        userId: task.taskAssignedTo,
        title: 'Task Due Tomorrow',
        body: message,
        category: 'task_deadline',
        data: {
          'taskId': task.taskId,
          'taskTitle': task.taskTitle,
          'deadline': task.taskDeadline?.toIso8601String() ?? '',
          'boardTitle': boardTitle,
          'boardManagerName': boardManagerName,
          'taskPriorityLevel': task.taskPriorityLevel,
          if (taskSummary.isNotEmpty) 'taskSummary': taskSummary,
          'reminderType': 'one_day_before',
          'hoursRemaining': timeUntilDeadline.inHours.toString(),
        },
      );

      print('[DeadlineReminder] 1-day reminder sent for ${task.taskTitle}');
    } catch (e) {
      print('[DeadlineReminder] Error sending 1-day reminder: $e');
    }
  }

  Future<Map<String, String>> _resolveBoardContext(Task task) async {
    var boardTitle = (task.taskBoardTitle ?? '').trim();
    var boardManagerName = '';
    final boardId = task.taskBoardId.trim();

    if (boardId.isNotEmpty) {
      try {
        final boardDoc = await _firestore.collection('boards').doc(boardId).get();
        if (boardDoc.exists) {
          final boardData = boardDoc.data() as Map<String, dynamic>;
          if (boardTitle.isEmpty) {
            boardTitle = (boardData['boardTitle'] as String? ?? '').trim();
          }
          boardManagerName =
              (boardData['boardManagerName'] as String? ?? '').trim();
        }
      } catch (_) {
        // Non-blocking enrichment.
      }
    }

    return {
      'boardTitle': boardTitle,
      'boardManagerName': boardManagerName,
    };
  }

  String _buildTaskSummary(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    if (text.length <= 180) return text;
    return '${text.substring(0, 177)}...';
  }

  String _formatTimeOverdue(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else {
      return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    }
  }
}
