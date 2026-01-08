import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/tasks/datasources/models/task_model.dart';
import '../models/task_notification_model.dart';
import 'task_notification_storage_service.dart';

class TaskNotificationService {
  static final TaskNotificationService _instance =
      TaskNotificationService._internal();

  factory TaskNotificationService() {
    return _instance;
  }

  TaskNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Track notification state per task (taskId -> {notificationType -> last notified time})
  final Map<String, Map<String, DateTime>> _notificationStates = {};
  
  // Minimum time between notifications for the same task/type (in minutes)
  static const int notificationCooldownMinutes = 5;

  /// Check and show notifications for task-related events
  void checkAndNotifyTasks(List<Task> tasks) async {
    // Check if push notifications are enabled in settings
    final prefs = await SharedPreferences.getInstance();
    final pushNotificationsEnabled = prefs.getBool('pushNotifications') ?? false;
    
    if (!pushNotificationsEnabled) {
      print('[TaskNotification] Push notifications are disabled in settings, skipping notifications');
      return;
    }
    
    for (var task in tasks) {
      _checkTaskDueToday(task);
      _checkTaskOverdue(task);
    }
  }

  /// Notify when a task is assigned to the user
  Future<void> notifyTaskAssigned(Task task) async {
    try {
      // Check if push notifications are enabled in settings
      final prefs = await SharedPreferences.getInstance();
      final pushNotificationsEnabled = prefs.getBool('pushNotifications') ?? false;
      
      if (!pushNotificationsEnabled) {
        print('[TaskNotification] Push notifications are disabled, skipping task assigned notification');
        return;
      }

      final notificationId = 'assigned_${task.taskId}'.hashCode;
      
      await _localNotificationsPlugin.show(
        notificationId,
        'New Task Assigned',
        '${task.taskTitle} has been assigned to you',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'task_assigned_channel',
            'Task Assignments',
            channelDescription: 'Notifications when tasks are assigned to you',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      
      // Also save to app notifications as a task request that needs acceptance
      final notification = TaskNotification(
        notificationId: 'task_request_${task.taskId}',
        userId: task.taskAssignedTo,
        taskId: task.taskId,
        taskTitle: task.taskTitle,
        boardTitle: task.taskBoardTitle,
        notificationType: 'task_request',
        message: '${task.taskOwnerName} assigned you a task: ${task.taskTitle}',
        createdAt: DateTime.now(),
        acceptanceStatus: task.taskAcceptanceStatus ?? 'pending',
        assignedBy: task.taskAssignedBy,
      );
      await TaskNotificationStorageService().saveNotification(notification);
      
      print('[TaskNotification] Notified task assigned: ${task.taskId}');
    } catch (e) {
      print('[TaskNotification] Error notifying task assigned: $e');
    }
  }

  /// Check and notify if task is due today
  void _checkTaskDueToday(Task task) {
    try {
      if (task.taskDeadline == null || task.taskIsDone) return;

      final now = DateTime.now();
      final deadline = task.taskDeadline!;

      // Check if deadline is today
      final isToday = deadline.year == now.year &&
          deadline.month == now.month &&
          deadline.day == now.day;

      if (!isToday) return;

      // Only notify if time hasn't passed yet
      if (deadline.isBefore(now)) return;

      // Check if we should notify (cooldown period)
      final notificationType = 'due_today_${task.taskId}';
      if (_shouldNotify(notificationType)) {
        _showDueTodayNotification(task, notificationType);
      }
    } catch (e) {
      print('[TaskNotification] Error checking task due today: $e');
    }
  }

  /// Check and notify if task is overdue
  void _checkTaskOverdue(Task task) {
    try {
      if (task.taskDeadline == null || task.taskIsDone) return;

      final now = DateTime.now();
      final deadline = task.taskDeadline!;

      // Task is overdue if deadline has passed
      if (!deadline.isBefore(now)) return;

      // Check if we should notify (cooldown period)
      final notificationType = 'overdue_${task.taskId}';
      if (_shouldNotify(notificationType)) {
        _showOverdueNotification(task, notificationType);
      }
    } catch (e) {
      print('[TaskNotification] Error checking task overdue: $e');
    }
  }

  /// Check if enough time has passed to notify again
  bool _shouldNotify(String notificationType) {
    final lastNotifiedTime = _notificationStates
        .values
        .expand((state) => state.entries)
        .where((entry) => entry.key == notificationType)
        .firstOrNull
        ?.value;

    if (lastNotifiedTime == null) {
      return true; // Never notified before
    }

    final timeSinceLastNotification =
        DateTime.now().difference(lastNotifiedTime).inMinutes;
    return timeSinceLastNotification >= notificationCooldownMinutes;
  }

  /// Record that a notification was shown
  void _recordNotification(String notificationType, String taskId) {
    _notificationStates.putIfAbsent(taskId, () => {});
    _notificationStates[taskId]![notificationType] = DateTime.now();
  }

  Future<void> _showDueTodayNotification(Task task, String notificationType) async {
    try {
      final deadline = task.taskDeadline!;
      final now = DateTime.now();
      final timeLeft = deadline.difference(now);
      final hoursLeft = timeLeft.inHours;
      final minutesLeft = timeLeft.inMinutes % 60;

      String timeStr = '';
      if (hoursLeft > 0) {
        timeStr = hoursLeft == 1 ? 'in 1 hour' : 'in $hoursLeft hours';
        if (minutesLeft > 0) {
          timeStr = '$timeStr ${minutesLeft}m';
        }
      } else if (minutesLeft > 0) {
        timeStr = 'in $minutesLeft minutes';
      } else {
        timeStr = 'very soon';
      }

      print('[TaskNotification] Task ${task.taskId} - deadline: $deadline, now: $now, hoursLeft: $hoursLeft, minutesLeft: $minutesLeft');

      await _localNotificationsPlugin.show(
        notificationType.hashCode,
        'Task Due Today',
        '${task.taskTitle} is due $timeStr',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'task_due_today_channel',
            'Tasks Due Today',
            channelDescription: 'Notifications for tasks due today',
            importance: Importance.high,
            priority: Priority.high,
            color: const Color(0xFFFFA500), // Orange color
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );

      _recordNotification(notificationType, task.taskId);
      
      // Also save to app notifications
      final notification = TaskNotification(
        notificationId: notificationType,
        userId: task.taskAssignedTo,
        taskId: task.taskId,
        taskTitle: task.taskTitle,
        boardTitle: task.taskBoardTitle,
        notificationType: 'due_today',
        message: '${task.taskTitle} is due $timeStr',
        createdAt: DateTime.now(),
      );
      await TaskNotificationStorageService().saveNotification(notification);
      
      print('[TaskNotification] Notified task due today: ${task.taskId}');
    } catch (e) {
      print('[TaskNotification] Error showing due today notification: $e');
    }
  }

  Future<void> _showOverdueNotification(Task task, String notificationType) async {
    try {
      final deadline = task.taskDeadline!;
      final timePassed = DateTime.now().difference(deadline);
      final hoursPassed = timePassed.inHours;
      final daysPassed = timePassed.inDays;

      String timeStr = '';
      if (daysPassed > 0) {
        timeStr = '${daysPassed}d overdue';
      } else {
        timeStr = '${hoursPassed}h overdue';
      }

      await _localNotificationsPlugin.show(
        notificationType.hashCode,
        'Task Overdue',
        '${task.taskTitle} is $timeStr',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'task_overdue_channel',
            'Overdue Tasks',
            channelDescription: 'Notifications for overdue tasks',
            importance: Importance.max,
            priority: Priority.max,
            color: const Color(0xFFFF0000), // Red color
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );

      _recordNotification(notificationType, task.taskId);
      
      // Also save to app notifications
      final notification = TaskNotification(
        notificationId: notificationType,
        userId: task.taskAssignedTo,
        taskId: task.taskId,
        taskTitle: task.taskTitle,
        boardTitle: task.taskBoardTitle,
        notificationType: 'overdue',
        message: '${task.taskTitle} is $timeStr',
        createdAt: DateTime.now(),
      );
      await TaskNotificationStorageService().saveNotification(notification);

      // Mark the task document as overdue so UI / filters can react if needed
      try {
        final _firestore = FirebaseFirestore.instance;
        await _firestore.collection('tasks').doc(task.taskId).update({
          'taskStatus': 'OVERDUE',
        });
      } catch (e) {
        print('[TaskNotification] Failed to update task status to OVERDUE: $e');
      }
      
      print('[TaskNotification] Notified task overdue: ${task.taskId}');
    } catch (e) {
      print('[TaskNotification] Error showing overdue notification: $e');
    }
  }

  /// Clear notification tracking (useful when filtering/viewing tasks)
  void clearNotificationTracking() {
    _notificationStates.clear();
  }

  /// Clear a specific notification from tracking
  void clearNotification(String taskId) {
    _notificationStates.remove(taskId);
  }
}
