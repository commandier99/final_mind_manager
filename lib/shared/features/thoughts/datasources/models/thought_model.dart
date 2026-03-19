import 'package:cloud_firestore/cloud_firestore.dart';

class ThoughtModel {
  static const String typeGeneral = 'general';
  static const String typeBoardInvite = 'board_invite';
  static const String typeBoardJoinRequest = 'board_join_request';
  static const String typeSuggestion = 'suggestion';
  static const String typeTaskAssignment = 'task_assignment';
  static const String typeTaskApplication = 'task_application';
  static const String typeSubmissionReview = 'submission_review';
  static const String typeFeedback = 'feedback';
  static const String typeReminder = 'reminder';

  static const String suggestionTargetTask = 'task';
  static const String suggestionTargetStep = 'step';

  static const String timingNow = 'now';
  static const String timingLater = 'later';

  static const String targetUser = 'user';
  static const String targetBoard = 'board';
  static const String targetTask = 'task';
  static const String targetStep = 'step';

  static const String statusPending = 'pending';
  static const String statusSent = 'sent';
  static const String statusScheduled = 'scheduled';
  static const String statusResolved = 'resolved';
  static const String statusDeleted = 'deleted';

  final String thoughtId;
  final String thoughtType;
  final String senderUserId;
  final String senderUserName;
  final String targetType;
  final String targetId;
  final String targetLabel;
  final String? title;
  final String message;
  final String? threadId;
  final String? inReplyToThoughtId;
  final String timing;
  final DateTime? scheduledAt;
  final String status;
  final String? recipientUserId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ThoughtModel({
    required this.thoughtId,
    this.thoughtType = typeGeneral,
    required this.senderUserId,
    required this.senderUserName,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
    this.title,
    required this.message,
    this.threadId,
    this.inReplyToThoughtId,
    required this.timing,
    required this.createdAt,
    required this.updatedAt,
    this.scheduledAt,
    this.status = statusPending,
    this.recipientUserId,
    this.metadata,
  });

  factory ThoughtModel.fromMap(Map<String, dynamic> map, String id) {
    return ThoughtModel(
      thoughtId: (map['thoughtId'] as String?) ??
          (map['memoryId'] as String?) ??
          (map['pokeId'] as String?) ??
          id,
      thoughtType: map['thoughtType'] as String? ??
          (map['type'] as String?) ??
          typeGeneral,
      senderUserId: (map['senderUserId'] as String?) ??
          (map['createdByUserId'] as String?) ??
          '',
      senderUserName: (map['senderUserName'] as String?) ??
          (map['createdByUserName'] as String?) ??
          'Unknown',
      targetType: map['targetType'] as String? ?? targetUser,
      targetId: map['targetId'] as String? ?? '',
      targetLabel: map['targetLabel'] as String? ?? '',
      title: (map['title'] as String?) ?? (map['subject'] as String?),
      message: map['message'] as String? ?? '',
      threadId: map['threadId'] as String?,
      inReplyToThoughtId: (map['inReplyToThoughtId'] as String?) ??
          (map['inReplyToMemoryId'] as String?) ??
          (map['inReplyToPokeId'] as String?),
      timing: map['timing'] as String? ?? timingNow,
      scheduledAt: (map['scheduledAt'] as Timestamp?)?.toDate(),
      status: map['status'] as String? ?? statusPending,
      recipientUserId: map['recipientUserId'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ??
          (map['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'thoughtId': thoughtId,
      'thoughtType': thoughtType,
      'type': thoughtType,
      // Backward compatibility while the Firestore collection is still `pokes`.
      'memoryId': thoughtId,
      'pokeId': thoughtId,
      'senderUserId': senderUserId,
      'createdByUserId': senderUserId,
      'senderUserName': senderUserName,
      'createdByUserName': senderUserName,
      'targetType': targetType,
      'targetId': targetId,
      'targetLabel': targetLabel,
      if (title != null && title!.trim().isNotEmpty) ...{
        'title': title,
        'subject': title,
      },
      'message': message,
      if (threadId != null && threadId!.trim().isNotEmpty) 'threadId': threadId,
      if (inReplyToThoughtId != null && inReplyToThoughtId!.trim().isNotEmpty) ...{
        'inReplyToThoughtId': inReplyToThoughtId,
        'inReplyToMemoryId': inReplyToThoughtId,
        'inReplyToPokeId': inReplyToThoughtId,
      },
      'timing': timing,
      if (scheduledAt != null) 'scheduledAt': Timestamp.fromDate(scheduledAt!),
      'status': status,
      if (recipientUserId != null) 'recipientUserId': recipientUserId,
      if (metadata != null) 'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  String get effectiveThreadId => (threadId ?? '').trim().isEmpty
      ? (thoughtId.trim().isEmpty ? targetId : thoughtId)
      : threadId!.trim();

  String get suggestionTargetType =>
      (metadata?['suggestionTargetType']?.toString() ?? '').trim().toLowerCase();

  String get boardId =>
      (metadata?['boardId']?.toString() ?? '').trim();

  String get taskId =>
      (metadata?['taskId']?.toString() ?? '').trim();

  String get convertedTaskId =>
      (metadata?['convertedTaskId']?.toString() ?? '').trim();

  String get convertedStepId =>
      (metadata?['convertedStepId']?.toString() ?? '').trim();

  bool get isTaskSuggestion =>
      thoughtType == typeSuggestion &&
      suggestionTargetType == suggestionTargetTask;

  bool get isStepSuggestion =>
      thoughtType == typeSuggestion &&
      suggestionTargetType == suggestionTargetStep;
}
