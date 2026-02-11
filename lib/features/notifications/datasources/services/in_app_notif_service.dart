import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/in_app_notif_model.dart';

class InAppNotificationService {
  final FirebaseFirestore _firestore;

  InAppNotificationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _collectionPath = 'in_app_notifications';

  /// Create a new in-app notification
  Future<String> createNotification(InAppNotification notification) async {
    try {
      print('[InAppNotifService] Creating notification for userId: ${notification.userId}');
      print('[InAppNotifService] Notification data: title="${notification.title}", category="${notification.category}"');
      
      final docRef = await _firestore.collection(_collectionPath).add(
            notification.toMap(),
          );
      
      print('[InAppNotifService] ✅ Notification created in Firestore with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('[InAppNotifService] ❌ Error creating in-app notification: $e');
      print('[InAppNotifService] Error type: ${e.runtimeType}');
      throw Exception('Error creating in-app notification: $e');
    }
  }

  /// Get notification by ID
  Future<InAppNotification?> getNotification(String notificationId) async {
    try {
      final doc = await _firestore
          .collection(_collectionPath)
          .doc(notificationId)
          .get();
      if (doc.exists) {
        return InAppNotification.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching notification: $e');
    }
  }

  /// Get all notifications for a user
  Future<List<InAppNotification>> getNotificationsByUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionPath)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => InAppNotification.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error fetching user notifications: $e');
    }
  }

  /// Stream notifications for a user
  Stream<List<InAppNotification>> streamNotificationsByUser(String userId) {
    return _firestore
        .collection(_collectionPath)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InAppNotification.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection(_collectionPath).doc(notificationId).update({
        'isRead': true,
        'readAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionPath)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.update({
          'isRead': true,
          'readAt': Timestamp.now(),
        });
      }
    } catch (e) {
      throw Exception('Error marking all notifications as read: $e');
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

  /// Delete all notifications for a user
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionPath)
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      throw Exception('Error deleting all notifications: $e');
    }
  }

  /// Get unread notification count for a user
  Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionPath)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Error fetching unread count: $e');
    }
  }

  /// Stream unread count for a user
  Stream<int> streamUnreadCount(String userId) {
    return _firestore
        .collection(_collectionPath)
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
