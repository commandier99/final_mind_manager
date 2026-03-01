import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/user_stats_model.dart';

void _log(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _users => _firestore.collection('users');
  CollectionReference get _userStats => _firestore.collection('userStats');
  CollectionReference get _legacyUserStats =>
      _firestore.collection('user_stats');

  Future<UserModel?> getUserById(String uid) async {
    _log('[DEBUG] UserService.getUserById: Fetching user with uid = $uid');
    try {
      final doc = await _users.doc(uid).get();
      _log(
        '[DEBUG] UserService.getUserById: Document exists = ${doc.exists}, data = ${doc.data()}',
      );
      if (doc.exists && doc.data() != null) {
        _log(
          '[DEBUG] UserService.getUserById: User data found, returning UserModel',
        );
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      } else {
        _log(
          '[DEBUG] UserService.getUserById: No user data found for uid = $uid',
        );
      }
    } catch (e) {
      _log('[UserService] Error fetching user: $e');
    }
    return null;
  }

  Future<void> saveUser(UserModel user) async {
    try {
      await _users.doc(user.userId).set(user.toMap(), SetOptions(merge: true));

      // Initialize user stats with default values.
      await _initializeUserStats(user.userId);

      _log('[UserService] User ${user.userId} saved successfully');
    } catch (e) {
      _log('[UserService] Error saving user: $e');
    }
  }

  /// Initialize canonical userStats doc, with legacy fallback migration.
  Future<void> _initializeUserStats(String userId) async {
    try {
      final statsDoc = await _userStats.doc(userId).get();
      if (statsDoc.exists && statsDoc.data() != null) return;

      final legacyStatsDoc = await _legacyUserStats.doc(userId).get();
      if (legacyStatsDoc.exists && legacyStatsDoc.data() != null) {
        await _userStats
            .doc(userId)
            .set(
              legacyStatsDoc.data() as Map<String, dynamic>,
              SetOptions(merge: true),
            );
        _log('[UserService] Legacy user_stats migrated for user $userId');
        return;
      }

      final defaultStats = UserStatsModel(userId: userId);
      await _userStats.doc(userId).set(defaultStats.toMap());
      _log('[UserService] UserStats initialized for user $userId');
    } catch (e) {
      _log('[UserService] Error initializing user stats: $e');
    }
  }

  Future<void> updateUserFields(
    String uid,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _users.doc(uid).update(updates);
      _log('[UserService] User $uid updated successfully');
    } catch (e) {
      _log('[UserService] Error updating user fields: $e');
      rethrow;
    }
  }

  Future<void> markUserAsVerified(String uid) async {
    try {
      await _users.doc(uid).update({'userIsVerified': true});
      _log('[UserService] User $uid marked as verified');
    } catch (e) {
      _log('[UserService] Error marking user $uid as verified: $e');
    }
  }

  // ========================
  // PUBLIC USERS
  // ========================

  Stream<List<UserModel>> streamPublicUsers() {
    return _users
        .where('userIsPublic', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => UserModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<void> deleteUserAccount(String userId) async {
    try {
      _log('[DEBUG] UserService: Starting deletion for user $userId');

      // Use batched writes for better performance and atomicity.
      WriteBatch batch = _firestore.batch();

      // Delete all boards created by user.
      final boardsSnapshot = await _firestore
          .collection('boards')
          .where('boardManagerId', isEqualTo: userId)
          .get();

      _log(
        '[DEBUG] UserService: Found ${boardsSnapshot.docs.length} boards to delete',
      );
      for (var doc in boardsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete all tasks created by user.
      final tasksSnapshot = await _firestore
          .collection('tasks')
          .where('taskOwnerId', isEqualTo: userId)
          .get();

      _log(
        '[DEBUG] UserService: Found ${tasksSnapshot.docs.length} tasks to delete',
      );
      for (var doc in tasksSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete board stats.
      final boardStatsSnapshot = await _firestore
          .collection('boardStats')
          .where('boardManagerId', isEqualTo: userId)
          .get();

      _log(
        '[DEBUG] UserService: Found ${boardStatsSnapshot.docs.length} board stats to delete',
      );
      for (var doc in boardStatsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete activity events.
      final activityEventsSnapshot = await _firestore
          .collection('activity_events')
          .where('userId', isEqualTo: userId)
          .get();

      _log(
        '[DEBUG] UserService: Found ${activityEventsSnapshot.docs.length} activity events to delete',
      );
      for (var doc in activityEventsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete user daily activity (subcollection).
      final dailyActivitySnapshot = await _firestore
          .collection('user_daily_activity')
          .doc(userId)
          .collection('days')
          .get();

      _log(
        '[DEBUG] UserService: Found ${dailyActivitySnapshot.docs.length} daily activity records to delete',
      );
      for (var doc in dailyActivitySnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete user daily activity parent document.
      batch.delete(_firestore.collection('user_daily_activity').doc(userId));

      // Delete user stats (canonical and legacy collections).
      batch.delete(_firestore.collection('userStats').doc(userId));
      batch.delete(_firestore.collection('user_stats').doc(userId));
      _log('[DEBUG] UserService: Marked user stats for deletion');

      // Delete user document (MAIN DOCUMENT).
      batch.delete(_users.doc(userId));
      _log('[DEBUG] UserService: Marked user document for deletion');

      // Commit all deletions at once.
      _log('[DEBUG] UserService: Committing batch deletion...');
      await batch.commit();

      _log(
        '[UserService] User $userId and all associated data deleted successfully',
      );
    } catch (e) {
      _log('[UserService] Error deleting user account: $e');
      rethrow;
    }
  }
}
