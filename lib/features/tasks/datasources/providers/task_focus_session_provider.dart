import 'package:flutter/foundation.dart';
import '../models/task_focus_session_model.dart';
import '../services/task_focus_session_service.dart';

class TaskFocusSessionProvider extends ChangeNotifier {
  final TaskFocusSessionService _focusSessionService = TaskFocusSessionService();

  List<TaskFocusSession> _focusSessions = [];
  List<TaskFocusSession> get focusSessions => _focusSessions;

  TaskFocusSession? _currentFocusSession;
  TaskFocusSession? get currentFocusSession => _currentFocusSession;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Stream<List<TaskFocusSession>>? _focusSessionStream;
  Stream<List<TaskFocusSession>>? get focusSessionStream => _focusSessionStream;

  void _setLoading(bool value) {
    print('[DEBUG] TaskFocusSessionProvider: _setLoading called with value = $value');
    _isLoading = value;
    notifyListeners();
  }

  Future<String> startFocusSession({
    required String taskId,
    required String userId,
    required int plannedDurationMinutes,
  }) async {
    try {
      print('[DEBUG] TaskFocusSessionProvider: startFocusSession for taskId = $taskId');
      final sessionId = '${taskId}_${DateTime.now().millisecondsSinceEpoch}';
      
      final focusSession = TaskFocusSession(
        focusSessionId: sessionId,
        taskId: taskId,
        userId: userId,
        focusStartedAt: DateTime.now(),
        focusPlannedDurationMinutes: plannedDurationMinutes,
        focusSessionCreatedAt: DateTime.now(),
      );

      await _focusSessionService.startFocusSession(focusSession);
      _currentFocusSession = focusSession;
      notifyListeners();
      
      print('✅ Focus session started: $sessionId');
      return sessionId;
    } catch (e) {
      print('⚠️ Error starting focus session: $e');
      rethrow;
    }
  }

  Future<void> endFocusSession({
    required int actualDurationMinutes,
    required bool wasCompleted,
    required String endReason,
    required int productivityScore,
    String? notes,
  }) async {
    try {
      if (_currentFocusSession == null) {
        throw Exception('No active focus session');
      }

      print('[DEBUG] TaskFocusSessionProvider: endFocusSession for sessionId = ${_currentFocusSession!.focusSessionId}');
      
      await _focusSessionService.endFocusSession(
        _currentFocusSession!.focusSessionId,
        actualDurationMinutes: actualDurationMinutes,
        wasCompleted: wasCompleted,
        endReason: endReason,
        productivityScore: productivityScore,
        notes: notes,
      );

      _currentFocusSession = null;
      notifyListeners();
      
      print('✅ Focus session ended');
    } catch (e) {
      print('⚠️ Error ending focus session: $e');
      rethrow;
    }
  }

  void streamTaskFocusSessions(String taskId) {
    print('[DEBUG] TaskFocusSessionProvider: streamTaskFocusSessions for taskId = $taskId');
    _setLoading(true);
    _focusSessionStream = _focusSessionService.streamTaskFocusSessions(taskId);
    _focusSessionStream!.listen((sessions) {
      print('[DEBUG] TaskFocusSessionProvider: Received ${sessions.length} focus sessions');
      _focusSessions = sessions;
      _setLoading(false);
      notifyListeners();
    });
  }

  void streamUserFocusSessions(String userId) {
    print('[DEBUG] TaskFocusSessionProvider: streamUserFocusSessions for userId = $userId');
    _setLoading(true);
    _focusSessionStream = _focusSessionService.streamUserFocusSessions(userId);
    _focusSessionStream!.listen((sessions) {
      print('[DEBUG] TaskFocusSessionProvider: Received ${sessions.length} focus sessions for user');
      _focusSessions = sessions;
      _setLoading(false);
      notifyListeners();
    });
  }

  Map<String, dynamic> getTaskProductivityStats(String taskId) {
    final taskSessions = _focusSessions.where((s) => s.taskId == taskId).toList();
    
    if (taskSessions.isEmpty) {
      return {
        'totalSessions': 0,
        'completedSessions': 0,
        'averageProductivityScore': 0.0,
        'totalFocusMinutes': 0,
      };
    }

    final completedCount = taskSessions.where((s) => s.focusWasCompleted).length;
    final avgScore = taskSessions.isEmpty
        ? 0.0
        : taskSessions
                .where((s) => s.focusProductivityScore > 0)
                .fold<int>(0, (sum, s) => sum + s.focusProductivityScore) /
            taskSessions.length;
    final totalMinutes = taskSessions.fold<int>(0, (sum, s) => sum + s.focusActualDurationMinutes);

    return {
      'totalSessions': taskSessions.length,
      'completedSessions': completedCount,
      'completionRate': (completedCount / taskSessions.length * 100).toStringAsFixed(1),
      'averageProductivityScore': avgScore.toStringAsFixed(1),
      'totalFocusMinutes': totalMinutes,
    };
  }
}
