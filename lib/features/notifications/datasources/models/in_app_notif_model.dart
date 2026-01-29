import 'package:cloud_firestore/cloud_firestore.dart';

class InAppNotification {
  final String notificationId;
  final String userId;
  final String title;
  final String message;
  final String? category; // 'invitation', 'request', 'update', etc.
  final String? relatedId; // Reference to related document (boardId, etc.)
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic>? metadata; // Additional data

  InAppNotification({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.message,
    this.category,
    this.relatedId,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.metadata,
  });

  factory InAppNotification.fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return InAppNotification(
      notificationId: documentId,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      category: data['category'] as String?,
      relatedId: data['relatedId'] as String?,
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'userId': userId,
      'title': title,
      'message': message,
      if (category != null) 'category': category,
      if (relatedId != null) 'relatedId': relatedId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      if (readAt != null) 'readAt': Timestamp.fromDate(readAt!),
      if (metadata != null) 'metadata': metadata,
    };
  }

  InAppNotification copyWith({
    String? notificationId,
    String? userId,
    String? title,
    String? message,
    String? category,
    String? relatedId,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
    Map<String, dynamic>? metadata,
  }) {
    return InAppNotification(
      notificationId: notificationId ?? this.notificationId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      relatedId: relatedId ?? this.relatedId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() =>
      'InAppNotification(id: $notificationId, userId: $userId, title: $title, isRead: $isRead)';
}
