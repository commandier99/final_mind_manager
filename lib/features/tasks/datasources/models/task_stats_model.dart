class TaskStats {
  final int? taskSubtasksCount; // Total number of subtasks
  final int? taskSubtasksDoneCount; // Number of subtasks completed
  final int? taskSubtasksDeletedCount; // Number of deleted subtasks
  final int? taskEditsCount; // Number of times the task has been edited
  final int? deadlinesMissedCount; // Total times deadline was missed
  final int? deadlinesExtendedCount; // Total times deadline was extended
  final int? tasksFailedCount; // Total times task was marked as failed

  TaskStats({
    this.taskSubtasksCount,
    this.taskSubtasksDoneCount,
    this.taskSubtasksDeletedCount,
    this.taskEditsCount,
    this.deadlinesMissedCount,
    this.deadlinesExtendedCount,
    this.tasksFailedCount,
  });

  // Factory method to create TaskStats from Firestore data
  factory TaskStats.fromMap(Map<String, dynamic> data) {
    return TaskStats(
      taskSubtasksCount: data['taskSubtasksCount'] as int?,
      taskSubtasksDoneCount: data['taskSubtasksDoneCount'] as int?,
      taskSubtasksDeletedCount: data['taskSubtasksDeletedCount'] as int?,
      taskEditsCount: data['taskEditsCount'] as int?,
      deadlinesMissedCount: data['deadlinesMissedCount'] as int?,
      deadlinesExtendedCount: data['deadlinesExtendedCount'] as int?,
      tasksFailedCount: data['tasksFailedCount'] as int?,
    );
  }

  // Convert TaskStats object to Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'taskSubtasksCount': taskSubtasksCount,
      'taskSubtasksDoneCount': taskSubtasksDoneCount,
      'taskSubtasksDeletedCount': taskSubtasksDeletedCount,
      'taskEditsCount': taskEditsCount,
      'deadlinesMissedCount': deadlinesMissedCount,
      'deadlinesExtendedCount': deadlinesExtendedCount,
      'tasksFailedCount': tasksFailedCount,
    };
  }

  // Helper method to create a copy of TaskStats with updated values
  TaskStats copyWith({
    int? taskSubtasksCount,
    int? taskSubtasksDoneCount,
    int? taskSubtasksDeletedCount,
    int? taskEditsCount,
    int? deadlinesMissedCount,
    int? deadlinesExtendedCount,
    int? tasksFailedCount,
  }) {
    return TaskStats(
      taskSubtasksCount: taskSubtasksCount ?? this.taskSubtasksCount,
      taskSubtasksDoneCount:
          taskSubtasksDoneCount ?? this.taskSubtasksDoneCount,
      taskSubtasksDeletedCount:
          taskSubtasksDeletedCount ?? this.taskSubtasksDeletedCount,
      taskEditsCount: taskEditsCount ?? this.taskEditsCount,
      deadlinesMissedCount: deadlinesMissedCount ?? this.deadlinesMissedCount,
      deadlinesExtendedCount:
          deadlinesExtendedCount ?? this.deadlinesExtendedCount,
      tasksFailedCount: tasksFailedCount ?? this.tasksFailedCount,
    );
  }

  // Helper method to check if stats are initialized
  bool get isInitialized =>
      taskSubtasksCount != null ||
      taskSubtasksDoneCount != null ||
      taskSubtasksDeletedCount != null ||
      taskEditsCount != null;
}
