import 'package:cloud_firestore/cloud_firestore.dart';

class Subtask {
  final String subtaskId;
  final String parentTaskId;

  final String? subtaskBoardId;
  final String? subtaskBoardTitle;

  final String subtaskOwnerId;
  final String subtaskOwnerName;

  final String? subtaskAssignedBy;
  final String? subtaskAssignedTo;

  final DateTime subtaskCreatedAt;
  final DateTime? subtaskDeletedAt;
  final bool subtaskIsDeleted;

  final String subtaskTitle;
  final String? subtaskDescription;

  final bool subtaskIsDone;
  final DateTime? subtaskIsDoneAt;

  final int? subtaskStatsAmountOfTimesEdited;

  Subtask({
    required this.subtaskId,
    required this.parentTaskId,
    this.subtaskBoardId,
    this.subtaskBoardTitle,
    required this.subtaskOwnerId,
    required this.subtaskOwnerName,
    this.subtaskAssignedBy,
    this.subtaskAssignedTo,
    required this.subtaskCreatedAt,
    this.subtaskDeletedAt,
    this.subtaskIsDeleted = false,
    required this.subtaskTitle,
    this.subtaskDescription,
    this.subtaskIsDone = false,
    this.subtaskIsDoneAt,
    this.subtaskStatsAmountOfTimesEdited,
  });

  factory Subtask.fromMap(Map<String, dynamic> data, String documentId) {
    return Subtask(
      subtaskId: documentId,
      parentTaskId: data['parentTaskId'],
      subtaskBoardId: data['subtaskBoardId'],
      subtaskBoardTitle: data['subtaskBoardTitle'],
      subtaskOwnerId: data['subtaskOwnerId'],
      subtaskOwnerName: data['subtaskOwnerName'],
      subtaskAssignedBy: data['subtaskAssignedBy'],
      subtaskAssignedTo: data['subtaskAssignedTo'],
      subtaskCreatedAt: (data['subtaskCreatedAt'] as Timestamp).toDate(),
      subtaskDeletedAt: data['subtaskDeletedAt'] != null
          ? (data['subtaskDeletedAt'] as Timestamp).toDate()
          : null,
      subtaskIsDeleted: data['subtaskIsDeleted'] ?? false,
      subtaskTitle: data['subtaskTitle'],
      subtaskDescription: data['subtaskDescription'],
      subtaskIsDone: data['subtaskIsDone'] ?? false,
      subtaskIsDoneAt: data['subtaskIsDoneAt'] != null
          ? (data['subtaskIsDoneAt'] as Timestamp).toDate()
          : null,
      subtaskStatsAmountOfTimesEdited: data['subtaskStatsAmountOfTimesEdited'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'parentTaskId': parentTaskId,
      if (subtaskBoardId != null) 'subtaskBoardId': subtaskBoardId,
      if (subtaskBoardTitle != null) 'subtaskBoardTitle': subtaskBoardTitle,
      'subtaskOwnerId': subtaskOwnerId,
      'subtaskOwnerName': subtaskOwnerName,
      if (subtaskAssignedBy != null) 'subtaskAssignedBy': subtaskAssignedBy,
      if (subtaskAssignedTo != null) 'subtaskAssignedTo': subtaskAssignedTo,
      'subtaskCreatedAt': Timestamp.fromDate(subtaskCreatedAt),
      if (subtaskDeletedAt != null)
        'subtaskDeletedAt': Timestamp.fromDate(subtaskDeletedAt!),
      'subtaskIsDeleted': subtaskIsDeleted,
      'subtaskTitle': subtaskTitle,
      if (subtaskDescription != null) 'subtaskDescription': subtaskDescription,
      'subtaskIsDone': subtaskIsDone,
      if (subtaskIsDoneAt != null)
        'subtaskIsDoneAt': Timestamp.fromDate(subtaskIsDoneAt!),
      if (subtaskStatsAmountOfTimesEdited != null)
        'subtaskStatsAmountOfTimesEdited': subtaskStatsAmountOfTimesEdited,
    };
  }

  Subtask copyWith({
    String? subtaskId,
    String? parentTaskId,
    String? subtaskBoardId,
    String? subtaskBoardTitle,
    String? subtaskOwnerId,
    String? subtaskOwnerName,
    String? subtaskAssignedBy,
    String? subtaskAssignedTo,
    DateTime? subtaskCreatedAt,
    DateTime? subtaskDeletedAt,
    bool? subtaskIsDeleted,
    String? subtaskTitle,
    String? subtaskDescription,
    bool? subtaskIsDone,
    DateTime? subtaskIsDoneAt,
    int? subtaskStatsAmountOfTimesEdited,
  }) {
    return Subtask(
      subtaskId: subtaskId ?? this.subtaskId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      subtaskBoardId: subtaskBoardId ?? this.subtaskBoardId,
      subtaskBoardTitle: subtaskBoardTitle ?? this.subtaskBoardTitle,
      subtaskOwnerId: subtaskOwnerId ?? this.subtaskOwnerId,
      subtaskOwnerName: subtaskOwnerName ?? this.subtaskOwnerName,
      subtaskAssignedBy: subtaskAssignedBy ?? this.subtaskAssignedBy,
      subtaskAssignedTo: subtaskAssignedTo ?? this.subtaskAssignedTo,
      subtaskCreatedAt: subtaskCreatedAt ?? this.subtaskCreatedAt,
      subtaskDeletedAt: subtaskDeletedAt ?? this.subtaskDeletedAt,
      subtaskIsDeleted: subtaskIsDeleted ?? this.subtaskIsDeleted,
      subtaskTitle: subtaskTitle ?? this.subtaskTitle,
      subtaskDescription: subtaskDescription ?? this.subtaskDescription,
      subtaskIsDone: subtaskIsDone ?? this.subtaskIsDone,
      subtaskIsDoneAt: subtaskIsDoneAt ?? this.subtaskIsDoneAt,
      subtaskStatsAmountOfTimesEdited:
          subtaskStatsAmountOfTimesEdited ?? this.subtaskStatsAmountOfTimesEdited,
    );
  }
}
