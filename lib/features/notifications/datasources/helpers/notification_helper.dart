import '../models/in_app_notif_model.dart';
import '../services/in_app_notif_service.dart';

/// Helper class to create canonical in-app notifications.
/// Push delivery is triggered by backend functions from the in-app record.
class NotificationHelper {
  static final InAppNotificationService _inAppService =
      InAppNotificationService();

  /// Legacy compatibility method.
  /// Creates a single in-app notification (source of truth).
  static Future<void> createNotificationPair({
    required String userId,
    required String title,
    required String message,
    String? category,
    String? relatedId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      print('[NotificationHelper] Starting createNotificationPair for userId: $userId, category: $category');

      // Create canonical in-app notification.
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

      print('[NotificationHelper] Creating in-app notification...');
      final inAppId = await _inAppService.createNotification(inAppNotif);
      print('[NotificationHelper] ✅ In-app notification created with ID: $inAppId');
      print('✅ Notification created: in-app=$inAppId');
    } catch (e) {
      print('[NotificationHelper] ❌ Error in createNotificationPair: $e');
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
      // Push-only records are deprecated. Create the canonical in-app item
      // so backend push delivery can be triggered from one source of truth.
      final inAppNotif = InAppNotification(
        notificationId: '',
        userId: userId,
        title: title,
        message: body,
        category: category,
        relatedId: relatedId,
        isRead: false,
        createdAt: DateTime.now(),
        metadata: data,
      );

      return await _inAppService.createNotification(inAppNotif);
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
