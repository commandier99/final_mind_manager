import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_stats_model.dart';

class TaskStatsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _taskStats => _firestore.collection('task_stats');

  /// Add TaskStats for a given task
  Future<void> addTaskStats(String taskId, TaskStats taskStats) async {
    try {
      await _taskStats.doc(taskId).set(taskStats.toMap());
      print('✅ Task stats for $taskId added successfully');
    } catch (e) {
      print('⚠️ Error adding task stats for $taskId: $e');
    }
  }

  /// Update TaskStats for a given task
  Future<void> updateTaskStats(String taskId, TaskStats taskStats) async {
    try {
      await _taskStats.doc(taskId).update(taskStats.toMap());
      print('✅ Task stats for $taskId updated successfully');
    } catch (e) {
      print('⚠️ Error updating task stats for $taskId: $e');
    }
  }

  /// Fetch TaskStats for a given task
  Future<TaskStats?> getTaskStatsById(String taskId) async {
    try {
      final docSnapshot = await _taskStats.doc(taskId).get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return TaskStats.fromMap(docSnapshot.data() as Map<String, dynamic>);
      }
    } catch (e) {
      print('⚠️ Error fetching task stats for $taskId: $e');
    }
    return null;
  }

  /// Increment task edits count (as an example)
  Future<void> incrementEditsCount(String taskId) async {
    try {
      final taskStats = await getTaskStatsById(taskId);
      if (taskStats != null) {
        final updatedStats = taskStats.copyWith(taskEditsCount: (taskStats.taskEditsCount ?? 0) + 1);
        await updateTaskStats(taskId, updatedStats);
        print('✅ Task stats for $taskId edits count incremented');
      }
    } catch (e) {
      print('⚠️ Error incrementing task stats for $taskId: $e');
    }
  }

  /// Increment subtask counts (completed or deleted)
  Future<void> incrementSubtaskCount(String taskId, {int completed = 0, int deleted = 0}) async {
    try {
      final taskStats = await getTaskStatsById(taskId);
      if (taskStats != null) {
        final updatedStats = taskStats.copyWith(
          taskSubtasksCount: (taskStats.taskSubtasksCount ?? 0) + 1,
          taskSubtasksDoneCount: (taskStats.taskSubtasksDoneCount ?? 0) + completed,
          taskSubtasksDeletedCount: (taskStats.taskSubtasksDeletedCount ?? 0) + deleted,
        );
        await updateTaskStats(taskId, updatedStats);
        print('✅ Task stats for $taskId subtask count incremented');
      }
    } catch (e) {
      print('⚠️ Error incrementing subtask count for $taskId: $e');
    }
  }

  /// Delete TaskStats for a given task (hard delete stats)
  Future<void> deleteTaskStats(String taskId) async {
    try {
      // Delete task stats from the 'task_stats' collection
      await _taskStats.doc(taskId).delete();
      print('✅ Task stats for $taskId permanently deleted');
    } catch (e) {
      print('⚠️ Error deleting task stats for $taskId: $e');
    }
  }
}
