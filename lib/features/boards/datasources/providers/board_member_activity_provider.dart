import 'package:flutter/foundation.dart';
import '../../../../shared/features/users/datasources/models/activity_event_model.dart';
import '../services/board_member_activity_service.dart';

class BoardMemberActivityProvider extends ChangeNotifier {
  final BoardMemberActivityService _service = BoardMemberActivityService();

  List<ActivityEvent> _boardMemberActivities = [];
  List<ActivityEvent> _boardActivities = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<ActivityEvent> get boardMemberActivities => _boardMemberActivities;
  List<ActivityEvent> get boardActivities => _boardActivities;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get board member activities (one-time fetch)
  Future<void> getBoardMemberActivities({
    required String boardId,
    required String memberId,
    int limit = 50,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('[DEBUG] BoardMemberActivityProvider: Fetching activities for member=$memberId');
      _boardMemberActivities = await _service.getBoardMemberActivities(
        boardId: boardId,
        memberId: memberId,
        limit: limit,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      print('[ERROR] BoardMemberActivityProvider: $e');
      notifyListeners();
    }
  }

  /// Get all board activities (one-time fetch)
  Future<void> getBoardActivities({
    required String boardId,
    int limit = 100,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('[DEBUG] BoardMemberActivityProvider: Fetching all board activities');
      _boardActivities = await _service.getBoardActivities(
        boardId: boardId,
        limit: limit,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      print('[ERROR] BoardMemberActivityProvider: $e');
      notifyListeners();
    }
  }

  /// Stream board member activities
  Stream<List<ActivityEvent>> streamBoardMemberActivities({
    required String boardId,
    required String memberId,
    int limit = 50,
  }) {
    print('[DEBUG] BoardMemberActivityProvider: Streaming member activities');
    return _service.streamBoardMemberActivities(
      boardId: boardId,
      memberId: memberId,
      limit: limit,
    );
  }

  /// Stream all board activities
  Stream<List<ActivityEvent>> streamBoardActivities({
    required String boardId,
    int limit = 100,
  }) {
    print('[DEBUG] BoardMemberActivityProvider: Streaming board activities');
    return _service.streamBoardActivities(
      boardId: boardId,
      limit: limit,
    );
  }

  /// Get activities filtered by type
  Future<void> getBoardActivitiesByType({
    required String boardId,
    required String activityType,
    int limit = 50,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('[DEBUG] BoardMemberActivityProvider: Fetching $activityType activities');
      _boardActivities = await _service.getBoardActivitiesByType(
        boardId: boardId,
        activityType: activityType,
        limit: limit,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      print('[ERROR] BoardMemberActivityProvider: $e');
      notifyListeners();
    }
  }

  /// Clear activities
  void clearActivities() {
    _boardMemberActivities = [];
    _boardActivities = [];
    _error = null;
    notifyListeners();
  }
}
