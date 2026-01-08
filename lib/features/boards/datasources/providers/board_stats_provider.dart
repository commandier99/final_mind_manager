import 'package:flutter/material.dart';
import '../models/board_stats_model.dart';
import '../services/board_stats_services.dart';

class BoardStatsProvider extends ChangeNotifier {
  final BoardStatsService _statsService = BoardStatsService();

  final Map<String, BoardStats> _stats = {};
  Map<String, BoardStats> get stats => _stats;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ------------------------
  // LOADING HELPER
  // ------------------------
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // ------------------------
  // FETCH STATS FOR A BOARD
  // ------------------------
  Future<void> fetchBoardStats(String boardId) async {
    print('[BoardStatsProvider] fetchBoardStats called for boardId: $boardId');
    _setLoading(true);

    try {
      final boardStats = await _statsService.getStats(boardId);
      print(
        '[BoardStatsProvider] Fetched stats: taskCount=${boardStats.boardTasksCount}, tasksDone=${boardStats.boardTasksDoneCount}',
      );
      _stats[boardId] = boardStats;
      notifyListeners();
    } catch (e) {
      print('[BoardStatsProvider] Error fetching stats: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ------------------------
  // STREAM STATS FOR A BOARD
  // ------------------------
  void streamStatsForBoard(String boardId) {
    print(
      '[BoardStatsProvider] streamStatsForBoard called for boardId: $boardId',
    );
    _statsService
        .streamStatsByBoardId(boardId)
        .listen(
          (boardStats) {
            print(
              '[BoardStatsProvider] Stream update: taskCount=${boardStats.boardTasksCount}, tasksDone=${boardStats.boardTasksDoneCount}',
            );
            _stats[boardId] = boardStats;
            notifyListeners();
          },
          onError: (error) {
            print('[BoardStatsProvider] Stream error: $error');
          },
        );
  }

  // ------------------------
  // UPDATE STATS
  // ------------------------
  Future<void> updateStats({
    required String boardId,
    int? boardTasksCount,
    int? boardTasksDoneCount,
    int? boardTasksDeletedCount,
    int? boardSubtasksCount,
    int? boardSubtasksDoneCount,
    int? boardSubtasksDeletedCount,
    int? boardMessageCount,
  }) async {
    _setLoading(true);

    try {
      final currentStats = _stats[boardId] ?? BoardStats();

      final updatedStats = currentStats.copyWith(
        boardTasksCount: boardTasksCount,
        boardTasksDoneCount: boardTasksDoneCount,
        boardTasksDeletedCount: boardTasksDeletedCount,
        boardSubtasksCount: boardSubtasksCount,
        boardSubtasksDoneCount: boardSubtasksDoneCount,
        boardSubtasksDeletedCount: boardSubtasksDeletedCount,
        boardMessageCount: boardMessageCount,
      );

      await _statsService.updateStats(boardId: boardId, stats: updatedStats);
    } finally {
      _setLoading(false);
    }
  }

  // ------------------------
  // INCREMENTAL UPDATES
  // ------------------------
  Future<void> incrementStats({
    required String boardId,
    int tasksAdded = 0,
    int tasksDone = 0,
    int tasksDeleted = 0,
    int subtasksAdded = 0,
    int subtasksDone = 0,
    int subtasksDeleted = 0,
    int messagesSent = 0,
  }) async {
    _setLoading(true);

    try {
      await _statsService.incrementStats(
        boardId,
        tasksAdded: tasksAdded,
        tasksDone: tasksDone,
        tasksDeleted: tasksDeleted,
        subtasksAdded: subtasksAdded,
        subtasksDone: subtasksDone,
        subtasksDeleted: subtasksDeleted,
        messagesSent: messagesSent,
      );
    } finally {
      _setLoading(false);
    }
  }

  // ------------------------
  // DELETE / RESET STATS
  // ------------------------
  Future<void> deleteStats(String boardId) async {
    _setLoading(true);

    try {
      await _statsService.deleteStats(boardId);
      _stats[boardId] = BoardStats();
    } finally {
      _setLoading(false);
    }
  }

  // ------------------------
  // UTILS
  // ------------------------
  BoardStats? getStatsForBoard(String boardId) {
    print(
      '[BoardStatsProvider] getStatsForBoard called for boardId: $boardId, stats: ${_stats[boardId]?.boardTasksCount ?? "null"}',
    );
    return _stats[boardId];
  }
}
