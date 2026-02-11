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

    print('[DeadlineReminder] 🔄 Starting periodic reminders (every ${interval.inMinutes} min)');

    // Run once immediately when starting
    checkAndSendReminders();

    // Schedule the first check to align with clock time
    _scheduleNextCheck(interval);
  }

  /// Schedule the next check based on actual clock time
  void _scheduleNextCheck(Duration interval) {
    final now = DateTime.now();
    
    // Calculate next check time aligned to the interval
    // For example, if interval is 1 minute, check at :00, :01, :02, etc.
    final nextCheckTime = now.add(interval).subtract(
      Duration(
        milliseconds: now.millisecondsSinceEpoch % interval.inMilliseconds,
      ),
    );
    
    final timeUntilNextCheck = nextCheckTime.difference(now);
    
    print('[DeadlineReminder] ⏰ Next check scheduled in ${timeUntilNextCheck.inSeconds}s');

    _periodicTimer = Timer(timeUntilNextCheck, () async {
      await checkAndSendReminders();
      // Reschedule for the next interval
      _scheduleNextCheck(interval);
    });
  }

  /// Stop periodic checks (optional when app goes to background)
  void stopPeriodicReminders() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    print('[DeadlineReminder] ⏹️ Stopped periodic reminders');
  }
  /// Check for upcoming deadlines and send reminders
  /// Sends reminders at: 1 day before, 1 hour before, and when deadline is missed
  /// Call this when user opens the app
  Future<void> checkAndSendReminders() async {
    try {
      print('[DeadlineReminder] Starting deadline reminder check...');

      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('[DeadlineReminder] ⚠️ No user logged in');
        return;
      }

      final userId = currentUser.uid;
      print('[DeadlineReminder] Checking reminders for user: $userId');

      final now = DateTime.now();
      // Get all incomplete tasks assigned to current user with deadlines
      final allTasksSnapshot = await _firestore
          .collection('tasks')
          .where('taskAssignedTo', isEqualTo: userId)
          .where('taskIsDone', isEqualTo: false)
          .where('taskIsDeleted', isEqualTo: false)
          .where('taskDeadline', isGreaterThan: Timestamp.fromDate(
              now.subtract(const Duration(days: 7)))) // Include past deadlines
          .get();

      print('[DeadlineReminder] Found ${allTasksSnapshot.docs.length} incomplete tasks');

      int remindersCount = 0;

      for (final doc in allTasksSnapshot.docs) {
        try {
          final taskData = Task.fromMap(doc.data(), doc.id);
          
          if (taskData.taskDeadline == null) {
            print(
              '[DeadlineReminder] Skipping ${taskData.taskTitle} (${taskData.taskId}): no deadline',
            );
            continue;
          }

          final timeUntilDeadline = taskData.taskDeadline!.difference(now);
          final isPastDeadline = timeUntilDeadline.isNegative;

          print(
            '[DeadlineReminder] Task ${taskData.taskTitle} (${taskData.taskId}) | deadline=${taskData.taskDeadline} | timeUntil=${timeUntilDeadline.inMinutes}m | reminderSentAt=${taskData.taskReminderSentAt} | pastDue=$isPastDeadline',
          );

          // Check 1: Missed deadline (deadline has passed)
          if (isPastDeadline) {
            final lastReminder = taskData.taskReminderSentAt;
            final deadline = taskData.taskDeadline!;
            final shouldSendMissed = lastReminder == null || lastReminder.isBefore(deadline);

            if (shouldSendMissed) {
              await _sendMissedDeadlineNotification(taskData);
              await _firestore.collection('tasks').doc(doc.id).update({
                'taskReminderSentAt': FieldValue.serverTimestamp(),
                'taskDeadlineMissed': true,
              });
              remindersCount++;
              print('[DeadlineReminder] ✅ Missed deadline notification sent for: ${taskData.taskTitle}');
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
              print('[DeadlineReminder] ✅ 1-hour reminder sent for: ${taskData.taskTitle}');
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
            print('[DeadlineReminder] ✅ 1-day reminder sent for: ${taskData.taskTitle}');
          }
        } catch (e) {
          print('[DeadlineReminder] ❌ Error processing task: $e');
        }
      }

      print('[DeadlineReminder] ✅ Completed - sent $remindersCount reminders');
    } catch (e) {
      print('[DeadlineReminder] ❌ Error checking reminders: $e');
    }
  }

  /// Check if reminder was already sent today
  bool _isSameDay(DateTime sentTime, DateTime now) {
    return sentTime.year == now.year &&
        sentTime.month == now.month &&
        sentTime.day == now.day;
  }

  /// Check if reminder was already sent within the last hour
  bool _wasReminderSentWithinHour(DateTime sentTime) {
    final now = DateTime.now();
    return now.difference(sentTime).inMinutes < 60;
  }

  /// Send missed deadline notification
  Future<void> _sendMissedDeadlineNotification(Task task) async {
    try {
      final timeOverdue = DateTime.now().difference(task.taskDeadline!);
      final formattedTime = _formatTimeOverdue(timeOverdue);

      // Send push and in-app notifications using dispatch service
      await _dispatchService.sendNotificationToUser(
        userId: task.taskAssignedTo,
        title: '❌ Missed Deadline!',
        body: '${task.taskTitle} was due $formattedTime ago',
        category: 'task_deadline',
        data: {
          'taskId': task.taskId,
          'taskTitle': task.taskTitle,
          'deadline': task.taskDeadline?.toIso8601String() ?? '',
          'boardTitle': task.taskBoardTitle ?? '',
          'reminderType': 'missed_deadline',
          'timeOverdue': timeOverdue.inHours.toString(),
        },
      );

      print('[DeadlineReminder] 🔔 Missed deadline notification sent for ${task.taskTitle}');
    } catch (e) {
      print('[DeadlineReminder] ❌ Error sending missed deadline notification: $e');
    }
  }

  /// Send 1-hour before deadline reminder
  Future<void> _sendOneHourReminderNotification(
      Task task, Duration timeUntilDeadline) async {
    try {
      final minutes = timeUntilDeadline.inMinutes;
      final timeText = minutes < 1 ? 'in a few moments' : 'in $minutes minutes';

      // Send push and in-app notifications using dispatch service
      await _dispatchService.sendNotificationToUser(
        userId: task.taskAssignedTo,
        title: '⚠️ Task Due Soon!',
        body: '${task.taskTitle} is due $timeText',
        category: 'task_deadline',
        data: {
          'taskId': task.taskId,
          'taskTitle': task.taskTitle,
          'deadline': task.taskDeadline?.toIso8601String() ?? '',
          'boardTitle': task.taskBoardTitle ?? '',
          'reminderType': 'one_hour_before',
          'minutesUntil': minutes.toString(),
        },
      );

      print('[DeadlineReminder] 🔔 1-hour reminder sent for ${task.taskTitle}');
    } catch (e) {
      print('[DeadlineReminder] ❌ Error sending 1-hour reminder: $e');
    }
  }

  /// Send 1-day before deadline reminder
  Future<void> _sendOneDayReminderNotification(
      Task task, Duration timeUntilDeadline) async {
    try {
      final formattedTime = _formatDeadlineTime(task.taskDeadline!);

      // Send push and in-app notifications using dispatch service
      await _dispatchService.sendNotificationToUser(
        userId: task.taskAssignedTo,
        title: '📌 Task Due Tomorrow',
        body: 'Don\'t forget: ${task.taskTitle} is due on $formattedTime',
        category: 'task_deadline',
        data: {
          'taskId': task.taskId,
          'taskTitle': task.taskTitle,
          'deadline': task.taskDeadline?.toIso8601String() ?? '',
          'boardTitle': task.taskBoardTitle ?? '',
          'reminderType': 'one_day_before',
          'hoursRemaining': timeUntilDeadline.inHours.toString(),
        },
      );

      print('[DeadlineReminder] 🔔 1-day reminder sent for ${task.taskTitle}');
    } catch (e) {
      print('[DeadlineReminder] ❌ Error sending 1-day reminder: $e');
    }
  }

  /// Format deadline time for display in notifications
  String _formatDeadlineTime(DateTime deadline) {
    final now = DateTime.now();
    final isToday = deadline.year == now.year &&
        deadline.month == now.month &&
        deadline.day == now.day;
    final isTomorrow = deadline.year == now.year &&
        deadline.month == now.month &&
        deadline.day == now.day + 1;

    if (isToday) {
      return 'today at ${deadline.hour}:${deadline.minute.toString().padLeft(2, '0')}';
    } else if (isTomorrow) {
      return 'tomorrow at ${deadline.hour}:${deadline.minute.toString().padLeft(2, '0')}';
    } else {
      return '${deadline.month}/${deadline.day} at ${deadline.hour}:${deadline.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Format time overdue for display in notifications
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
