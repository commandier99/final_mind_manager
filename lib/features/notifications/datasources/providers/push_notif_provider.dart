import 'package:flutter/material.dart';
import 'dart:async';
import '../models/push_notif_model.dart';
import '../services/push_notif_service.dart';

class PushNotificationProvider extends ChangeNotifier {
  final PushNotificationService _service;

  PushNotificationProvider({PushNotificationService? service})
      : _service = service ?? PushNotificationService();

  List<PushNotification> _notifications = [];
  List<PushNotification> _unsentNotifications = [];
  bool _isLoading = false;
  String? _error;

  StreamSubscription? _notificationSubscription;
  StreamSubscription? _unsentNotificationsSubscription;
  // Getters
  List<PushNotification> get notifications => _notifications;
  List<PushNotification> get unsentNotifications => _unsentNotifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Stream notifications for a user
  void streamNotificationsByUser(String userId) {
    // Cancel previous subscription if any
    _notificationSubscription?.cancel();
    
    _isLoading = true;
    _error = null;

    _notificationSubscription = _service.streamNotificationsByUser(userId).listen(
      (notifications) {
        _notifications = notifications;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Stream unsent notifications
  void streamUnsentNotifications() {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Cancel previous subscription if any
    _unsentNotificationsSubscription?.cancel();

    _unsentNotificationsSubscription = _service.streamUnsentNotifications().listen(
      (notifications) {
        _unsentNotifications = notifications;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Create a new push notification
  Future<String> createNotification(PushNotification notification) async {
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

  /// Mark notification as sent
  Future<void> markAsSent(String notificationId) async {
    try {
      _error = null;
      await _service.markAsSent(notificationId);
      _notifications = _notifications.map((n) {
        if (n.notificationId == notificationId) {
          return n.copyWith(
            isSent: true,
            sentAt: DateTime.now(),
          );
        }
        return n;
      }).toList();
      _unsentNotifications = _unsentNotifications
          .where((n) => n.notificationId != notificationId)
          .toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Update notification with error
  Future<void> updateWithError(
    String notificationId,
    String errorMessage,
  ) async {
    try {
      _error = null;
      await _service.updateWithError(notificationId, errorMessage);
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
      _unsentNotifications = _unsentNotifications
          .where((n) => n.notificationId != notificationId)
          .toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Get notification by category
  List<PushNotification> getNotificationsByCategory(String category) {
    return _notifications.where((n) => n.category == category).toList();
  }
  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _unsentNotificationsSubscription?.cancel();
    super.dispose();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
