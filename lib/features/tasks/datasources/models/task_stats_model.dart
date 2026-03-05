class TaskStats {
  final int? taskStepsCount; // Total number of steps
  final int? taskStepsDoneCount; // Number of steps completed
  final int? taskStepsDeletedCount; // Number of deleted steps
  final int? taskEditsCount; // Number of times the task has been edited
  final int? deadlinesMissedCount; // Total times deadline was missed
  final int? deadlinesExtendedCount; // Total times deadline was extended
  final int? tasksFailedCount; // Total times task was marked as failed

  TaskStats({
    this.taskStepsCount,
    this.taskStepsDoneCount,
    this.taskStepsDeletedCount,
    this.taskEditsCount,
    this.deadlinesMissedCount,
    this.deadlinesExtendedCount,
    this.tasksFailedCount,
  });

  // Factory method to create TaskStats from Firestore data
  factory TaskStats.fromMap(Map<String, dynamic> data) {
    return TaskStats(
      taskStepsCount: data['taskStepsCount'] as int?,
      taskStepsDoneCount: data['taskStepsDoneCount'] as int?,
      taskStepsDeletedCount: data['taskStepsDeletedCount'] as int?,
      taskEditsCount: data['taskEditsCount'] as int?,
      deadlinesMissedCount: data['deadlinesMissedCount'] as int?,
      deadlinesExtendedCount: data['deadlinesExtendedCount'] as int?,
      tasksFailedCount: data['tasksFailedCount'] as int?,
    );
  }

  // Convert TaskStats object to Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'taskStepsCount': taskStepsCount,
      'taskStepsDoneCount': taskStepsDoneCount,
      'taskStepsDeletedCount': taskStepsDeletedCount,
      'taskEditsCount': taskEditsCount,
      'deadlinesMissedCount': deadlinesMissedCount,
      'deadlinesExtendedCount': deadlinesExtendedCount,
      'tasksFailedCount': tasksFailedCount,
    };
  }

  // Helper method to create a copy of TaskStats with updated values
  TaskStats copyWith({
    int? taskStepsCount,
    int? taskStepsDoneCount,
    int? taskStepsDeletedCount,
    int? taskEditsCount,
    int? deadlinesMissedCount,
    int? deadlinesExtendedCount,
    int? tasksFailedCount,
  }) {
    return TaskStats(
      taskStepsCount: taskStepsCount ?? this.taskStepsCount,
      taskStepsDoneCount:
          taskStepsDoneCount ?? this.taskStepsDoneCount,
      taskStepsDeletedCount:
          taskStepsDeletedCount ?? this.taskStepsDeletedCount,
      taskEditsCount: taskEditsCount ?? this.taskEditsCount,
      deadlinesMissedCount: deadlinesMissedCount ?? this.deadlinesMissedCount,
      deadlinesExtendedCount:
          deadlinesExtendedCount ?? this.deadlinesExtendedCount,
      tasksFailedCount: tasksFailedCount ?? this.tasksFailedCount,
    );
  }

  // Helper method to check if stats are initialized
  bool get isInitialized =>
      taskStepsCount != null ||
      taskStepsDoneCount != null ||
      taskStepsDeletedCount != null ||
      taskEditsCount != null;
}

