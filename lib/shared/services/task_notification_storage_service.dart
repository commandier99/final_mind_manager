import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/task_notification_model.dart';

class TaskNotificationStorageService {
  static final TaskNotificationStorageService _instance =
      TaskNotificationStorageService._internal();

  factory TaskNotificationStorageService() {
    return _instance;
  }

  TaskNotificationStorageService._internal();

  static const String _storageKey = 'task_notifications';

  /// Save a task notification
  Future<void> saveNotification(TaskNotification notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = await getNotifications();
      
      // Remove any existing notification with same ID
      notifications.removeWhere((n) => n.notificationId == notification.notificationId);
      
      // Add the new notification at the beginning
      notifications.insert(0, notification);
      
      // Keep only the last 50 notifications
      if (notifications.length > 50) {
        notifications.removeRange(50, notifications.length);
      }
      
      final jsonList = notifications.map((n) => jsonEncode(n.toMap())).toList();
      await prefs.setStringList(_storageKey, jsonList);
      
      print('[TaskNotificationStorage] Saved notification: ${notification.notificationId}');
    } catch (e) {
      print('[TaskNotificationStorage] Error saving notification: $e');
    }
  }

  /// Get all task notifications for a specific user
  Future<List<TaskNotification>> getNotifications({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_storageKey) ?? [];
      
      final notifications = jsonList
          .map((json) => TaskNotification.fromMap(jsonDecode(json)))
          .toList();
      
      // Filter by userId if provided
      if (userId != null) {
        return notifications.where((n) => n.userId == userId).toList();
      }
      
      return notifications;
    } catch (e) {
      print('[TaskNotificationStorage] Error getting notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final notifications = await getNotifications();
      final index = notifications.indexWhere((n) => n.notificationId == notificationId);
      
      if (index != -1) {
        notifications[index] = notifications[index].copyWith(isRead: true);
        
        final prefs = await SharedPreferences.getInstance();
        final jsonList = notifications.map((n) => jsonEncode(n.toMap())).toList();
        await prefs.setStringList(_storageKey, jsonList);
        
        print('[TaskNotificationStorage] Marked as read: $notificationId');
      }
    } catch (e) {
      print('[TaskNotificationStorage] Error marking as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      final notifications = await getNotifications();
      notifications.removeWhere((n) => n.notificationId == notificationId);
      
      final prefs = await SharedPreferences.getInstance();
      final jsonList = notifications.map((n) => jsonEncode(n.toMap())).toList();
      await prefs.setStringList(_storageKey, jsonList);
      
      print('[TaskNotificationStorage] Deleted notification: $notificationId');
    } catch (e) {
      print('[TaskNotificationStorage] Error deleting notification: $e');
    }
  }

  /// Update task request acceptance status
  Future<void> updateAcceptanceStatus(String notificationId, String status) async {
    try {
      final notifications = await getNotifications();
      final index = notifications.indexWhere((n) => n.notificationId == notificationId);
      
      if (index != -1) {
        notifications[index] = notifications[index].copyWith(
          acceptanceStatus: status,
          isRead: true,
        );
        
        final prefs = await SharedPreferences.getInstance();
        final jsonList = notifications.map((n) => jsonEncode(n.toMap())).toList();
        await prefs.setStringList(_storageKey, jsonList);
        
        print('[TaskNotificationStorage] Updated acceptance status for $notificationId to $status');
      }
    } catch (e) {
      print('[TaskNotificationStorage] Error updating acceptance status: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      print('[TaskNotificationStorage] Cleared all notifications');
    } catch (e) {
      print('[TaskNotificationStorage] Error clearing notifications: $e');
    }
  }

  /// Get unread notification count for a specific user
  Future<int> getUnreadCount({String? userId}) async {
    try {
      final notifications = await getNotifications(userId: userId);
      return notifications.where((n) => !n.isRead).length;
    } catch (e) {
      print('[TaskNotificationStorage] Error getting unread count: $e');
      return 0;
    }
  }
}
