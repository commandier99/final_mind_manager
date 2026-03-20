import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  static const String deliveryPending = 'pending';
  static const String deliverySent = 'sent';
  static const String deliveryFailed = 'failed';

  final String notificationId;
  final String recipientUserId;
  final String title;
  final String message;
  final String type;
  final String deliveryStatus;
  final bool isRead;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? readAt;
  final DateTime? pushedAt;
  final String? actorUserId;
  final String? actorUserName;
  final String? boardId;
  final String? taskId;
  final String? thoughtId;
  final String? eventKey;
  final Map<String, dynamic>? metadata;

  const AppNotification({
    required this.notificationId,
    required this.recipientUserId,
    required this.title,
    required this.message,
    required this.type,
    required this.deliveryStatus,
    required this.isRead,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    this.readAt,
    this.pushedAt,
    this.actorUserId,
    this.actorUserName,
    this.boardId,
    this.taskId,
    this.thoughtId,
    this.eventKey,
    this.metadata,
  });

  factory AppNotification.fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return AppNotification(
      notificationId: documentId,
      recipientUserId: data['recipientUserId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      message: data['message'] as String? ?? '',
      type: normalizeType(data['type'] as String?),
      deliveryStatus: normalizeDeliveryStatus(
        data['deliveryStatus'] as String?,
      ),
      isRead: data['isRead'] as bool? ?? false,
      isDeleted: data['isDeleted'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      pushedAt: (data['pushedAt'] as Timestamp?)?.toDate(),
      actorUserId: data['actorUserId'] as String?,
      actorUserName: data['actorUserName'] as String?,
      boardId: data['boardId'] as String?,
      taskId: data['taskId'] as String?,
      thoughtId: data['thoughtId'] as String?,
      eventKey: data['eventKey'] as String?,
      metadata: data['metadata'] == null
          ? null
          : Map<String, dynamic>.from(data['metadata'] as Map),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'recipientUserId': recipientUserId,
      'title': title,
      'message': message,
      'type': normalizeType(type),
      'deliveryStatus': normalizeDeliveryStatus(deliveryStatus),
      'isRead': isRead,
      'isDeleted': isDeleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (readAt != null) 'readAt': Timestamp.fromDate(readAt!),
      if (pushedAt != null) 'pushedAt': Timestamp.fromDate(pushedAt!),
      if (actorUserId != null) 'actorUserId': actorUserId,
      if (actorUserName != null) 'actorUserName': actorUserName,
      if (boardId != null) 'boardId': boardId,
      if (taskId != null) 'taskId': taskId,
      if (thoughtId != null) 'thoughtId': thoughtId,
      if (eventKey != null) 'eventKey': eventKey,
      if (metadata != null) 'metadata': metadata,
    };
  }

  AppNotification copyWith({
    String? notificationId,
    String? recipientUserId,
    String? title,
    String? message,
    String? type,
    String? deliveryStatus,
    bool? isRead,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? readAt,
    DateTime? pushedAt,
    String? actorUserId,
    String? actorUserName,
    String? boardId,
    String? taskId,
    String? thoughtId,
    String? eventKey,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      notificationId: notificationId ?? this.notificationId,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: normalizeType(type ?? this.type),
      deliveryStatus: normalizeDeliveryStatus(
        deliveryStatus ?? this.deliveryStatus,
      ),
      isRead: isRead ?? this.isRead,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      readAt: readAt ?? this.readAt,
      pushedAt: pushedAt ?? this.pushedAt,
      actorUserId: actorUserId ?? this.actorUserId,
      actorUserName: actorUserName ?? this.actorUserName,
      boardId: boardId ?? this.boardId,
      taskId: taskId ?? this.taskId,
      thoughtId: thoughtId ?? this.thoughtId,
      eventKey: eventKey ?? this.eventKey,
      metadata: metadata ?? this.metadata,
    );
  }

  static String normalizeType(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return normalized.isEmpty ? 'general' : normalized;
  }

  static String normalizeDeliveryStatus(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case deliverySent:
        return deliverySent;
      case deliveryFailed:
        return deliveryFailed;
      case deliveryPending:
      default:
        return deliveryPending;
    }
  }
}
