import 'package:cloud_firestore/cloud_firestore.dart';

class TaskStep {
  final String stepId;
  final String parentTaskId;

  final String? stepBoardId;
  final String? stepBoardTitle;

  final String stepOwnerId;
  final String stepOwnerName;

  final String? stepAssignedBy;
  final String? stepAssignedTo;

  final DateTime stepCreatedAt;
  final DateTime? stepDeletedAt;
  final bool stepIsDeleted;

  final String stepTitle;
  final String? stepDescription;

  final bool stepIsDone;
  final DateTime? stepIsDoneAt;
  final int? stepOrder;

  final int? stepStatsAmountOfTimesEdited;

  TaskStep({
    required this.stepId,
    required this.parentTaskId,
    this.stepBoardId,
    this.stepBoardTitle,
    required this.stepOwnerId,
    required this.stepOwnerName,
    this.stepAssignedBy,
    this.stepAssignedTo,
    required this.stepCreatedAt,
    this.stepDeletedAt,
    this.stepIsDeleted = false,
    required this.stepTitle,
    this.stepDescription,
    this.stepIsDone = false,
    this.stepIsDoneAt,
    this.stepOrder,
    this.stepStatsAmountOfTimesEdited,
  });

  factory TaskStep.fromMap(Map<String, dynamic> data, String documentId) {
    final createdAtRaw = data['stepCreatedAt'] ?? data['stepCreatedAt'];
    final deletedAtRaw = data['stepDeletedAt'] ?? data['stepDeletedAt'];
    final doneAtRaw = data['stepIsDoneAt'] ?? data['stepIsDoneAt'];
    return TaskStep(
      stepId: documentId,
      parentTaskId: data['parentTaskId'],
      stepBoardId: data['stepBoardId'] ?? data['stepBoardId'],
      stepBoardTitle: data['stepBoardTitle'] ?? data['stepBoardTitle'],
      stepOwnerId: data['stepOwnerId'] ?? data['stepOwnerId'],
      stepOwnerName: data['stepOwnerName'] ?? data['stepOwnerName'],
      stepAssignedBy: data['stepAssignedBy'] ?? data['stepAssignedBy'],
      stepAssignedTo: data['stepAssignedTo'] ?? data['stepAssignedTo'],
      stepCreatedAt: (createdAtRaw as Timestamp).toDate(),
      stepDeletedAt: deletedAtRaw != null
          ? (deletedAtRaw as Timestamp).toDate()
          : null,
      stepIsDeleted: data['stepIsDeleted'] ?? data['stepIsDeleted'] ?? false,
      stepTitle: data['stepTitle'] ?? data['stepTitle'],
      stepDescription: data['stepDescription'] ?? data['stepDescription'],
      stepIsDone: data['stepIsDone'] ?? data['stepIsDone'] ?? false,
      stepIsDoneAt: doneAtRaw != null
          ? (doneAtRaw as Timestamp).toDate()
          : null,
      stepOrder: data['stepOrder'] is int
          ? data['stepOrder'] as int
          : data['stepOrder'] is num
          ? (data['stepOrder'] as num).toInt()
          : data['stepOrder'] is int
          ? data['stepOrder'] as int
          : (data['stepOrder'] as num?)?.toInt(),
      stepStatsAmountOfTimesEdited:
          data['stepStatsAmountOfTimesEdited'] ??
          data['stepStatsAmountOfTimesEdited'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'parentTaskId': parentTaskId,
      if (stepBoardId != null) 'stepBoardId': stepBoardId,
      if (stepBoardTitle != null) 'stepBoardTitle': stepBoardTitle,
      'stepOwnerId': stepOwnerId,
      'stepOwnerName': stepOwnerName,
      if (stepAssignedBy != null) 'stepAssignedBy': stepAssignedBy,
      if (stepAssignedTo != null) 'stepAssignedTo': stepAssignedTo,
      'stepCreatedAt': Timestamp.fromDate(stepCreatedAt),
      if (stepDeletedAt != null)
        'stepDeletedAt': Timestamp.fromDate(stepDeletedAt!),
      'stepIsDeleted': stepIsDeleted,
      'stepTitle': stepTitle,
      if (stepDescription != null) 'stepDescription': stepDescription,
      'stepIsDone': stepIsDone,
      if (stepIsDoneAt != null)
        'stepIsDoneAt': Timestamp.fromDate(stepIsDoneAt!),
      if (stepOrder != null) 'stepOrder': stepOrder,
      if (stepStatsAmountOfTimesEdited != null)
        'stepStatsAmountOfTimesEdited': stepStatsAmountOfTimesEdited,
    };
  }

  TaskStep copyWith({
    String? stepId,
    String? parentTaskId,
    String? stepBoardId,
    String? stepBoardTitle,
    String? stepOwnerId,
    String? stepOwnerName,
    String? stepAssignedBy,
    String? stepAssignedTo,
    DateTime? stepCreatedAt,
    DateTime? stepDeletedAt,
    bool? stepIsDeleted,
    String? stepTitle,
    String? stepDescription,
    bool? stepIsDone,
    DateTime? stepIsDoneAt,
    int? stepOrder,
    int? stepStatsAmountOfTimesEdited,
  }) {
    return TaskStep(
      stepId: stepId ?? this.stepId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      stepBoardId: stepBoardId ?? this.stepBoardId,
      stepBoardTitle: stepBoardTitle ?? this.stepBoardTitle,
      stepOwnerId: stepOwnerId ?? this.stepOwnerId,
      stepOwnerName: stepOwnerName ?? this.stepOwnerName,
      stepAssignedBy: stepAssignedBy ?? this.stepAssignedBy,
      stepAssignedTo: stepAssignedTo ?? this.stepAssignedTo,
      stepCreatedAt: stepCreatedAt ?? this.stepCreatedAt,
      stepDeletedAt: stepDeletedAt ?? this.stepDeletedAt,
      stepIsDeleted: stepIsDeleted ?? this.stepIsDeleted,
      stepTitle: stepTitle ?? this.stepTitle,
      stepDescription: stepDescription ?? this.stepDescription,
      stepIsDone: stepIsDone ?? this.stepIsDone,
      stepIsDoneAt: stepIsDoneAt ?? this.stepIsDoneAt,
      stepOrder: stepOrder ?? this.stepOrder,
      stepStatsAmountOfTimesEdited:
          stepStatsAmountOfTimesEdited ??
          this.stepStatsAmountOfTimesEdited,
    );
  }
}


