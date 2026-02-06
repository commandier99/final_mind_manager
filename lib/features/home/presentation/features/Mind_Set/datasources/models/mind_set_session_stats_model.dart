class MindSetSessionStats {
  final int? tasksTotalCount;
  final int? tasksDoneCount;
  final int? sessionFocusDurationMinutes;
  final int? sessionFocusDurationSeconds;
  final int? pomodoroCount;

  const MindSetSessionStats({
    this.tasksTotalCount,
    this.tasksDoneCount,
    this.sessionFocusDurationMinutes,
    this.sessionFocusDurationSeconds,
    this.pomodoroCount,
  });

  factory MindSetSessionStats.fromMap(Map<String, dynamic> data) {
    return MindSetSessionStats(
      tasksTotalCount: data['tasksTotalCount'] as int?,
      tasksDoneCount: data['tasksDoneCount'] as int?,
      sessionFocusDurationMinutes:
          data['sessionFocusDurationMinutes'] as int?,
      sessionFocusDurationSeconds:
          data['sessionFocusDurationSeconds'] as int?,
      pomodoroCount: data['pomodoroCount'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tasksTotalCount': tasksTotalCount,
      'tasksDoneCount': tasksDoneCount,
      'sessionFocusDurationMinutes': sessionFocusDurationMinutes,
      'sessionFocusDurationSeconds': sessionFocusDurationSeconds,
      'pomodoroCount': pomodoroCount,
    };
  }

  MindSetSessionStats copyWith({
    int? tasksTotalCount,
    int? tasksDoneCount,
    int? sessionFocusDurationMinutes,
    int? sessionFocusDurationSeconds,
    int? pomodoroCount,
  }) {
    return MindSetSessionStats(
      tasksTotalCount: tasksTotalCount ?? this.tasksTotalCount,
      tasksDoneCount: tasksDoneCount ?? this.tasksDoneCount,
      sessionFocusDurationMinutes:
          sessionFocusDurationMinutes ?? this.sessionFocusDurationMinutes,
      sessionFocusDurationSeconds:
          sessionFocusDurationSeconds ?? this.sessionFocusDurationSeconds,
      pomodoroCount: pomodoroCount ?? this.pomodoroCount,
    );
  }
}
