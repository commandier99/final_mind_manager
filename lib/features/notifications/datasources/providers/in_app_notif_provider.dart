import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../../shared/services/firebase_messaging_service.dart';
import '../models/in_app_notif_model.dart';
import '../services/in_app_notif_service.dart';

class InAppNotificationProvider extends ChangeNotifier {
  final InAppNotificationService _service;

  InAppNotificationProvider({InAppNotificationService? service})
      : _service = service ?? InAppNotificationService();

  List<InAppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _error;
  bool _hasLoadedOnce = false;
  final Set<String> _seenNotificationIds = {};
  
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _unreadCountSubscription;

  // Getters
  List<InAppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<InAppNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  /// Stream notifications for a user
  void streamNotificationsByUser(String userId) {
     print('[InAppNotificationProvider] streamNotificationsByUser called for userId: $userId');
   
     // Cancel previous subscription if any
     _notificationSubscription?.cancel();
   
     _isLoading = true;
     _error = null;

     _notificationSubscription = _service.streamNotificationsByUser(userId).listen(
      (notifications) {
        print('[InAppNotificationProvider] Received ${notifications.length} notifications');
        _notifications = notifications;
        _unreadCount = notifications.where((n) => !n.isRead).length;
        _handleNewNotifications(notifications);
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        print('[InAppNotificationProvider] Error streaming: $e');
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Stream unread count for a user
  void streamUnreadCount(String userId) {
      // Cancel previous subscription if any
      _unreadCountSubscription?.cancel();

      _unreadCountSubscription = _service.streamUnreadCount(userId).listen(
      (count) {
        _unreadCount = count;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  /// Create a new in-app notification
  Future<String> createNotification(InAppNotification notification) async {
    try {
      _error = null;
      final id = await _service.createNotification(notification);
      notifyListeners();
      return id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      _error = null;
      await _service.markAsRead(notificationId);
      _notifications = _notifications.map((n) {
        if (n.notificationId == notificationId) {
          return n.copyWith(
            isRead: true,
            readAt: DateTime.now(),
          );
        }
        return n;
      }).toList();
      _unreadCount =
          _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    try {
      _error = null;
      await _service.markAllAsRead(userId);
      _notifications = _notifications.map((n) {
        return n.copyWith(
          isRead: true,
          readAt: DateTime.now(),
        );
      }).toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      _error = null;
      await _service.deleteNotification(notificationId);
      _notifications = _notifications
          .where((n) => n.notificationId != notificationId)
          .toList();
      _unreadCount =
          _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications(String userId) async {
    try {
      _error = null;
      await _service.deleteAllNotifications(userId);
      _notifications = [];
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Get notifications by category
  List<InAppNotification> getNotificationsByCategory(String category) {
    return _notifications.where((n) => n.category == category).toList();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    super.dispose();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _handleNewNotifications(List<InAppNotification> notifications) {
    if (!_hasLoadedOnce) {
      _seenNotificationIds.addAll(
        notifications.map((n) => n.notificationId),
      );
      _hasLoadedOnce = true;
      return;
    }

    final newNotifications = notifications
        .where((n) => !_seenNotificationIds.contains(n.notificationId))
        .toList();

    for (final notification in newNotifications) {
      if (notification.category == 'task_assigned' && !notification.isRead) {
        _showLocalNotification(notification);
      }
    }

    _seenNotificationIds
      ..clear()
      ..addAll(notifications.map((n) => n.notificationId));
  }

  Future<void> _showLocalNotification(
    InAppNotification notification,
  ) async {
    try {
      final localNotifications = FirebaseMessagingService().localNotifications;

      const androidDetails = AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await localNotifications.show(
        notification.notificationId.hashCode,
        notification.title,
        notification.message,
        notificationDetails,
      );
    } catch (e) {
      print('[InAppNotificationProvider] Local notification error: $e');
    }
  }
}
