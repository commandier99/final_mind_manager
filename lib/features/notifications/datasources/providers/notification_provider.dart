import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({NotificationService? service})
    : _service = service ?? NotificationService();

  final NotificationService _service;

  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;
  StreamSubscription<List<AppNotification>>? _notificationSubscription;
  StreamSubscription<int>? _unreadCountSubscription;
  String? _currentUserId;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;
  List<AppNotification> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  void streamNotificationsForUser(String userId) {
    if (_currentUserId == userId) return;

    _notificationSubscription?.cancel();
    _unreadCountSubscription?.cancel();

    _currentUserId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    _notificationSubscription = _service.streamNotificationsForUser(userId).listen(
      (notifications) {
        _notifications = notifications;
        _unreadCount = notifications.where((n) => !n.isRead).length;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _notifications = [];
        _unreadCount = 0;
        _isLoading = false;
        _error = error.toString();
        notifyListeners();
      },
    );

    _unreadCountSubscription = _service.streamUnreadCount(userId).listen(
      (count) {
        _unreadCount = count;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  Future<String> createNotification(AppNotification notification) async {
    try {
      _error = null;
      return await _service.createNotification(notification);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<List<String>> createNotifications(
    List<AppNotification> notifications,
  ) async {
    try {
      _error = null;
      return await _service.createNotifications(notifications);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      _error = null;
      await _service.markAsRead(notificationId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> markAllAsRead() async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;

    try {
      _error = null;
      await _service.markAllAsRead(userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> softDeleteNotification(String notificationId) async {
    try {
      _error = null;
      await _service.softDeleteNotification(notificationId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    _notificationSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    _notifications = [];
    _unreadCount = 0;
    _isLoading = false;
    _error = null;
    _currentUserId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _unreadCountSubscription?.cancel();
    super.dispose();
  }
}
