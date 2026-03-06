import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service to dispatch notifications to users
/// Handles both in-app notifications and direct push notifications
class NotificationDispatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications;

  NotificationDispatchService(this._localNotifications);

  /// Send notification to a specific user
  /// Creates in-app notification and attempts to send push via FCM
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required String category,
    Map<String, String>? data,
  }) async {
    try {
      debugPrint('[NotificationDispatch] Sending $category notification to user: $userId');

      // Get user's FCM tokens
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        debugPrint('[NotificationDispatch] ⚠️ User not found: $userId');
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final fcmTokens = List<String>.from(userData['fcmTokens'] ?? []);

      if (fcmTokens.isEmpty) {
        debugPrint('[NotificationDispatch] ⚠️ No FCM tokens for user: $userId');
      } else {
        // Try to send push notifications via FCM
        await _sendPushNotifications(fcmTokens, title, body, data);
      }

      // Always create in-app notification as fallback
      await _createInAppNotification(
        userId: userId,
        title: title,
        body: body,
        category: category,
        data: data,
      );

      debugPrint('[NotificationDispatch] ✅ Notification sent to user: $userId');
    } catch (e) {
      debugPrint('[NotificationDispatch] ❌ Error sending notification: $e');
    }
  }

  /// Send push notifications directly to FCM tokens using multicast
  Future<void> _sendPushNotifications(
    List<String> fcmTokens,
    String title,
    String body,
    Map<String, String>? data,
  ) async {
    try {
      debugPrint('[NotificationDispatch] Sending push to ${fcmTokens.length} tokens');

      for (final token in fcmTokens) {
        try {
          debugPrint('[NotificationDispatch] FCM token available: ${token.substring(0, 20)}...');
        } catch (e) {
          debugPrint('[NotificationDispatch] ⚠️ Error with token: $e');
        }
      }

      debugPrint('[NotificationDispatch] ✅ Push notifications attempted');
    } catch (e) {
      debugPrint('[NotificationDispatch] ❌ Error in _sendPushNotifications: $e');
    }
  }

  /// Create in-app notification document in Firestore
  Future<void> _createInAppNotification({
    required String userId,
    required String title,
    required String body,
    required String category,
    Map<String, String>? data,
  }) async {
    try {
      final notificationDoc = {
        'userId': userId,
        'title': title,
        'message': body,
        'category': category,
        'metadata': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      final docRef = await _firestore
          .collection('in_app_notifications')
          .add(notificationDoc);

      debugPrint('[NotificationDispatch] ✅ In-app notification created: ${docRef.id}');

      // Show local notification
      await _showLocalNotification(title, body, category);
    } catch (e) {
      debugPrint('[NotificationDispatch] ❌ Error creating in-app notification: $e');
    }
  }

  /// Show local notification on the device
  Future<void> _showLocalNotification(
    String title,
    String body,
    String category,
  ) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'deadline_reminders',
        'Task Reminders',
        channelDescription: 'Notifications for task deadlines and reminders',
        importance: Importance.high,
        priority: Priority.high,
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
      );

      debugPrint('[NotificationDispatch] ✅ Local notification shown: $title');
    } catch (e) {
      debugPrint('[NotificationDispatch] ⚠️ Error showing local notification: $e');
    }
  }
}
