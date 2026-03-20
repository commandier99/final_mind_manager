import 'package:flutter/material.dart';
import 'dart:async';
import '../models/board_stats_model.dart';
import '../services/board_stats_services.dart';
import 'package:flutter/foundation.dart';

class BoardStatsProvider extends ChangeNotifier {
  final BoardStatsService _statsService = BoardStatsService();

  final Map<String, BoardStats> _stats = {};
  Map<String, BoardStats> get stats => _stats;
  final Map<String, StreamSubscription<BoardStats>> _subscriptions = {};

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
    debugPrint(
      '[BoardStatsProvider] fetchBoardStats called for boardId: $boardId',
    );
    _setLoading(true);

    try {
      final boardStats = await _statsService.getStats(boardId);
      debugPrint(
        '[BoardStatsProvider] Fetched stats: taskCount=${boardStats.boardTasksCount}, tasksDone=${boardStats.boardTasksDoneCount}',
      );
      _stats[boardId] = boardStats;
      notifyListeners();
    } catch (e) {
      debugPrint('[BoardStatsProvider] Error fetching stats: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ------------------------
  // STREAM STATS FOR A BOARD
  // ------------------------
  void streamStatsForBoard(String boardId) {
    debugPrint(
      '[BoardStatsProvider] streamStatsForBoard called for boardId: $boardId',
    );
    if (_subscriptions.containsKey(boardId)) {
      debugPrint(
        '[BoardStatsProvider] Subscription already active for boardId: $boardId',
      );
      return;
    }

    _subscriptions[boardId] = _statsService
        .streamStatsByBoardId(boardId)
        .listen(
          (boardStats) {
            debugPrint(
              '[BoardStatsProvider] Stream update: taskCount=${boardStats.boardTasksCount}, tasksDone=${boardStats.boardTasksDoneCount}',
            );
            _stats[boardId] = boardStats;
            notifyListeners();
          },
          onError: (error) {
            debugPrint(
              '[BoardStatsProvider] Stream error for board $boardId: $error',
            );
            _subscriptions.remove(boardId);
            _stats.remove(boardId);
            notifyListeners();
          },
        );
  }

  void stopStreamingBoard(String boardId) {
    debugPrint('[BoardStatsProvider] stopStreamingBoard called for $boardId');
    _subscriptions.remove(boardId)?.cancel();
  }

  void syncStreamingBoards(Iterable<String> boardIds) {
    final nextIds = boardIds.toSet();
    debugPrint(
      '[BoardStatsProvider] syncStreamingBoards nextIds=$nextIds active=${_subscriptions.keys.toSet()}',
    );

    for (final boardId in _subscriptions.keys.toList()) {
      if (!nextIds.contains(boardId)) {
        debugPrint(
          '[BoardStatsProvider] Cancelling stale stats subscription for $boardId',
        );
        _subscriptions.remove(boardId)?.cancel();
        _stats.remove(boardId);
      }
    }
  }

  void clear() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _stats.clear();
    _isLoading = false;
    notifyListeners();
  }

  // ------------------------
  // UPDATE STATS
  // ------------------------
  Future<void> updateStats({
    required String boardId,
    int? boardTasksCount,
    int? boardTasksDoneCount,
    int? boardTasksDeletedCount,
    int? boardStepsCount,
    int? boardStepsDoneCount,
    int? boardStepsDeletedCount,
    int? boardMessageCount,
  }) async {
    _setLoading(true);

    try {
      final currentStats = _stats[boardId] ?? BoardStats();

      final updatedStats = currentStats.copyWith(
        boardTasksCount: boardTasksCount,
        boardTasksDoneCount: boardTasksDoneCount,
        boardTasksDeletedCount: boardTasksDeletedCount,
        boardStepsCount: boardStepsCount,
        boardStepsDoneCount: boardStepsDoneCount,
        boardStepsDeletedCount: boardStepsDeletedCount,
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
    int stepsAdded = 0,
    int stepsDone = 0,
    int stepsDeleted = 0,
    int messagesSent = 0,
  }) async {
    _setLoading(true);

    try {
      await _statsService.incrementStats(
        boardId,
        tasksAdded: tasksAdded,
        tasksDone: tasksDone,
        tasksDeleted: tasksDeleted,
        stepsAdded: stepsAdded,
        stepsDone: stepsDone,
        stepsDeleted: stepsDeleted,
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
    return _stats[boardId];
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}

