import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  Future<String> createNotification(AppNotification notification) async {
    final explicitId = notification.notificationId.trim();
    final eventKey = (notification.eventKey ?? '').trim();
    final docRef = explicitId.isNotEmpty
        ? _notifications.doc(explicitId)
        : (eventKey.isNotEmpty ? _notifications.doc(eventKey) : _notifications.doc());
    final normalized = notification.copyWith(
      notificationId: docRef.id,
      updatedAt: DateTime.now(),
    );
    await docRef.set(normalized.toMap());
    return docRef.id;
  }

  Future<List<String>> createNotifications(
    List<AppNotification> notifications,
  ) async {
    final ids = <String>[];
    for (final notification in notifications) {
      ids.add(await createNotification(notification));
    }
    return ids;
  }

  Future<void> updateNotification(AppNotification notification) async {
    await _notifications.doc(notification.notificationId).update(
      notification.copyWith(updatedAt: DateTime.now()).toMap(),
    );
  }

  Future<void> markAsRead(String notificationId) async {
    await _notifications.doc(notificationId).update({
      'isRead': true,
      'readAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> markAllAsRead(String userId) async {
    final snapshot = await _notifications
        .where('recipientUserId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    }
    await batch.commit();
  }

  Future<void> softDeleteNotification(String notificationId) async {
    await _notifications.doc(notificationId).update({
      'isDeleted': true,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<AppNotification?> getNotificationById(String notificationId) async {
    final doc = await _notifications.doc(notificationId).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppNotification.fromMap(doc.data()!, doc.id);
  }

  Stream<List<AppNotification>> streamNotificationsForUser(String userId) {
    return _notifications
        .where('recipientUserId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapSnapshotToNotifications);
  }

  Stream<int> streamUnreadCount(String userId) {
    return _notifications
        .where('recipientUserId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  List<AppNotification> _mapSnapshotToNotifications(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) {
          try {
            return AppNotification.fromMap(doc.data(), doc.id);
          } catch (e) {
            debugPrint(
              '[NotificationService] Failed to parse notification ${doc.id}: $e',
            );
            return null;
          }
        })
        .whereType<AppNotification>()
        .toList();
  }
}
