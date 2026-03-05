import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/board_stats_model.dart';
import 'package:flutter/foundation.dart';

class BoardStatsService {
  final CollectionReference _boardCollection = FirebaseFirestore.instance
      .collection('boards');

  /// Fetch the stats for a specific board
  Future<BoardStats> getStats(String boardId) async {
    debugPrint('[BoardStatsService] Fetching stats for boardId: $boardId');
    final doc = await _boardCollection.doc(boardId).get();

    if (!doc.exists) {
      debugPrint('[BoardStatsService] Board document does not exist');
      return BoardStats();
    }

    final data = doc.get('stats') as Map<String, dynamic>? ?? {};
    debugPrint('[BoardStatsService] Stats data: $data');
    return BoardStats.fromMap(Map<String, dynamic>.from(data));
  }

  /// Stream stats for a board
  Stream<BoardStats> streamStatsByBoardId(String boardId) {
    debugPrint('[BoardStatsService] Starting stream for boardId: $boardId');
    return _boardCollection.doc(boardId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        debugPrint(
          '[BoardStatsService] Board document does not exist in stream',
        );
        return BoardStats();
      }
      final data = snapshot.get('stats') as Map<String, dynamic>? ?? {};
      debugPrint('[BoardStatsService] Stream stats data: $data');
      return BoardStats.fromMap(Map<String, dynamic>.from(data));
    });
  }

  /// Update the entire stats object
  Future<void> updateStats({
    required String boardId,
    required BoardStats stats,
  }) async {
    await _boardCollection.doc(boardId).update({'stats': stats.toMap()});
  }

  /// Increment stats fields
  Future<void> incrementStats(
    String boardId, {
    int tasksAdded = 0,
    int tasksDone = 0,
    int tasksDeleted = 0,
    int stepsAdded = 0,
    int stepsDone = 0,
    int stepsDeleted = 0,
    int messagesSent = 0,
  }) async {
    debugPrint(
      '[BoardStatsService] incrementStats called for boardId: $boardId',
    );
    debugPrint(
      '[BoardStatsService] tasksAdded=$tasksAdded, tasksDone=$tasksDone, tasksDeleted=$tasksDeleted',
    );

    final Map<String, dynamic> incrementData = {
      'stats.boardTasksCount': FieldValue.increment(tasksAdded),
      'stats.boardTasksDoneCount': FieldValue.increment(tasksDone),
      'stats.boardTasksDeletedCount': FieldValue.increment(tasksDeleted),
      'stats.boardStepsCount': FieldValue.increment(stepsAdded),
      'stats.boardStepsDoneCount': FieldValue.increment(stepsDone),
      'stats.boardStepsDeletedCount': FieldValue.increment(stepsDeleted),
      'stats.boardMessageCount': FieldValue.increment(messagesSent),
    };

    await _boardCollection.doc(boardId).update(incrementData);
    debugPrint('[BoardStatsService] Stats incremented successfully');
  }

  /// Reset stats to zero
  Future<void> resetStats(String boardId) async {
    await _boardCollection.doc(boardId).update({'stats': BoardStats().toMap()});
  }

  /// "Delete" stats (optional) — just reset to zero
  Future<void> deleteStats(String boardId) async {
    await resetStats(boardId);
  }
}

