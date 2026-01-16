import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  static const String _storageKey = 'app_notifications';

  /// Save a notification
  Future<void> saveNotification(AppNotification notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifications = await getNotifications();
      
      // Remove any existing notification with same ID
      notifications.removeWhere((n) => n.notifId == notification.notifId);
      
      // Add the new notification at the beginning
      notifications.insert(0, notification);
      
      // Keep only the last 100 notifications
      if (notifications.length > 100) {
        notifications.removeRange(100, notifications.length);
      }
      
      final jsonList = notifications.map((n) => jsonEncode(n.toMap())).toList();
      await prefs.setStringList(_storageKey, jsonList);
      
      print('[NotificationService] Saved notification: ${notification.notifId}');
    } catch (e) {
      print('[NotificationService] Error saving notification: $e');
    }
  }

  /// Get all notifications for a specific user
  Future<List<AppNotification>> getNotifications({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_storageKey) ?? [];
      
      final notifications = jsonList
          .map((json) => AppNotification.fromMap(jsonDecode(json)))
          .toList();
      
      // Filter by userId if provided
      if (userId != null) {
        return notifications.where((n) => n.notifUserId == userId).toList();
      }
      
      return notifications;
    } catch (e) {
      print('[NotificationService] Error getting notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notifId) async {
    try {
      final notifications = await getNotifications();
      final index = notifications.indexWhere((n) => n.notifId == notifId);
      
      if (index != -1) {
        notifications[index] = notifications[index].copyWith(notifIsRead: true);
        
        final prefs = await SharedPreferences.getInstance();
        final jsonList = notifications.map((n) => jsonEncode(n.toMap())).toList();
        await prefs.setStringList(_storageKey, jsonList);
        
        print('[NotificationService] Marked as read: $notifId');
      }
    } catch (e) {
      print('[NotificationService] Error marking as read: $e');
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      final notifications = await getNotifications();
      final updatedNotifications = notifications.map((n) {
        if (n.notifUserId == userId && !n.notifIsRead) {
          return n.copyWith(notifIsRead: true);
        }
        return n;
      }).toList();
      
      final prefs = await SharedPreferences.getInstance();
      final jsonList = updatedNotifications.map((n) => jsonEncode(n.toMap())).toList();
      await prefs.setStringList(_storageKey, jsonList);
      
      print('[NotificationService] Marked all as read for user: $userId');
    } catch (e) {
      print('[NotificationService] Error marking all as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notifId) async {
    try {
      final notifications = await getNotifications();
      notifications.removeWhere((n) => n.notifId == notifId);
      
      final prefs = await SharedPreferences.getInstance();
      final jsonList = notifications.map((n) => jsonEncode(n.toMap())).toList();
      await prefs.setStringList(_storageKey, jsonList);
      
      print('[NotificationService] Deleted notification: $notifId');
    } catch (e) {
      print('[NotificationService] Error deleting notification: $e');
    }
  }

  /// Update task request acceptance status
  Future<void> updateAcceptanceStatus(String notifId, String status) async {
    try {
      final notifications = await getNotifications();
      final index = notifications.indexWhere((n) => n.notifId == notifId);
      
      if (index != -1) {
        notifications[index] = notifications[index].copyWith(
          notifAcceptanceStatus: status,
          notifIsRead: true,
        );
        
        final prefs = await SharedPreferences.getInstance();
        final jsonList = notifications.map((n) => jsonEncode(n.toMap())).toList();
        await prefs.setStringList(_storageKey, jsonList);
        
        print('[NotificationService] Updated acceptance status for $notifId to $status');
      }
    } catch (e) {
      print('[NotificationService] Error updating acceptance status: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      print('[NotificationService] Cleared all notifications');
    } catch (e) {
      print('[NotificationService] Error clearing notifications: $e');
    }
  }

  /// Clear all notifications for a specific user
  Future<void> clearUserNotifications(String userId) async {
    try {
      final notifications = await getNotifications();
      final filteredNotifications = notifications.where((n) => n.notifUserId != userId).toList();
      
      final prefs = await SharedPreferences.getInstance();
      final jsonList = filteredNotifications.map((n) => jsonEncode(n.toMap())).toList();
      await prefs.setStringList(_storageKey, jsonList);
      
      print('[NotificationService] Cleared notifications for user: $userId');
    } catch (e) {
      print('[NotificationService] Error clearing user notifications: $e');
    }
  }

  /// Get unread notification count for a specific user
  Future<int> getUnreadCount({String? userId}) async {
    try {
      final notifications = await getNotifications(userId: userId);
      return notifications.where((n) => !n.notifIsRead).length;
    } catch (e) {
      print('[NotificationService] Error getting unread count: $e');
      return 0;
    }
  }

  /// Create and save a notification
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? taskId,
    String? boardTitle,
    String? acceptanceStatus,
    String? assignedBy,
  }) async {
    final notification = AppNotification(
      notifId: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      notifUserId: userId,
      notifTaskId: taskId,
      notifTitle: title,
      notifBoardTitle: boardTitle,
      notifType: type,
      notifMessage: message,
      notifCreatedAt: DateTime.now(),
      notifAcceptanceStatus: acceptanceStatus,
      notifAssignedBy: assignedBy,
    );
    
    await saveNotification(notification);
  }
}
