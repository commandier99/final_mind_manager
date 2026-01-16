class AppNotification {
  final String notifId;
  final String notifUserId; // The user who should receive this notification
  final String? notifTaskId;
  final String notifTitle;
  final String? notifBoardTitle;
  final String notifType; // 'due_today', 'overdue', 'assigned', 'task_request', 'general'
  final String notifMessage;
  final DateTime notifCreatedAt;
  final bool notifIsRead;
  final String? notifAcceptanceStatus; // 'pending', 'accepted', 'declined' for task_request notifications
  final String? notifAssignedBy; // User who assigned the task

  AppNotification({
    required this.notifId,
    required this.notifUserId,
    this.notifTaskId,
    required this.notifTitle,
    this.notifBoardTitle,
    required this.notifType,
    required this.notifMessage,
    required this.notifCreatedAt,
    this.notifIsRead = false,
    this.notifAcceptanceStatus,
    this.notifAssignedBy,
  });

  AppNotification copyWith({
    String? notifId,
    String? notifUserId,
    String? notifTaskId,
    String? notifTitle,
    String? notifBoardTitle,
    String? notifType,
    String? notifMessage,
    DateTime? notifCreatedAt,
    bool? notifIsRead,
    String? notifAcceptanceStatus,
    String? notifAssignedBy,
  }) {
    return AppNotification(
      notifId: notifId ?? this.notifId,
      notifUserId: notifUserId ?? this.notifUserId,
      notifTaskId: notifTaskId ?? this.notifTaskId,
      notifTitle: notifTitle ?? this.notifTitle,
      notifBoardTitle: notifBoardTitle ?? this.notifBoardTitle,
      notifType: notifType ?? this.notifType,
      notifMessage: notifMessage ?? this.notifMessage,
      notifCreatedAt: notifCreatedAt ?? this.notifCreatedAt,
      notifIsRead: notifIsRead ?? this.notifIsRead,
      notifAcceptanceStatus: notifAcceptanceStatus ?? this.notifAcceptanceStatus,
      notifAssignedBy: notifAssignedBy ?? this.notifAssignedBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notifId': notifId,
      'notifUserId': notifUserId,
      'notifTaskId': notifTaskId,
      'notifTitle': notifTitle,
      'notifBoardTitle': notifBoardTitle,
      'notifType': notifType,
      'notifMessage': notifMessage,
      'notifCreatedAt': notifCreatedAt.toIso8601String(),
      'notifIsRead': notifIsRead,
      'notifAcceptanceStatus': notifAcceptanceStatus,
      'notifAssignedBy': notifAssignedBy,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> data) {
    return AppNotification(
      notifId: data['notifId'] as String,
      notifUserId: data['notifUserId'] as String,
      notifTaskId: data['notifTaskId'] as String?,
      notifTitle: data['notifTitle'] as String,
      notifBoardTitle: data['notifBoardTitle'] as String?,
      notifType: data['notifType'] as String,
      notifMessage: data['notifMessage'] as String,
      notifCreatedAt: DateTime.parse(data['notifCreatedAt'] as String),
      notifIsRead: data['notifIsRead'] as bool? ?? false,
      notifAcceptanceStatus: data['notifAcceptanceStatus'] as String?,
      notifAssignedBy: data['notifAssignedBy'] as String?,
    );
  }
}
