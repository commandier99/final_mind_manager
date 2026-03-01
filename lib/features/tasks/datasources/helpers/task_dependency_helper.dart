import '../models/task_model.dart';

class TaskDependencyHelper {
  static List<String> sanitizeDependencyIds(
    Iterable<String> dependencyIds, {
    String? selfTaskId,
  }) {
    final cleaned = <String>{};
    for (final id in dependencyIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty) continue;
      if (selfTaskId != null && trimmed == selfTaskId) continue;
      cleaned.add(trimmed);
    }
    return cleaned.toList();
  }

  static List<Task> unresolvedDependencies({
    required Task task,
    required Iterable<Task> tasks,
  }) {
    final byId = <String, Task>{for (final t in tasks) t.taskId: t};
    final unresolved = <Task>[];
    for (final dependencyId in task.taskDependencyIds) {
      final dependency = byId[dependencyId];
      if (dependency != null && !dependency.taskIsDone) {
        unresolved.add(dependency);
      }
    }
    return unresolved;
  }

  static Task? firstUnresolvedDependency({
    required Task task,
    required Iterable<Task> tasks,
  }) {
    final unresolved = unresolvedDependencies(task: task, tasks: tasks);
    return unresolved.isEmpty ? null : unresolved.first;
  }

  static bool wouldCreateCycle({
    required String taskId,
    required String candidateDependencyId,
    required Iterable<Task> tasks,
    Iterable<String>? selectedDependencies,
  }) {
    if (taskId == candidateDependencyId) return true;

    final adjacency = <String, List<String>>{};
    for (final task in tasks) {
      adjacency[task.taskId] = sanitizeDependencyIds(
        task.taskDependencyIds,
        selfTaskId: task.taskId,
      );
    }

    final current = selectedDependencies ?? adjacency[taskId] ?? const <String>[];
    final nextDependencies = sanitizeDependencyIds(
      <String>[...current, candidateDependencyId],
      selfTaskId: taskId,
    );
    adjacency[taskId] = nextDependencies;

    return _hasPath(
      sourceId: candidateDependencyId,
      targetId: taskId,
      adjacency: adjacency,
      visiting: <String>{},
    );
  }

  static bool _hasPath({
    required String sourceId,
    required String targetId,
    required Map<String, List<String>> adjacency,
    required Set<String> visiting,
  }) {
    if (sourceId == targetId) return true;
    if (visiting.contains(sourceId)) return false;
    visiting.add(sourceId);

    final next = adjacency[sourceId] ?? const <String>[];
    for (final id in next) {
      if (_hasPath(
        sourceId: id,
        targetId: targetId,
        adjacency: adjacency,
        visiting: visiting,
      )) {
        return true;
      }
    }
    return false;
  }
}
