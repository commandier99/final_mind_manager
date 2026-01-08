import 'package:flutter/material.dart';
import '../models/board_model.dart';
import '../models/board_stats_model.dart';
import '../services/board_services.dart';

class BoardProvider extends ChangeNotifier {
  final BoardService _boardService = BoardService();

  List<Board> _boards = [];
  List<Board> get boards => _boards;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

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
      _boardService.streamUserBoardsWithMembership(userId).listen((boardList) {
        _boards = boardList;
        notifyListeners();
      });
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
  }) async {
    _setLoading(true);
    try {
      await _boardService.addBoard(
        boardTitle: title,
        boardGoal: goal,
        boardGoalDescription: description,
      );
      await refreshBoards();
    } finally {
      _setLoading(false);
    }
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
  }) async {
    _setLoading(true);
    try {
      await _boardService.updateBoard(
        board.boardId,
        newTitle: newTitle,
        newGoal: newGoal,
        newGoalDescription: newGoalDescription,
        newStats: newStats,
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
    print('[BoardProvider] Starting stats initialization for all boards...');
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
          print('[BoardProvider] Initialized stats for board ${board.boardId}');
        }
      }
      await refreshBoards();
      print('[BoardProvider] Stats initialization complete!');
    } catch (e) {
      print('[BoardProvider] Error initializing stats: $e');
    } finally {
      _setLoading(false);
    }
  }
}
