import 'package:cloud_firestore/cloud_firestore.dart';

class MindSetSessionStats {
  final int? tasksTotalCount;
  final int? tasksDoneCount;
  final int? tasksWorkedCount;
  final int? focusCount;
  final int? pauseCount;
  final int? switchCount;
  final int? checklistCompletedCount;
  final int? pomodoroCompletedCount;
  final int? eatTheFrogCompletedCount;
  final int? sessionFocusDurationMinutes;
  final int? sessionFocusDurationSeconds;
  final int? pomodoroCount;
  final int? pomodoroTargetCount;
  final int? pomodoroFocusMinutes;
  final int? pomodoroBreakMinutes;
  final int? pomodoroLongBreakMinutes;
  final int? pomodoroRemainingSeconds;
  final bool? pomodoroIsRunning;
  final bool? pomodoroIsOnBreak;
  final bool? pomodoroIsLongBreak;
  final String? pomodoroMotivation;
  final DateTime? pomodoroLastUpdatedAt;
  final List<Map<String, dynamic>> pomodoroCustomPresets;

  const MindSetSessionStats({
    this.tasksTotalCount,
    this.tasksDoneCount,
    this.tasksWorkedCount,
    this.focusCount,
    this.pauseCount,
    this.switchCount,
    this.checklistCompletedCount,
    this.pomodoroCompletedCount,
    this.eatTheFrogCompletedCount,
    this.sessionFocusDurationMinutes,
    this.sessionFocusDurationSeconds,
    this.pomodoroCount,
    this.pomodoroTargetCount,
    this.pomodoroFocusMinutes,
    this.pomodoroBreakMinutes,
    this.pomodoroLongBreakMinutes,
    this.pomodoroRemainingSeconds,
    this.pomodoroIsRunning,
    this.pomodoroIsOnBreak,
    this.pomodoroIsLongBreak,
    this.pomodoroMotivation,
    this.pomodoroLastUpdatedAt,
    this.pomodoroCustomPresets = const [],
  });

  factory MindSetSessionStats.fromMap(Map<String, dynamic> data) {
    return MindSetSessionStats(
      tasksTotalCount: data['tasksTotalCount'] as int?,
      tasksDoneCount: data['tasksDoneCount'] as int?,
      tasksWorkedCount: data['tasksWorkedCount'] as int?,
      focusCount: data['focusCount'] as int?,
      pauseCount: data['pauseCount'] as int?,
      switchCount: data['switchCount'] as int?,
      checklistCompletedCount: data['checklistCompletedCount'] as int?,
      pomodoroCompletedCount: data['pomodoroCompletedCount'] as int?,
      eatTheFrogCompletedCount: data['eatTheFrogCompletedCount'] as int?,
      sessionFocusDurationMinutes: data['sessionFocusDurationMinutes'] as int?,
      sessionFocusDurationSeconds: data['sessionFocusDurationSeconds'] as int?,
      pomodoroCount: data['pomodoroCount'] as int?,
      pomodoroTargetCount: data['pomodoroTargetCount'] as int?,
      pomodoroFocusMinutes: data['pomodoroFocusMinutes'] as int?,
      pomodoroBreakMinutes: data['pomodoroBreakMinutes'] as int?,
      pomodoroLongBreakMinutes: data['pomodoroLongBreakMinutes'] as int?,
      pomodoroRemainingSeconds: data['pomodoroRemainingSeconds'] as int?,
      pomodoroIsRunning: data['pomodoroIsRunning'] as bool?,
      pomodoroIsOnBreak: data['pomodoroIsOnBreak'] as bool?,
      pomodoroIsLongBreak: data['pomodoroIsLongBreak'] as bool?,
      pomodoroMotivation: data['pomodoroMotivation'] as String?,
      pomodoroCustomPresets:
          (data['pomodoroCustomPresets'] as List<dynamic>?)
              ?.map((entry) => Map<String, dynamic>.from(entry as Map))
              .toList() ??
          const [],
      pomodoroLastUpdatedAt: data['pomodoroLastUpdatedAt'] != null
          ? (data['pomodoroLastUpdatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tasksTotalCount': tasksTotalCount,
      'tasksDoneCount': tasksDoneCount,
      'tasksWorkedCount': tasksWorkedCount,
      'focusCount': focusCount,
      'pauseCount': pauseCount,
      'switchCount': switchCount,
      'checklistCompletedCount': checklistCompletedCount,
      'pomodoroCompletedCount': pomodoroCompletedCount,
      'eatTheFrogCompletedCount': eatTheFrogCompletedCount,
      'sessionFocusDurationMinutes': sessionFocusDurationMinutes,
      'sessionFocusDurationSeconds': sessionFocusDurationSeconds,
      'pomodoroCount': pomodoroCount,
      'pomodoroTargetCount': pomodoroTargetCount,
      'pomodoroFocusMinutes': pomodoroFocusMinutes,
      'pomodoroBreakMinutes': pomodoroBreakMinutes,
      'pomodoroLongBreakMinutes': pomodoroLongBreakMinutes,
      'pomodoroRemainingSeconds': pomodoroRemainingSeconds,
      'pomodoroIsRunning': pomodoroIsRunning,
      'pomodoroIsOnBreak': pomodoroIsOnBreak,
      'pomodoroIsLongBreak': pomodoroIsLongBreak,
      'pomodoroMotivation': pomodoroMotivation,
      'pomodoroCustomPresets': pomodoroCustomPresets,
      'pomodoroLastUpdatedAt': pomodoroLastUpdatedAt != null
          ? Timestamp.fromDate(pomodoroLastUpdatedAt!)
          : null,
    };
  }

  MindSetSessionStats copyWith({
    int? tasksTotalCount,
    int? tasksDoneCount,
    int? tasksWorkedCount,
    int? focusCount,
    int? pauseCount,
    int? switchCount,
    int? checklistCompletedCount,
    int? pomodoroCompletedCount,
    int? eatTheFrogCompletedCount,
    int? sessionFocusDurationMinutes,
    int? sessionFocusDurationSeconds,
    int? pomodoroCount,
    int? pomodoroTargetCount,
    int? pomodoroFocusMinutes,
    int? pomodoroBreakMinutes,
    int? pomodoroLongBreakMinutes,
    int? pomodoroRemainingSeconds,
    bool? pomodoroIsRunning,
    bool? pomodoroIsOnBreak,
    bool? pomodoroIsLongBreak,
    String? pomodoroMotivation,
    DateTime? pomodoroLastUpdatedAt,
    List<Map<String, dynamic>>? pomodoroCustomPresets,
  }) {
    return MindSetSessionStats(
      tasksTotalCount: tasksTotalCount ?? this.tasksTotalCount,
      tasksDoneCount: tasksDoneCount ?? this.tasksDoneCount,
      tasksWorkedCount: tasksWorkedCount ?? this.tasksWorkedCount,
      focusCount: focusCount ?? this.focusCount,
      pauseCount: pauseCount ?? this.pauseCount,
      switchCount: switchCount ?? this.switchCount,
      checklistCompletedCount:
          checklistCompletedCount ?? this.checklistCompletedCount,
      pomodoroCompletedCount:
          pomodoroCompletedCount ?? this.pomodoroCompletedCount,
      eatTheFrogCompletedCount:
          eatTheFrogCompletedCount ?? this.eatTheFrogCompletedCount,
      sessionFocusDurationMinutes:
          sessionFocusDurationMinutes ?? this.sessionFocusDurationMinutes,
      sessionFocusDurationSeconds:
          sessionFocusDurationSeconds ?? this.sessionFocusDurationSeconds,
      pomodoroCount: pomodoroCount ?? this.pomodoroCount,
      pomodoroTargetCount: pomodoroTargetCount ?? this.pomodoroTargetCount,
      pomodoroFocusMinutes: pomodoroFocusMinutes ?? this.pomodoroFocusMinutes,
      pomodoroBreakMinutes: pomodoroBreakMinutes ?? this.pomodoroBreakMinutes,
      pomodoroLongBreakMinutes:
          pomodoroLongBreakMinutes ?? this.pomodoroLongBreakMinutes,
      pomodoroRemainingSeconds:
          pomodoroRemainingSeconds ?? this.pomodoroRemainingSeconds,
      pomodoroIsRunning: pomodoroIsRunning ?? this.pomodoroIsRunning,
      pomodoroIsOnBreak: pomodoroIsOnBreak ?? this.pomodoroIsOnBreak,
      pomodoroIsLongBreak: pomodoroIsLongBreak ?? this.pomodoroIsLongBreak,
      pomodoroMotivation: pomodoroMotivation ?? this.pomodoroMotivation,
      pomodoroCustomPresets:
          pomodoroCustomPresets ?? this.pomodoroCustomPresets,
      pomodoroLastUpdatedAt:
          pomodoroLastUpdatedAt ?? this.pomodoroLastUpdatedAt,
    );
  }
}
