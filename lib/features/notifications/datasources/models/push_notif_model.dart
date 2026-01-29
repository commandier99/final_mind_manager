import 'package:cloud_firestore/cloud_firestore.dart';

class PushNotification {
  final String notificationId;
  final String userId;
  final String title;
  final String body;
  final String? category; // 'invitation', 'request', 'update', etc.
  final String? relatedId; // Reference to related document (boardId, etc.)
  final bool isSent;
  final DateTime createdAt;
  final DateTime? sentAt;
  final String? deviceToken;
  final int? attempts;
  final String? lastError;
  final Map<String, dynamic>? data; // Additional payload

  PushNotification({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.body,
    this.category,
    this.relatedId,
    required this.isSent,
    required this.createdAt,
    this.sentAt,
    this.deviceToken,
    this.attempts,
    this.lastError,
    this.data,
  });

  factory PushNotification.fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return PushNotification(
      notificationId: documentId,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      category: data['category'] as String?,
      relatedId: data['relatedId'] as String?,
      isSent: data['isSent'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
      deviceToken: data['deviceToken'] as String?,
      attempts: data['attempts'] as int?,
      lastError: data['lastError'] as String?,
      data: data['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'userId': userId,
      'title': title,
      'body': body,
      if (category != null) 'category': category,
      if (relatedId != null) 'relatedId': relatedId,
      'isSent': isSent,
      'createdAt': Timestamp.fromDate(createdAt),
      if (sentAt != null) 'sentAt': Timestamp.fromDate(sentAt!),
      if (deviceToken != null) 'deviceToken': deviceToken,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'lastError': lastError,
      if (data != null) 'data': data,
    };
  }

  PushNotification copyWith({
    String? notificationId,
    String? userId,
    String? title,
    String? body,
    String? category,
    String? relatedId,
    bool? isSent,
    DateTime? createdAt,
    DateTime? sentAt,
    String? deviceToken,
    int? attempts,
    String? lastError,
    Map<String, dynamic>? data,
  }) {
    return PushNotification(
      notificationId: notificationId ?? this.notificationId,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      relatedId: relatedId ?? this.relatedId,
      isSent: isSent ?? this.isSent,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
      deviceToken: deviceToken ?? this.deviceToken,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      data: data ?? this.data,
    );
  }

  @override
  String toString() =>
      'PushNotification(id: $notificationId, userId: $userId, title: $title, isSent: $isSent)';
}
