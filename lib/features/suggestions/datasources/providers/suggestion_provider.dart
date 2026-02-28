import 'dart:async';

import 'package:flutter/foundation.dart';
import '../models/suggestion_model.dart';
import '../services/suggestion_service.dart';

class SuggestionProvider extends ChangeNotifier {
  final SuggestionService _service = SuggestionService();

  List<Suggestion> _suggestions = [];
  bool _isLoading = false;
  String? _error;

  StreamSubscription<List<Suggestion>>? _subscription;
  String? _mode;
  String? _modeKey;

  List<Suggestion> get suggestions => _suggestions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void listenToBoardSuggestions(String boardId, {bool includeResolved = true}) {
    final modeKey = '$boardId|$includeResolved';
    if (_mode == 'board' && _modeKey == modeKey) {
      return;
    }

    _subscription?.cancel();
    _mode = 'board';
    _modeKey = modeKey;
    _setLoading(true);

    _subscription = _service
        .streamBoardSuggestions(boardId, includeResolved: includeResolved)
        .listen(
          (data) {
            _suggestions = data;
            _error = null;
            debugPrint(
              '[SuggestionProvider] board stream update: ${data.length} suggestion(s) for board $boardId',
            );
            _setLoading(false);
          },
          onError: (error) {
            debugPrint('[SuggestionProvider] stream board error: $error');
            _error = error.toString();
            _setLoading(false);
          },
        );
  }

  void listenToUserSuggestions(String userId, {String? boardId}) {
    final modeKey = '$userId|${boardId ?? ''}';
    if (_mode == 'user' && _modeKey == modeKey) {
      return;
    }

    _subscription?.cancel();
    _mode = 'user';
    _modeKey = modeKey;
    _setLoading(true);

    _subscription = _service
        .streamUserSuggestions(userId, boardId: boardId)
        .listen(
          (data) {
            _suggestions = data;
            _error = null;
            _setLoading(false);
          },
          onError: (error) {
            debugPrint('[SuggestionProvider] stream user error: $error');
            _error = error.toString();
            _setLoading(false);
          },
        );
  }

  Future<void> addSuggestion(Suggestion suggestion) async {
    try {
      _setLoading(true);
      await _service.addSuggestion(suggestion);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('[SuggestionProvider] add error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateSuggestion(Suggestion suggestion) async {
    try {
      _setLoading(true);
      await _service.updateSuggestion(suggestion);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('[SuggestionProvider] update error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> softDeleteSuggestion(String suggestionId) async {
    try {
      _setLoading(true);
      await _service.softDeleteSuggestion(suggestionId);
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('[SuggestionProvider] delete error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> reviewSuggestion({
    required String suggestionId,
    required String status,
    required String reviewerId,
    String? reviewNote,
    String? convertedTaskId,
  }) async {
    try {
      _setLoading(true);
      await _service.reviewSuggestion(
        suggestionId: suggestionId,
        status: status,
        reviewerId: reviewerId,
        reviewNote: reviewNote,
        convertedTaskId: convertedTaskId,
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('[SuggestionProvider] review error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void clear() {
    _suggestions = [];
    _error = null;
    _mode = null;
    _modeKey = null;
    notifyListeners();
  }
}
