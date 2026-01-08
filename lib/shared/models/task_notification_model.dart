class TaskNotification {
  final String notificationId;
  final String userId; // The user who should receive this notification
  final String taskId;
  final String taskTitle;
  final String? boardTitle;
  final String notificationType; // 'due_today', 'overdue', 'assigned', 'task_request'
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? acceptanceStatus; // 'pending', 'accepted', 'declined' for task_request notifications
  final String? assignedBy; // User who assigned the task

  TaskNotification({
    required this.notificationId,
    required this.userId,
    required this.taskId,
    required this.taskTitle,
    this.boardTitle,
    required this.notificationType,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.acceptanceStatus,
    this.assignedBy,
  });

  TaskNotification copyWith({
    String? notificationId,
    String? userId,
    String? taskId,
    String? taskTitle,
    String? boardTitle,
    String? notificationType,
    String? message,
    DateTime? createdAt,
    bool? isRead,
    String? acceptanceStatus,
    String? assignedBy,
  }) {
    return TaskNotification(
      notificationId: notificationId ?? this.notificationId,
      userId: userId ?? this.userId,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      boardTitle: boardTitle ?? this.boardTitle,
      notificationType: notificationType ?? this.notificationType,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      acceptanceStatus: acceptanceStatus ?? this.acceptanceStatus,
      assignedBy: assignedBy ?? this.assignedBy,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'userId': userId,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'boardTitle': boardTitle,
      'notificationType': notificationType,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'acceptanceStatus': acceptanceStatus,
      'assignedBy': assignedBy,
    };
  }

  factory TaskNotification.fromMap(Map<String, dynamic> data) {
    return TaskNotification(
      notificationId: data['notificationId'] as String,
      userId: data['userId'] as String,
      taskId: data['taskId'] as String,
      taskTitle: data['taskTitle'] as String,
      boardTitle: data['boardTitle'] as String?,
      notificationType: data['notificationType'] as String,
      message: data['message'] as String,
      createdAt: DateTime.parse(data['createdAt'] as String),
      isRead: data['isRead'] as bool? ?? false,
      acceptanceStatus: data['acceptanceStatus'] as String?,
      assignedBy: data['assignedBy'] as String?,
    );
  }
}
