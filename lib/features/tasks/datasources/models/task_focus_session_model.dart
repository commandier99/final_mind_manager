import 'package:cloud_firestore/cloud_firestore.dart';

class TaskFocusSession {
  final String focusSessionId;
  final String taskId;
  final String userId;
  
  // Session timing
  final DateTime focusStartedAt;
  final DateTime? focusEndedAt;
  final int focusPlannedDurationMinutes;
  final int focusActualDurationMinutes;
  
  // Productivity tracking
  final bool focusWasCompleted;
  final String focusEndReason;
  final int focusProductivityScore;
  final String? focusNotes;
  
  // Interruptions & breaks
  final int focusInterruptionCount;
  final int focusTotalBreakMinutes;
  final List<String>? focusInterruptions;
  
  // Context
  final DateTime focusSessionCreatedAt;

  TaskFocusSession({
    required this.focusSessionId,
    required this.taskId,
    required this.userId,
    required this.focusStartedAt,
    this.focusEndedAt,
    required this.focusPlannedDurationMinutes,
    this.focusActualDurationMinutes = 0,
    this.focusWasCompleted = false,
    this.focusEndReason = 'ongoing',
    this.focusProductivityScore = 0,
    this.focusNotes,
    this.focusInterruptionCount = 0,
    this.focusTotalBreakMinutes = 0,
    this.focusInterruptions,
    required this.focusSessionCreatedAt,
  });

  factory TaskFocusSession.fromMap(Map<String, dynamic> data, String documentId) {
    return TaskFocusSession(
      focusSessionId: documentId,
      taskId: data['taskId'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      focusStartedAt: (data['focusStartedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      focusEndedAt: (data['focusEndedAt'] as Timestamp?)?.toDate(),
      focusPlannedDurationMinutes: data['focusPlannedDurationMinutes'] as int? ?? 25,
      focusActualDurationMinutes: data['focusActualDurationMinutes'] as int? ?? 0,
      focusWasCompleted: data['focusWasCompleted'] as bool? ?? false,
      focusEndReason: data['focusEndReason'] as String? ?? 'ongoing',
      focusProductivityScore: data['focusProductivityScore'] as int? ?? 0,
      focusNotes: data['focusNotes'] as String?,
      focusInterruptionCount: data['focusInterruptionCount'] as int? ?? 0,
      focusTotalBreakMinutes: data['focusTotalBreakMinutes'] as int? ?? 0,
      focusInterruptions: List<String>.from(data['focusInterruptions'] as List? ?? []),
      focusSessionCreatedAt: (data['focusSessionCreatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'userId': userId,
      'focusStartedAt': Timestamp.fromDate(focusStartedAt),
      if (focusEndedAt != null) 'focusEndedAt': Timestamp.fromDate(focusEndedAt!),
      'focusPlannedDurationMinutes': focusPlannedDurationMinutes,
      'focusActualDurationMinutes': focusActualDurationMinutes,
      'focusWasCompleted': focusWasCompleted,
      'focusEndReason': focusEndReason,
      'focusProductivityScore': focusProductivityScore,
      if (focusNotes != null) 'focusNotes': focusNotes,
      'focusInterruptionCount': focusInterruptionCount,
      'focusTotalBreakMinutes': focusTotalBreakMinutes,
      'focusInterruptions': focusInterruptions ?? [],
      'focusSessionCreatedAt': Timestamp.fromDate(focusSessionCreatedAt),
    };
  }

  TaskFocusSession copyWith({
    String? focusSessionId,
    String? taskId,
    String? userId,
    DateTime? focusStartedAt,
    DateTime? focusEndedAt,
    int? focusPlannedDurationMinutes,
    int? focusActualDurationMinutes,
    bool? focusWasCompleted,
    String? focusEndReason,
    int? focusProductivityScore,
    String? focusNotes,
    int? focusInterruptionCount,
    int? focusTotalBreakMinutes,
    List<String>? focusInterruptions,
    DateTime? focusSessionCreatedAt,
  }) {
    return TaskFocusSession(
      focusSessionId: focusSessionId ?? this.focusSessionId,
      taskId: taskId ?? this.taskId,
      userId: userId ?? this.userId,
      focusStartedAt: focusStartedAt ?? this.focusStartedAt,
      focusEndedAt: focusEndedAt ?? this.focusEndedAt,
      focusPlannedDurationMinutes: focusPlannedDurationMinutes ?? this.focusPlannedDurationMinutes,
      focusActualDurationMinutes: focusActualDurationMinutes ?? this.focusActualDurationMinutes,
      focusWasCompleted: focusWasCompleted ?? this.focusWasCompleted,
      focusEndReason: focusEndReason ?? this.focusEndReason,
      focusProductivityScore: focusProductivityScore ?? this.focusProductivityScore,
      focusNotes: focusNotes ?? this.focusNotes,
      focusInterruptionCount: focusInterruptionCount ?? this.focusInterruptionCount,
      focusTotalBreakMinutes: focusTotalBreakMinutes ?? this.focusTotalBreakMinutes,
      focusInterruptions: focusInterruptions ?? this.focusInterruptions,
      focusSessionCreatedAt: focusSessionCreatedAt ?? this.focusSessionCreatedAt,
    );
  }
}
