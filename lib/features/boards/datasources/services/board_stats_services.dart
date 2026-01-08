import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/board_stats_model.dart';

class BoardStatsService {
  final CollectionReference _boardCollection = FirebaseFirestore.instance
      .collection('boards');

  /// Fetch the stats for a specific board
  Future<BoardStats> getStats(String boardId) async {
    print('[BoardStatsService] Fetching stats for boardId: $boardId');
    final doc = await _boardCollection.doc(boardId).get();

    if (!doc.exists) {
      print('[BoardStatsService] Board document does not exist');
      return BoardStats();
    }

    final data = doc.get('stats') as Map<String, dynamic>? ?? {};
    print('[BoardStatsService] Stats data: $data');
    return BoardStats.fromMap(Map<String, dynamic>.from(data));
  }

  /// Stream stats for a board
  Stream<BoardStats> streamStatsByBoardId(String boardId) {
    print('[BoardStatsService] Starting stream for boardId: $boardId');
    return _boardCollection.doc(boardId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        print('[BoardStatsService] Board document does not exist in stream');
        return BoardStats();
      }
      final data = snapshot.get('stats') as Map<String, dynamic>? ?? {};
      print('[BoardStatsService] Stream stats data: $data');
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
    int subtasksAdded = 0,
    int subtasksDone = 0,
    int subtasksDeleted = 0,
    int messagesSent = 0,
  }) async {
    print('[BoardStatsService] incrementStats called for boardId: $boardId');
    print(
      '[BoardStatsService] tasksAdded=$tasksAdded, tasksDone=$tasksDone, tasksDeleted=$tasksDeleted',
    );

    final Map<String, dynamic> incrementData = {
      'stats.boardTasksCount': FieldValue.increment(tasksAdded),
      'stats.boardTasksDoneCount': FieldValue.increment(tasksDone),
      'stats.boardTasksDeletedCount': FieldValue.increment(tasksDeleted),
      'stats.boardSubtasksCount': FieldValue.increment(subtasksAdded),
      'stats.boardSubtasksDoneCount': FieldValue.increment(subtasksDone),
      'stats.boardSubtasksDeletedCount': FieldValue.increment(subtasksDeleted),
      'stats.boardMessageCount': FieldValue.increment(messagesSent),
    };

    await _boardCollection.doc(boardId).update(incrementData);
    print('[BoardStatsService] Stats incremented successfully');
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
