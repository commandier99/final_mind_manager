import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/activity_event_model.dart';
import '../services/activity_event_services.dart';

class ActivityEventProvider extends ChangeNotifier {
  final ActivityEventService _service = ActivityEventService();

  List<ActivityEvent> _events = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<ActivityEvent>>? _subscription;

  List<ActivityEvent> get events => _events;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Listen to user events with proper subscription management
  void listenToUser(String userId) {
    print('[DEBUG] ActivityEventProvider: Starting event listener for userId: $userId');
    
    // Cancel existing subscription if any
    _subscription?.cancel();
    
    _subscription = _service.streamUserEvents(userId).listen(
      (data) {
        print('[DEBUG] ActivityEventProvider: Received ${data.length} events for userId: $userId');
        _events = data;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        print('[ERROR] ActivityEventProvider: Stream error - $error');
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  /// Listen to all board events (all members' activities) with proper subscription management
  void listenToBoard(String boardId) {
    print('[DEBUG] ActivityEventProvider: Starting event listener for boardId: $boardId');
    
    // Cancel existing subscription if any
    _subscription?.cancel();
    
    _subscription = _service.streamBoardEvents(boardId).listen(
      (data) {
        print('[DEBUG] ActivityEventProvider: Received ${data.length} events for boardId: $boardId');
        _events = data;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        print('[ERROR] ActivityEventProvider: Stream error - $error');
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  Future<void> getUserEvents(String userId, {int limit = 50}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _events = await _service.getUserEvents(userId, limit: limit);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      print('[ERROR] ActivityEventProvider: Failed to get user events - $e');
      notifyListeners();
    }
  }

  Future<void> logEvent({
    required String userId,
    required String userName,
    required String activityType,
    String? userProfilePicture,
    String? boardId,
    String? taskId,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _service.logEvent(
        userId: userId,
        userName: userName,
        activityType: activityType,
        userProfilePicture: userProfilePicture,
        boardId: boardId,
        taskId: taskId,
        description: description,
        metadata: metadata,
      );
      print('[DEBUG] ActivityEventProvider: Event logged successfully');
    } catch (e) {
      print('[ERROR] ActivityEventProvider: Failed to log event: $e');
      rethrow;
    }
  }

  void clear() {
    _events = [];
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    print('[DEBUG] ActivityEventProvider: Disposing - cancelling subscription');
    _subscription?.cancel();
    super.dispose();
  }
}
