import 'package:cloud_firestore/cloud_firestore.dart';

class Plan {
  final String planId;
  final String planOwnerId;
  final String planOwnerName;
  final String planTitle;
  final String planDescription;
  final DateTime planCreatedAt;
  final DateTime? planDeletedAt;
  final bool planIsDeleted;

  // Execution fields
  final String planStatus; // 'draft', 'active', 'paused', 'completed'
  final DateTime? planStartedAt;
  final DateTime? planCompletedAt;
  final DateTime? planDeadline;
  final DateTime? planScheduledFor; // Date user wants to do this plan (primary scheduling)

  // Task organization
  final List<String> taskIds; // Tasks included in this plan
  final Map<String, int> taskOrder; // taskId -> position mapping
  final int totalTasks;
  final int completedTasks;

  // Technique/Methodology
  final String planTechnique; // 'pomodoro', 'timeblocking', 'gtd', 'custom'
  final int estimatedDurationMinutes; // Total estimated work time
  final int plannedFocusIntervals; // Number of Pomodoro sessions
  final int focusIntervalMinutes; // Minutes per focus interval (default 25)
  final int breakMinutes; // Minutes per break

  // Progress tracking
  final int actualFocusSessionsCompleted;
  final int actualFocusMinutesSpent;
  final double averageProductivityScore; // Average score from focus sessions
  final List<String> focusSessionIds; // Track which focus sessions belong to this plan

  // Sharing & collaboration
  final bool planIsShared;
  final List<String> sharedWithUserIds;
  final Map<String, String> sharedUserNames;

  // Templates
  final bool planIsTemplate; // If true, can be duplicated for new plans
  final String? planTemplateName;

  Plan({
    required this.planId,
    required this.planOwnerId,
    required this.planOwnerName,
    required this.planTitle,
    required this.planDescription,
    required this.planCreatedAt,
    this.planDeletedAt,
    this.planIsDeleted = false,
    this.planStatus = 'draft',
    this.planStartedAt,
    this.planCompletedAt,
    this.planDeadline,
    this.planScheduledFor,
    this.taskIds = const [],
    this.taskOrder = const {},
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.planTechnique = 'custom',
    this.estimatedDurationMinutes = 0,
    this.plannedFocusIntervals = 0,
    this.focusIntervalMinutes = 25,
    this.breakMinutes = 5,
    this.actualFocusSessionsCompleted = 0,
    this.actualFocusMinutesSpent = 0,
    this.averageProductivityScore = 0.0,
    this.focusSessionIds = const [],
    this.planIsShared = false,
    this.sharedWithUserIds = const [],
    this.sharedUserNames = const {},
    this.planIsTemplate = false,
    this.planTemplateName,
  });

  // Computed properties
  bool get isActive => planStatus == 'active';
  bool get isCompleted => planStatus == 'completed';
  bool get isDraft => planStatus == 'draft';
  bool get isPaused => planStatus == 'paused';
  int get remainingTasks => totalTasks - completedTasks;
  double get completionPercentage =>
      totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0;
  double get focusIntervalPercentage =>
      plannedFocusIntervals > 0 ? (actualFocusSessionsCompleted / plannedFocusIntervals) * 100 : 0;

  factory Plan.fromMap(Map<String, dynamic> data, String documentId) {
    return Plan(
      planId: documentId,
      planOwnerId: data['planOwnerId'] as String? ?? '',
      planOwnerName: data['planOwnerName'] as String? ?? 'Unknown',
      planTitle: data['planTitle'] as String? ?? 'Untitled Plan',
      planDescription: data['planDescription'] as String? ?? '',
      planCreatedAt: (data['planCreatedAt'] as Timestamp).toDate(),
      planDeletedAt: data['planDeletedAt'] != null
          ? (data['planDeletedAt'] as Timestamp).toDate()
          : null,
      planIsDeleted: data['planIsDeleted'] as bool? ?? false,
      planStatus: data['planStatus'] as String? ?? 'draft',
      planStartedAt: data['planStartedAt'] != null
          ? (data['planStartedAt'] as Timestamp).toDate()
          : null,
      planCompletedAt: data['planCompletedAt'] != null
          ? (data['planCompletedAt'] as Timestamp).toDate()
          : null,
      planDeadline: data['planDeadline'] != null
          ? (data['planDeadline'] as Timestamp).toDate()
          : null,
      planScheduledFor: data['planScheduledFor'] != null
          ? (data['planScheduledFor'] as Timestamp).toDate()
          : null,
      taskIds: List<String>.from(data['taskIds'] ?? []),
      taskOrder: Map<String, int>.from(data['taskOrder'] ?? {}),
      totalTasks: data['totalTasks'] as int? ?? 0,
      completedTasks: data['completedTasks'] as int? ?? 0,
      planTechnique: data['planTechnique'] as String? ?? 'custom',
      estimatedDurationMinutes: data['estimatedDurationMinutes'] as int? ?? 0,
      plannedFocusIntervals: data['plannedFocusIntervals'] as int? ?? 0,
      focusIntervalMinutes: data['focusIntervalMinutes'] as int? ?? 25,
      breakMinutes: data['breakMinutes'] as int? ?? 5,
      actualFocusSessionsCompleted: data['actualFocusSessionsCompleted'] as int? ?? 0,
      actualFocusMinutesSpent: data['actualFocusMinutesSpent'] as int? ?? 0,
      averageProductivityScore: (data['averageProductivityScore'] as num? ?? 0).toDouble(),
      focusSessionIds: List<String>.from(data['focusSessionIds'] ?? []),
      planIsShared: data['planIsShared'] as bool? ?? false,
      sharedWithUserIds: List<String>.from(data['sharedWithUserIds'] ?? []),
      sharedUserNames: Map<String, String>.from(data['sharedUserNames'] ?? {}),
      planIsTemplate: data['planIsTemplate'] as bool? ?? false,
      planTemplateName: data['planTemplateName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'planOwnerId': planOwnerId,
      'planOwnerName': planOwnerName,
      'planTitle': planTitle,
      'planDescription': planDescription,
      'planCreatedAt': Timestamp.fromDate(planCreatedAt),
      if (planDeletedAt != null) 'planDeletedAt': Timestamp.fromDate(planDeletedAt!),
      'planIsDeleted': planIsDeleted,
      'planStatus': planStatus,
      if (planStartedAt != null) 'planStartedAt': Timestamp.fromDate(planStartedAt!),
      if (planCompletedAt != null) 'planCompletedAt': Timestamp.fromDate(planCompletedAt!),
      if (planDeadline != null) 'planDeadline': Timestamp.fromDate(planDeadline!),
      if (planScheduledFor != null) 'planScheduledFor': Timestamp.fromDate(planScheduledFor!),
      'taskIds': taskIds,
      'taskOrder': taskOrder,
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'planTechnique': planTechnique,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'plannedFocusIntervals': plannedFocusIntervals,
      'focusIntervalMinutes': focusIntervalMinutes,
      'breakMinutes': breakMinutes,
      'actualFocusSessionsCompleted': actualFocusSessionsCompleted,
      'actualFocusMinutesSpent': actualFocusMinutesSpent,
      'averageProductivityScore': averageProductivityScore,
      'focusSessionIds': focusSessionIds,
      'planIsShared': planIsShared,
      'sharedWithUserIds': sharedWithUserIds,
      'sharedUserNames': sharedUserNames,
      'planIsTemplate': planIsTemplate,
      if (planTemplateName != null) 'planTemplateName': planTemplateName,
    };
  }

  Plan copyWith({
    String? planId,
    String? planOwnerId,
    String? planOwnerName,
    String? planTitle,
    String? planDescription,
    DateTime? planCreatedAt,
    DateTime? planDeletedAt,
    bool? planIsDeleted,
    String? planStatus,
    DateTime? planStartedAt,
    DateTime? planCompletedAt,
    DateTime? planDeadline,
    DateTime? planScheduledFor,
    List<String>? taskIds,
    Map<String, int>? taskOrder,
    int? totalTasks,
    int? completedTasks,
    String? planTechnique,
    int? estimatedDurationMinutes,
    int? plannedFocusIntervals,
    int? focusIntervalMinutes,
    int? breakMinutes,
    int? actualFocusSessionsCompleted,
    int? actualFocusMinutesSpent,
    double? averageProductivityScore,
    List<String>? focusSessionIds,
    bool? planIsShared,
    List<String>? sharedWithUserIds,
    Map<String, String>? sharedUserNames,
    bool? planIsTemplate,
    String? planTemplateName,
  }) {
    return Plan(
      planId: planId ?? this.planId,
      planOwnerId: planOwnerId ?? this.planOwnerId,
      planOwnerName: planOwnerName ?? this.planOwnerName,
      planTitle: planTitle ?? this.planTitle,
      planDescription: planDescription ?? this.planDescription,
      planCreatedAt: planCreatedAt ?? this.planCreatedAt,
      planDeletedAt: planDeletedAt ?? this.planDeletedAt,
      planIsDeleted: planIsDeleted ?? this.planIsDeleted,
      planStatus: planStatus ?? this.planStatus,
      planStartedAt: planStartedAt ?? this.planStartedAt,
      planCompletedAt: planCompletedAt ?? this.planCompletedAt,
      planDeadline: planDeadline ?? this.planDeadline,
      planScheduledFor: planScheduledFor ?? this.planScheduledFor,
      taskIds: taskIds ?? this.taskIds,
      taskOrder: taskOrder ?? this.taskOrder,
      totalTasks: totalTasks ?? this.totalTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      planTechnique: planTechnique ?? this.planTechnique,
      estimatedDurationMinutes: estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      plannedFocusIntervals: plannedFocusIntervals ?? this.plannedFocusIntervals,
      focusIntervalMinutes: focusIntervalMinutes ?? this.focusIntervalMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      actualFocusSessionsCompleted: actualFocusSessionsCompleted ?? this.actualFocusSessionsCompleted,
      actualFocusMinutesSpent: actualFocusMinutesSpent ?? this.actualFocusMinutesSpent,
      averageProductivityScore: averageProductivityScore ?? this.averageProductivityScore,
      focusSessionIds: focusSessionIds ?? this.focusSessionIds,
      planIsShared: planIsShared ?? this.planIsShared,
      sharedWithUserIds: sharedWithUserIds ?? this.sharedWithUserIds,
      sharedUserNames: sharedUserNames ?? this.sharedUserNames,
      planIsTemplate: planIsTemplate ?? this.planIsTemplate,
      planTemplateName: planTemplateName ?? this.planTemplateName,
    );
  }

  @override
  String toString() {
    return 'Plan(planId: $planId, planTitle: $planTitle, planStatus: $planStatus, '
        'totalTasks: $totalTasks, completedTasks: $completedTasks)';
  }
}
