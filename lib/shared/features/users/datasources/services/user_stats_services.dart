import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_stats_model.dart';

class UserStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _stats => _firestore.collection('user_stats');

  Future<UserStatsModel?> getStats(String userId) async {
    print('[DEBUG] UserStatsService.getStats: Fetching stats for userId: $userId');
    try {
      final doc = await _stats.doc(userId).get();
      if (!doc.exists || doc.data() == null) {
        print('[DEBUG] UserStatsService.getStats: No stats document found for userId: $userId');
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      print('[DEBUG] UserStatsService.getStats: Stats found - tasks: ${data['userTasksCreatedCount'] ?? 0}, subtasks: ${data['userSubtasksCreatedCount'] ?? 0}');
      return UserStatsModel(
        userId: userId,
        userBoardsCreatedCount: data['userBoardsCreatedCount'] ?? 0,
        userBoardsDeletedCount: data['userBoardsDeletedCount'] ?? 0,
        userTasksCreatedCount: data['userTasksCreatedCount'] ?? 0,
        userTasksCompletedCount: data['userTasksCompletedCount'] ?? 0,
        userTasksDeletedCount: data['userTasksDeletedCount'] ?? 0,
        userSubtasksCreatedCount: data['userSubtasksCreatedCount'] ?? 0,
        userSubtasksCompletedCount: data['userSubtasksCompletedCount'] ?? 0,
        userSubtasksDeletedCount: data['userSubtasksDeletedCount'] ?? 0,
        userTimeOnTasksMinutes: data['userTimeOnTasksMinutes'] ?? 0,
      );
    } catch (e) {
      print('[ERROR] UserStatsService.getStats: Failed to fetch stats - $e');
      rethrow;
    }
  }

  Future<void> createInitialStats(String userId) async {
    print('[DEBUG] UserStatsService.createInitialStats: Creating initial stats for userId: $userId');
    try {
      await _stats.doc(userId).set({'userId': userId});
      print('[DEBUG] UserStatsService.createInitialStats: Initial stats created for userId: $userId');
    } catch (e) {
      print('[ERROR] UserStatsService.createInitialStats: Failed to create initial stats - $e');
      rethrow;
    }
  }

  Future<void> increment(String userId, Map<String, dynamic> updates) async {
    print('[DEBUG] UserStatsService.increment: Incrementing stats for userId: $userId, updates: $updates');
    try {
      await _stats.doc(userId).update(
        updates.map(
          (key, value) => MapEntry(key, FieldValue.increment(value)),
        ),
      );
      print('[DEBUG] UserStatsService.increment: Stats incremented successfully for userId: $userId');
    } catch (e) {
      print('[ERROR] UserStatsService.increment: Failed to increment stats - $e');
      rethrow;
    }
  }
}
