import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/push_notif_model.dart';

class PushNotificationService {
  final FirebaseFirestore _firestore;

  PushNotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collectionPath = 'push_notifications';

  /// Create a new push notification
  Future<String> createNotification(PushNotification notification) async {
    try {
      final docRef = await _firestore.collection(_collectionPath).add(
            notification.toMap(),
          );
      return docRef.id;
    } catch (e) {
      throw Exception('Error creating push notification: $e');
    }
  }

  /// Get notification by ID
  Future<PushNotification?> getNotification(String notificationId) async {
    try {
      final doc = await _firestore
          .collection(_collectionPath)
          .doc(notificationId)
          .get();
      if (doc.exists) {
        return PushNotification.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching notification: $e');
    }
  }

  /// Get all notifications for a user
  Future<List<PushNotification>> getNotificationsByUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionPath)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => PushNotification.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error fetching user notifications: $e');
    }
  }

  /// Stream notifications for a user
  Stream<List<PushNotification>> streamNotificationsByUser(String userId) {
    return _firestore
        .collection(_collectionPath)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PushNotification.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Mark notification as sent
  Future<void> markAsSent(String notificationId) async {
    try {
      await _firestore.collection(_collectionPath).doc(notificationId).update({
        'isSent': true,
        'sentAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error marking notification as sent: $e');
    }
  }

  /// Update notification with error info
  Future<void> updateWithError(
    String notificationId,
    String errorMessage,
  ) async {
    try {
      final doc = await _firestore
          .collection(_collectionPath)
          .doc(notificationId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final currentAttempts = data['attempts'] as int? ?? 0;

        await _firestore
            .collection(_collectionPath)
            .doc(notificationId)
            .update({
          'attempts': currentAttempts + 1,
          'lastError': errorMessage,
        });
      }
    } catch (e) {
      throw Exception('Error updating notification with error: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection(_collectionPath)
          .doc(notificationId)
          .delete();
    } catch (e) {
      throw Exception('Error deleting notification: $e');
    }
  }

  /// Get unsent notifications
  Future<List<PushNotification>> getUnsentNotifications() async {
    try {
      final snapshot = await _firestore
          .collection(_collectionPath)
          .where('isSent', isEqualTo: false)
          .orderBy('createdAt')
          .get();
      return snapshot.docs
          .map((doc) => PushNotification.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error fetching unsent notifications: $e');
    }
  }

  /// Stream unsent notifications
  Stream<List<PushNotification>> streamUnsentNotifications() {
    return _firestore
        .collection(_collectionPath)
        .where('isSent', isEqualTo: false)
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PushNotification.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Clean up old notifications (e.g., older than 30 days)
  Future<void> deleteOldNotifications(int daysOld) async {
    try {
      final cutoffDate =
          DateTime.now().subtract(Duration(days: daysOld));
      final snapshot = await _firestore
          .collection(_collectionPath)
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception('Error deleting old notifications: $e');
    }
  }
}
