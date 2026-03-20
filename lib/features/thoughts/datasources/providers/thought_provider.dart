import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/thought_model.dart';
import '../services/thought_service.dart';

class ThoughtProvider extends ChangeNotifier {
  ThoughtProvider({ThoughtService? service})
    : _service = service ?? ThoughtService();

  final ThoughtService _service;

  List<Thought> _thoughts = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<Thought>>? _subscription;

  String? _currentScopeType;
  String? _currentScopeId;

  List<Thought> get thoughts => _thoughts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Thought> thoughtsByType(String type) =>
      _thoughts.where((thought) => thought.type == type).toList();

  void streamThoughtsByBoard(String boardId) {
    if (_currentScopeType == Thought.scopeBoard && _currentScopeId == boardId) {
      return;
    }
    _listenToStream(
      scopeType: Thought.scopeBoard,
      scopeId: boardId,
      stream: _service.streamThoughtsByBoard(boardId),
    );
  }

  void streamThoughtsByTask(String taskId) {
    if (_currentScopeType == Thought.scopeTask && _currentScopeId == taskId) {
      return;
    }
    _listenToStream(
      scopeType: Thought.scopeTask,
      scopeId: taskId,
      stream: _service.streamThoughtsByTask(taskId),
    );
  }

  void streamThoughtsForUser(String userId) {
    if (_currentScopeType == Thought.scopeUser && _currentScopeId == userId) {
      return;
    }
    _listenToStream(
      scopeType: Thought.scopeUser,
      scopeId: userId,
      stream: _service.streamThoughtsForUser(userId),
    );
  }

  Future<String> createThought(Thought thought) async {
    try {
      _error = null;
      final id = await _service.createThought(thought);
      return id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Set<String>> getPendingBoardInviteTargetUserIds(String boardId) async {
    try {
      _error = null;
      return await _service.getPendingBoardInviteTargetUserIds(boardId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<int> countSubmissionThoughtsForTask(String taskId) async {
    try {
      _error = null;
      return await _service.countSubmissionThoughtsForTask(taskId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateThought(Thought thought) async {
    try {
      _error = null;
      await _service.updateThought(thought);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateThoughtStatus({
    required String thoughtId,
    required String status,
    required String actionedBy,
    required String actionedByName,
  }) async {
    try {
      _error = null;
      await _service.updateThoughtStatus(
        thoughtId: thoughtId,
        status: status,
        actionedBy: actionedBy,
        actionedByName: actionedByName,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> softDeleteThought(String thoughtId) async {
    try {
      _error = null;
      await _service.softDeleteThought(thoughtId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Thought?> getThoughtById(String thoughtId) async {
    try {
      _error = null;
      return await _service.getThoughtById(thoughtId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    _thoughts = [];
    _error = null;
    _currentScopeType = null;
    _currentScopeId = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _listenToStream({
    required String scopeType,
    required String scopeId,
    required Stream<List<Thought>> stream,
  }) {
    _subscription?.cancel();
    _currentScopeType = scopeType;
    _currentScopeId = scopeId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = stream.listen(
      (thoughts) {
        _thoughts = thoughts;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _thoughts = [];
        _isLoading = false;
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
