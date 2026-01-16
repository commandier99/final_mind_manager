import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  
  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  /// Load notifications for a specific user
  Future<void> loadNotifications(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _notifications = await _notificationService.getNotifications(userId: userId);
      _unreadCount = await _notificationService.getUnreadCount(userId: userId);
      print('[NotificationProvider] Loaded ${_notifications.length} notifications, $unreadCount unread');
    } catch (e) {
      print('[NotificationProvider] Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create and save a new notification
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
    try {
      await _notificationService.createNotification(
        userId: userId,
        title: title,
        message: message,
        type: type,
        taskId: taskId,
        boardTitle: boardTitle,
        acceptanceStatus: acceptanceStatus,
        assignedBy: assignedBy,
      );
      
      // Reload notifications for the user
      await loadNotifications(userId);
    } catch (e) {
      print('[NotificationProvider] Error creating notification: $e');
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notifId, String userId) async {
    try {
      await _notificationService.markAsRead(notifId);
      await loadNotifications(userId);
    } catch (e) {
      print('[NotificationProvider] Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      await _notificationService.markAllAsRead(userId);
      await loadNotifications(userId);
    } catch (e) {
      print('[NotificationProvider] Error marking all as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notifId, String userId) async {
    try {
      await _notificationService.deleteNotification(notifId);
      await loadNotifications(userId);
    } catch (e) {
      print('[NotificationProvider] Error deleting notification: $e');
    }
  }

  /// Update acceptance status for task request notifications
  Future<void> updateAcceptanceStatus(String notifId, String status, String userId) async {
    try {
      await _notificationService.updateAcceptanceStatus(notifId, status);
      await loadNotifications(userId);
    } catch (e) {
      print('[NotificationProvider] Error updating acceptance status: $e');
    }
  }

  /// Clear all notifications for a user
  Future<void> clearUserNotifications(String userId) async {
    try {
      await _notificationService.clearUserNotifications(userId);
      await loadNotifications(userId);
    } catch (e) {
      print('[NotificationProvider] Error clearing user notifications: $e');
    }
  }

  /// Refresh unread count
  Future<void> refreshUnreadCount(String userId) async {
    try {
      _unreadCount = await _notificationService.getUnreadCount(userId: userId);
      notifyListeners();
    } catch (e) {
      print('[NotificationProvider] Error refreshing unread count: $e');
    }
  }

  /// Get notifications by type
  List<AppNotification> getNotificationsByType(String type) {
    return _notifications.where((n) => n.notifType == type).toList();
  }

  /// Get unread notifications
  List<AppNotification> get unreadNotifications {
    return _notifications.where((n) => !n.notifIsRead).toList();
  }

  /// Get read notifications
  List<AppNotification> get readNotifications {
    return _notifications.where((n) => n.notifIsRead).toList();
  }
}
