import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/user_stats_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _users => _firestore.collection('users');
  CollectionReference get _userStats => _firestore.collection('userStats');

  Future<UserModel?> getUserById(String uid) async {
    print('[DEBUG] UserService.getUserById: Fetching user with uid = $uid');
    try {
      final doc = await _users.doc(uid).get();
      print('[DEBUG] UserService.getUserById: Document exists = ${doc.exists}, data = ${doc.data()}');
      if (doc.exists && doc.data() != null) {
        print('[DEBUG] UserService.getUserById: User data found, returning UserModel');
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      } else {
        print('[DEBUG] UserService.getUserById: No user data found for uid = $uid');
      }
    } catch (e) {
      print('⚠️ [UserService] Error fetching user: $e');
    }
    return null;
  }

  Future<void> saveUser(UserModel user) async {
    try {
      await _users.doc(user.userId).set(user.toMap(), SetOptions(merge: true));
      
      // Initialize user stats with default values
      await _initializeUserStats(user.userId);
      
      print('✅ [UserService] User ${user.userId} saved successfully');
    } catch (e) {
      print('⚠️ [UserService] Error saving user: $e');
    }
  }

  /// Initialize UserStats with default values when user is created
  Future<void> _initializeUserStats(String userId) async {
    try {
      final statsDoc = await _userStats.doc(userId).get();
      if (!statsDoc.exists) {
        final defaultStats = UserStatsModel(userId: userId);
        await _userStats.doc(userId).set(defaultStats.toMap());
        print('✅ [UserService] UserStats initialized for user $userId');
      }
    } catch (e) {
      print('⚠️ [UserService] Error initializing user stats: $e');
    }
  }

  Future<void> updateUserFields(String uid, Map<String, dynamic> updates) async {
    try {
      await _users.doc(uid).update(updates);
      print('✅ [UserService] User $uid updated successfully');
    } catch (e) {
      print('⚠️ [UserService] Error updating user fields: $e');
      rethrow;
    }
  }

  Future<void> markUserAsVerified(String uid) async {
    try {
      await _users.doc(uid).update({'userIsVerified': true});
      print('✅ [UserService] User $uid marked as verified');
    } catch (e) {
      print('⚠️ [UserService] Error marking user $uid as verified: $e');
    }
  }

  // ========================
  // PUBLIC USERS
  // ========================


  Stream<List<UserModel>> streamPublicUsers() {
    return _users
        .where('userIsPublic', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<void> deleteUserAccount(String userId) async {
    try {
      print('[DEBUG] UserService: Starting deletion for user $userId');
      
      // Use batched writes for better performance and atomicity
      WriteBatch batch = _firestore.batch();
      
      // Delete all boards created by user
      final boardsSnapshot = await _firestore
          .collection('boards')
          .where('boardManagerId', isEqualTo: userId)
          .get();
      
      print('[DEBUG] UserService: Found ${boardsSnapshot.docs.length} boards to delete');
      for (var doc in boardsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete all tasks created by user
      final tasksSnapshot = await _firestore
          .collection('tasks')
          .where('taskOwnerId', isEqualTo: userId)
          .get();
      
      print('[DEBUG] UserService: Found ${tasksSnapshot.docs.length} tasks to delete');
      for (var doc in tasksSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete board stats
      final boardStatsSnapshot = await _firestore
          .collection('boardStats')
          .where('boardManagerId', isEqualTo: userId)
          .get();
      
      print('[DEBUG] UserService: Found ${boardStatsSnapshot.docs.length} board stats to delete');
      for (var doc in boardStatsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete activity events
      final activityEventsSnapshot = await _firestore
          .collection('activity_events')
          .where('userId', isEqualTo: userId)
          .get();
      
      print('[DEBUG] UserService: Found ${activityEventsSnapshot.docs.length} activity events to delete');
      for (var doc in activityEventsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete user daily activity (subcollection)
      final dailyActivitySnapshot = await _firestore
          .collection('user_daily_activity')
          .doc(userId)
          .collection('days')
          .get();
      
      print('[DEBUG] UserService: Found ${dailyActivitySnapshot.docs.length} daily activity records to delete');
      for (var doc in dailyActivitySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete user daily activity parent document
      batch.delete(_firestore.collection('user_daily_activity').doc(userId));
      
      // Delete user stats
      batch.delete(_firestore.collection('userStats').doc(userId));
      print('[DEBUG] UserService: Marked user stats for deletion');
      
      // Delete user document (MAIN DOCUMENT)
      batch.delete(_users.doc(userId));
      print('[DEBUG] UserService: Marked user document for deletion');
      
      // Commit all deletions at once
      print('[DEBUG] UserService: Committing batch deletion...');
      await batch.commit();
      
      print('✅ [UserService] User $userId and all associated data deleted successfully');
    } catch (e) {
      print('⚠️ [UserService] Error deleting user account: $e');
      rethrow;
    }
  }
}