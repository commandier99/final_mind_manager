import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_stats_model.dart';

void _log(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class UserStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _stats => _firestore.collection('user_stats');

  Future<UserStatsModel?> getStats(String userId) async {
    _log(
      '[DEBUG] UserStatsService.getStats: Fetching stats for userId: $userId',
    );
    try {
      final primaryDoc = await _stats.doc(userId).get();

      if (primaryDoc.exists && primaryDoc.data() != null) {
        final data = primaryDoc.data() as Map<String, dynamic>;
        _log(
          '[DEBUG] UserStatsService.getStats: Stats found (primary) - tasks: ${data['userTasksCreatedCount'] ?? 0}, steps: ${data['userStepsCreatedCount'] ?? 0}',
        );
        return UserStatsModel.fromMap(data, userId);
      }

      _log(
        '[DEBUG] UserStatsService.getStats: No stats document found for userId: $userId',
      );
      return null;
    } catch (e) {
      _log('[ERROR] UserStatsService.getStats: Failed to fetch stats - $e');
      rethrow;
    }
  }

  Future<void> createInitialStats(String userId) async {
    _log(
      '[DEBUG] UserStatsService.createInitialStats: Creating initial stats for userId: $userId',
    );
    try {
      await _stats.doc(userId).set(UserStatsModel(userId: userId).toMap());
      _log(
        '[DEBUG] UserStatsService.createInitialStats: Initial stats created for userId: $userId',
      );
    } catch (e) {
      _log(
        '[ERROR] UserStatsService.createInitialStats: Failed to create initial stats - $e',
      );
      rethrow;
    }
  }

  Future<void> increment(String userId, Map<String, dynamic> updates) async {
    _log(
      '[DEBUG] UserStatsService.increment: Incrementing stats for userId: $userId, updates: $updates',
    );
    try {
      await _stats
          .doc(userId)
          .set(
            updates.map(
              (key, value) => MapEntry(key, FieldValue.increment(value)),
            ),
            SetOptions(merge: true),
          );
      _log(
        '[DEBUG] UserStatsService.increment: Stats incremented successfully for userId: $userId',
      );
    } catch (e) {
      _log(
        '[ERROR] UserStatsService.increment: Failed to increment stats - $e',
      );
      rethrow;
    }
  }
}

