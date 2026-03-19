import 'package:flutter/material.dart';
import 'dart:async';
import '../models/board_model.dart';
import '../models/board_stats_model.dart';
import '../services/board_services.dart';
import 'package:flutter/foundation.dart';

class BoardProvider extends ChangeNotifier {
  final BoardService _boardService = BoardService();

  List<Board> _boards = [];
  List<Board> get boards => _boards;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  StreamSubscription<List<Board>>? _boardsSubscription;

  BoardProvider() {
    _init();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _init() {
    final userId = _boardService.currentUserId;
    if (userId != null) {
      // Stream all boards where user is either manager or member
      _boardsSubscription?.cancel();
      _boardsSubscription = _boardService
          .streamUserBoardsWithMembership(userId)
          .listen(
            (boardList) {
              _boards = boardList;
              notifyListeners();
            },
            onError: (error) {
              debugPrint('[BoardProvider] Error streaming boards: $error');
            },
          );
    }
  }

  /// ------------------------
  /// MANUAL REFRESH
  /// ------------------------
  Future<void> refreshBoards() async {
    _setLoading(true);
    try {
      final userId = _boardService.currentUserId;
      if (userId != null) {
        _boards = await _boardService.getBoardsForUserWithMembership(userId);
      } else {
        _boards = [];
      }
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// ------------------------
  /// CREATE
  /// ------------------------
  Future<void> addBoard({
    String? title,
    String? goal,
    String? description,
    String? boardType,
    String? boardPurpose,
  }) async {
    _setLoading(true);
    try {
      await _boardService.addBoard(
        boardTitle: title,
        boardGoal: goal,
        boardGoalDescription: description,
        boardType: boardType,
        boardPurpose: boardPurpose,
      );
      await refreshBoards();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> duplicateBoard(Board board) async {
    await addBoard(
      title: _duplicateTitle(board.boardTitle),
      goal: board.boardGoal,
      description: board.boardGoalDescription,
      boardType: board.boardType,
      boardPurpose: board.boardPurpose,
    );
  }

  String _duplicateTitle(String title) {
    const copySuffix = ' (Copy)';
    return title.endsWith(copySuffix) ? title : '$title$copySuffix';
  }

  /// ------------------------
  /// UPDATE
  /// ------------------------
  Future<void> updateBoard({
    required Board board,
    String? newTitle,
    String? newGoal,
    String? newGoalDescription,
    BoardStats? newStats,
    Map<String, String>? memberRoles,
    int? boardTaskCapacity,
  }) async {
    _setLoading(true);
    try {
      await _boardService.updateBoard(
        board.boardId,
        newTitle: newTitle,
        newGoal: newGoal,
        newGoalDescription: newGoalDescription,
        newStats: newStats,
        memberRoles: memberRoles,
        boardTaskCapacity: boardTaskCapacity,
      );
      await refreshBoards();
    } finally {
      _setLoading(false);
    }
  }

  /// ------------------------
  /// MEMBERS MANAGEMENT
  /// ------------------------
  Future<void> addMemberToBoard({
    required String boardId,
    required String userId,
  }) async {
    _setLoading(true);
    try {
      await _boardService.addMemberToBoard(boardId: boardId, userId: userId);
      await refreshBoards();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> removeMemberFromBoard({
    required String boardId,
    required String userId,
  }) async {
    _setLoading(true);
    try {
      await _boardService.removeMemberFromBoard(
        boardId: boardId,
        userId: userId,
      );
      await refreshBoards();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> isMember({required Board board, required String userId}) async {
    return _boardService.isMember(board: board, userId: userId);
  }

  /// ------------------------
  /// SOFT DELETE / RESTORE
  /// ------------------------
  Future<void> softDeleteBoard(Board board) async {
    _setLoading(true);
    try {
      await _boardService.softDeleteBoard(board);
      await refreshBoards();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> restoreBoard(Board board) async {
    _setLoading(true);
    try {
      await _boardService.restoreBoard(board);
      await refreshBoards();
    } finally {
      _setLoading(false);
    }
  }

  /// ------------------------
  /// DELETE
  /// ------------------------
  Future<void> deleteBoard(String boardId) async {
    _setLoading(true);
    try {
      await _boardService.deleteBoard(boardId);
      await refreshBoards();
    } finally {
      _setLoading(false);
    }
  }

  /// ------------------------
  /// UTILS
  /// ------------------------
  Board? getBoardById(String id) {
    try {
      return _boards.firstWhere((b) => b.boardId == id);
    } catch (_) {
      return null;
    }
  }

  /// ------------------------
  /// ONE-TIME MIGRATION: Initialize stats for existing boards
  /// ------------------------
  Future<void> initializeStatsForAllBoards() async {
    debugPrint(
      '[BoardProvider] Starting stats initialization for all boards...',
    );
    _setLoading(true);

    try {
      for (var board in _boards) {
        if (board.stats.boardTasksCount == 0 &&
            board.stats.boardTasksDoneCount == 0 &&
            board.stats.boardTasksDeletedCount == 0) {
          // Board likely doesn't have stats initialized
          await _boardService.updateBoard(
            board.boardId,
            newStats: BoardStats(), // Initialize with zeros
          );
          debugPrint(
            '[BoardProvider] Initialized stats for board ${board.boardId}',
          );
        }
      }
      await refreshBoards();
      debugPrint('[BoardProvider] Stats initialization complete!');
    } catch (e) {
      debugPrint('[BoardProvider] Error initializing stats: $e');
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _boardsSubscription?.cancel();
    super.dispose();
  }
}
