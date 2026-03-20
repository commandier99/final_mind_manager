import 'package:cloud_firestore/cloud_firestore.dart';

class Thought {
  static const String typeReminder = 'reminder';
  static const String typeBoardRequest = 'board_request';
  static const String typeTaskAssignment = 'task_assignment';
  static const String typeTaskRequest = 'task_request';
  static const String typeSuggestion = 'suggestion';
  static const String typeSubmissionFeedback = 'submission_feedback';

  static const String statusOpen = 'open';
  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusDeclined = 'declined';
  static const String statusResolved = 'resolved';
  static const String statusConverted = 'converted';

  static const String scopeBoard = 'board';
  static const String scopeTask = 'task';
  static const String scopeUser = 'user';

  final String thoughtId;
  final String type;
  final String status;
  final String scopeType;
  final String boardId;
  final String taskId;
  final String authorId;
  final String authorName;
  final String? targetUserId;
  final String? targetUserName;
  final String title;
  final String message;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? actionedAt;
  final String? actionedBy;
  final String? actionedByName;
  final Map<String, dynamic>? metadata;

  const Thought({
    required this.thoughtId,
    required this.type,
    required this.status,
    required this.scopeType,
    required this.boardId,
    required this.taskId,
    required this.authorId,
    required this.authorName,
    this.targetUserId,
    this.targetUserName,
    required this.title,
    required this.message,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.actionedAt,
    this.actionedBy,
    this.actionedByName,
    this.metadata,
  });

  bool get isActionable =>
      status == statusOpen || status == statusPending;

  factory Thought.fromMap(Map<String, dynamic> data, String documentId) {
    return Thought(
      thoughtId: documentId,
      type: normalizeType(data['type'] as String?),
      status: normalizeStatus(data['status'] as String?),
      scopeType: normalizeScopeType(data['scopeType'] as String?),
      boardId: data['boardId'] as String? ?? '',
      taskId: data['taskId'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? 'Unknown',
      targetUserId: data['targetUserId'] as String?,
      targetUserName: data['targetUserName'] as String?,
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      isDeleted: data['isDeleted'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      actionedAt: (data['actionedAt'] as Timestamp?)?.toDate(),
      actionedBy: data['actionedBy'] as String?,
      actionedByName: data['actionedByName'] as String?,
      metadata: data['metadata'] == null
          ? null
          : Map<String, dynamic>.from(data['metadata'] as Map),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'thoughtId': thoughtId,
      'type': normalizeType(type),
      'status': normalizeStatus(status),
      'scopeType': normalizeScopeType(scopeType),
      'boardId': boardId,
      'taskId': taskId,
      'authorId': authorId,
      'authorName': authorName,
      if (targetUserId != null) 'targetUserId': targetUserId,
      if (targetUserName != null) 'targetUserName': targetUserName,
      'title': title,
      'message': message,
      'isDeleted': isDeleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (actionedAt != null) 'actionedAt': Timestamp.fromDate(actionedAt!),
      if (actionedBy != null) 'actionedBy': actionedBy,
      if (actionedByName != null) 'actionedByName': actionedByName,
      if (metadata != null) 'metadata': metadata,
    };
  }

  Thought copyWith({
    String? thoughtId,
    String? type,
    String? status,
    String? scopeType,
    String? boardId,
    String? taskId,
    String? authorId,
    String? authorName,
    String? targetUserId,
    String? targetUserName,
    String? title,
    String? message,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? actionedAt,
    String? actionedBy,
    String? actionedByName,
    Map<String, dynamic>? metadata,
  }) {
    return Thought(
      thoughtId: thoughtId ?? this.thoughtId,
      type: normalizeType(type ?? this.type),
      status: normalizeStatus(status ?? this.status),
      scopeType: normalizeScopeType(scopeType ?? this.scopeType),
      boardId: boardId ?? this.boardId,
      taskId: taskId ?? this.taskId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      targetUserId: targetUserId ?? this.targetUserId,
      targetUserName: targetUserName ?? this.targetUserName,
      title: title ?? this.title,
      message: message ?? this.message,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      actionedAt: actionedAt ?? this.actionedAt,
      actionedBy: actionedBy ?? this.actionedBy,
      actionedByName: actionedByName ?? this.actionedByName,
      metadata: metadata ?? this.metadata,
    );
  }

  static String normalizeType(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case typeReminder:
        return typeReminder;
      case typeBoardRequest:
        return typeBoardRequest;
      case typeTaskAssignment:
        return typeTaskAssignment;
      case typeTaskRequest:
        return typeTaskRequest;
      case typeSuggestion:
        return typeSuggestion;
      case typeSubmissionFeedback:
        return typeSubmissionFeedback;
      default:
        return typeReminder;
    }
  }

  static String normalizeStatus(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case statusPending:
        return statusPending;
      case statusAccepted:
        return statusAccepted;
      case statusDeclined:
        return statusDeclined;
      case statusResolved:
        return statusResolved;
      case statusConverted:
        return statusConverted;
      case statusOpen:
      default:
        return statusOpen;
    }
  }

  static String normalizeScopeType(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case scopeTask:
        return scopeTask;
      case scopeUser:
        return scopeUser;
      case scopeBoard:
      default:
        return scopeBoard;
    }
  }
}
