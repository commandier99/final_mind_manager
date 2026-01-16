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
  final DateTime? planDeadline;
  final DateTime? planScheduledFor; // Date user wants to do this plan (primary scheduling)

  // Task organization
  final List<String> taskIds; // Tasks included in this plan
  final Map<String, int> taskOrder; // taskId -> position mapping
  final int totalTasks;
  final int completedTasks;

  // Style/Methodology
  final String planStyle; // 'Pomodoro', 'Timeblocking', 'GTD', 'Checklist'

  Plan({
    required this.planId,
    required this.planOwnerId,
    required this.planOwnerName,
    required this.planTitle,
    required this.planDescription,
    required this.planCreatedAt,
    this.planDeletedAt,
    this.planIsDeleted = false,
    this.planDeadline,
    this.planScheduledFor,
    this.taskIds = const [],
    this.taskOrder = const {},
    this.totalTasks = 0,
    this.completedTasks = 0,
    this.planStyle = 'Checklist',
  });

  // Computed properties
  int get remainingTasks => totalTasks - completedTasks;
  double get completionPercentage =>
      totalTasks > 0 ? (completedTasks / totalTasks) * 100 : 0;

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
      planStyle: data['planStyle'] as String? ?? 'Checklist',
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
      if (planDeadline != null) 'planDeadline': Timestamp.fromDate(planDeadline!),
      if (planScheduledFor != null) 'planScheduledFor': Timestamp.fromDate(planScheduledFor!),
      'taskIds': taskIds,
      'taskOrder': taskOrder,
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'planStyle': planStyle,
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
    DateTime? planDeadline,
    DateTime? planScheduledFor,
    List<String>? taskIds,
    Map<String, int>? taskOrder,
    int? totalTasks,
    int? completedTasks,
    String? planStyle,
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
      planDeadline: planDeadline ?? this.planDeadline,
      planScheduledFor: planScheduledFor ?? this.planScheduledFor,
      taskIds: taskIds ?? this.taskIds,
      taskOrder: taskOrder ?? this.taskOrder,
      totalTasks: totalTasks ?? this.totalTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      planStyle: planStyle ?? this.planStyle,
    );
  }

  @override
  String toString() {
    return 'Plan(planId: $planId, planTitle: $planTitle, '
        'totalTasks: $totalTasks, completedTasks: $completedTasks)';
  }
}
