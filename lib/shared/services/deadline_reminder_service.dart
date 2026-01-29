import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../features/tasks/datasources/models/task_model.dart';

class DeadlineReminderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications;

  DeadlineReminderService(this._localNotifications);

  /// Check for upcoming deadlines and send reminders
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
      final oneHourLater = now.add(const Duration(hours: 1));

      // Query tasks assigned to current user with upcoming deadlines
      final querySnapshot = await _firestore
          .collection('tasks')
          .where('taskAssignedTo', isEqualTo: userId)
          .where('taskIsDone', isEqualTo: false)
          .where('taskDeadline', isGreaterThan: Timestamp.fromDate(now))
          .where('taskDeadline', isLessThanOrEqualTo: Timestamp.fromDate(oneHourLater))
          .get();

      print('[DeadlineReminder] Found ${querySnapshot.docs.length} tasks due soon');

      int remindersCount = 0;

      for (final doc in querySnapshot.docs) {
        try {
          final taskData = Task.fromMap(doc.data(), doc.id);

          // Skip if reminder already sent
          if (taskData.taskReminderSentAt != null) {
            print('[DeadlineReminder] ⊘ Reminder already sent for task: ${taskData.taskTitle}');
            continue;
          }

          // Send local notification
          await _sendReminderNotification(taskData);

          // Update task with reminder sent timestamp
          await _firestore.collection('tasks').doc(doc.id).update({
            'taskReminderSentAt': FieldValue.serverTimestamp(),
          });

          remindersCount++;
          print('[DeadlineReminder] ✅ Reminder sent for task: ${taskData.taskTitle}');
        } catch (e) {
          print('[DeadlineReminder] ❌ Error processing task: $e');
        }
      }

      print('[DeadlineReminder] ✅ Completed - sent $remindersCount reminders');
    } catch (e) {
      print('[DeadlineReminder] ❌ Error checking reminders: $e');
    }
  }

  /// Send local notification for upcoming deadline
  Future<void> _sendReminderNotification(Task task) async {
    try {
      final timeUntilDeadline = task.taskDeadline!.difference(DateTime.now());

      String timeStr;
      if (timeUntilDeadline.inHours < 1) {
        timeStr = '${timeUntilDeadline.inMinutes} minutes';
      } else if (timeUntilDeadline.inHours < 24) {
        timeStr = '${timeUntilDeadline.inHours} hour${timeUntilDeadline.inHours > 1 ? 's' : ''}';
      } else {
        timeStr = '${timeUntilDeadline.inDays} day${timeUntilDeadline.inDays > 1 ? 's' : ''}';
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'Task Deadlines',
        channelDescription: 'Notifications for upcoming task deadlines',
        importance: Importance.high,
        priority: Priority.high,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _localNotifications.show(
        task.taskId.hashCode, // Unique notification ID per task
        '⏰ Task Due Soon',
        '${task.taskTitle} is due in $timeStr',
        notificationDetails,
        payload: 'task:${task.taskId}',
      );

      print('[DeadlineReminder] 🔔 Local notification shown for ${task.taskTitle}');
    } catch (e) {
      print('[DeadlineReminder] ❌ Error sending notification: $e');
    }
  }
}
