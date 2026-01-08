import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/task_stats_model.dart';
import '../services/task_stats_services.dart';

class TaskStatsProvider extends ChangeNotifier {
  final TaskStatsService _service = TaskStatsService();

  // Store task stats in a map (cached by taskId)
  final Map<String, TaskStats> _taskStats = {};
  Map<String, TaskStats> get taskStats => _taskStats;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Fetch stats for a single task
  Future<void> fetchTaskStats(String taskId) async {
    _setLoading(true);
    final stats = await _service.getTaskStatsById(taskId);
    if (stats != null) {
      _taskStats[taskId] = stats;
      notifyListeners();
    }
    _setLoading(false);
  }

  /// Update stats for a task
  Future<void> updateTaskStats(String taskId, TaskStats stats) async {
    await _service.updateTaskStats(taskId, stats);
    _taskStats[taskId] = stats;
    notifyListeners();
  }

  /// Increment task edit count
  Future<void> incrementTimesEdited(String taskId) async {
    await _service.incrementEditsCount(taskId);
    final current = _taskStats[taskId] ?? TaskStats();
    _taskStats[taskId] = current.copyWith(taskEditsCount: (current.taskEditsCount ?? 0) + 1);
    notifyListeners();
  }

  /// Increment subtask counts (completed or deleted)
  Future<void> incrementSubtaskCount(String taskId, {int completed = 0, int deleted = 0}) async {
    await _service.incrementSubtaskCount(taskId, completed: completed, deleted: deleted);

    final current = _taskStats[taskId] ?? TaskStats();
    _taskStats[taskId] = current.copyWith(
      taskSubtasksCount: (current.taskSubtasksCount ?? 0) + 1,
      taskSubtasksDoneCount: (current.taskSubtasksDoneCount ?? 0) + completed,
      taskSubtasksDeletedCount: (current.taskSubtasksDeletedCount ?? 0) + deleted,
    );
    notifyListeners();
  }

  /// Optional: get cached stats
  TaskStats? getStats(String taskId) => _taskStats[taskId];
}
