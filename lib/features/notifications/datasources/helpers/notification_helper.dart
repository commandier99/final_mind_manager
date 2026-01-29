import '../models/in_app_notif_model.dart';
import '../models/push_notif_model.dart';
import '../services/in_app_notif_service.dart';
import '../services/push_notif_service.dart';

/// Helper class to create both in-app and push notifications simultaneously
class NotificationHelper {
  static final InAppNotificationService _inAppService =
      InAppNotificationService();
  static final PushNotificationService _pushService =
      PushNotificationService();

  /// Create an in-app notification and trigger a corresponding push notification
  static Future<void> createNotificationPair({
    required String userId,
    required String title,
    required String message,
    String? category,
    String? relatedId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Create in-app notification
      final inAppNotif = InAppNotification(
        notificationId: '', // Will be set by Firestore
        userId: userId,
        title: title,
        message: message,
        category: category,
        relatedId: relatedId,
        isRead: false,
        createdAt: DateTime.now(),
        metadata: metadata,
      );

      final inAppId = await _inAppService.createNotification(inAppNotif);

      // Create push notification (triggers immediately)
      final pushNotif = PushNotification(
        notificationId: '', // Will be set by Firestore
        userId: userId,
        title: title,
        body: message,
        category: category,
        relatedId: relatedId,
        isSent: false,
        createdAt: DateTime.now(),
        data: {
          'inAppNotificationId': inAppId,
          if (metadata != null) ...metadata,
        },
      );

      final pushId = await _pushService.createNotification(pushNotif);

      print('✅ Notification pair created: in-app=$inAppId, push=$pushId');
    } catch (e) {
      print('⚠️ Error creating notification pair: $e');
      rethrow;
    }
  }

  /// Create only an in-app notification (without push)
  static Future<String> createInAppOnly({
    required String userId,
    required String title,
    required String message,
    String? category,
    String? relatedId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final inAppNotif = InAppNotification(
        notificationId: '',
        userId: userId,
        title: title,
        message: message,
        category: category,
        relatedId: relatedId,
        isRead: false,
        createdAt: DateTime.now(),
        metadata: metadata,
      );

      return await _inAppService.createNotification(inAppNotif);
    } catch (e) {
      print('⚠️ Error creating in-app notification: $e');
      rethrow;
    }
  }

  /// Create only a push notification (without in-app)
  static Future<String> createPushOnly({
    required String userId,
    required String title,
    required String body,
    String? category,
    String? relatedId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final pushNotif = PushNotification(
        notificationId: '',
        userId: userId,
        title: title,
        body: body,
        category: category,
        relatedId: relatedId,
        isSent: false,
        createdAt: DateTime.now(),
        data: data,
      );

      return await _pushService.createNotification(pushNotif);
    } catch (e) {
      print('⚠️ Error creating push notification: $e');
      rethrow;
    }
  }

  // Notification categories (constants)
  static const String categoryInvitation = 'invitation';
  static const String categoryJoinRequest = 'join_request';
  static const String categoryTaskAssigned = 'task_assigned';
  static const String categoryTaskDeadline = 'task_deadline';
  static const String categoryReminder = 'reminder';
  static const String categoryComment = 'comment';
  static const String categoryBoardMember = 'board_member';
  static const String categoryApproval = 'approval';
}
