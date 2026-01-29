import 'package:cloud_firestore/cloud_firestore.dart';

class EmailNotification {
  final String notificationId;
  final String userId;
  final String userEmail;
  final String subject;
  final String body;
  final String? htmlBody;
  final String? category; // 'invitation', 'request', 'update', etc.
  final String? relatedId; // Reference to related document (boardId, etc.)
  final bool isSent;
  final DateTime createdAt;
  final DateTime? sentAt;
  final int? attempts;
  final String? lastError;
  final List<String>? attachments;
  final Map<String, dynamic>? metadata; // Additional data

  EmailNotification({
    required this.notificationId,
    required this.userId,
    required this.userEmail,
    required this.subject,
    required this.body,
    this.htmlBody,
    this.category,
    this.relatedId,
    required this.isSent,
    required this.createdAt,
    this.sentAt,
    this.attempts,
    this.lastError,
    this.attachments,
    this.metadata,
  });

  factory EmailNotification.fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return EmailNotification(
      notificationId: documentId,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      subject: data['subject'] ?? '',
      body: data['body'] ?? '',
      htmlBody: data['htmlBody'] as String?,
      category: data['category'] as String?,
      relatedId: data['relatedId'] as String?,
      isSent: data['isSent'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
      attempts: data['attempts'] as int?,
      lastError: data['lastError'] as String?,
      attachments: data['attachments'] != null
          ? List<String>.from(data['attachments'] as List)
          : null,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'userId': userId,
      'userEmail': userEmail,
      'subject': subject,
      'body': body,
      if (htmlBody != null) 'htmlBody': htmlBody,
      if (category != null) 'category': category,
      if (relatedId != null) 'relatedId': relatedId,
      'isSent': isSent,
      'createdAt': Timestamp.fromDate(createdAt),
      if (sentAt != null) 'sentAt': Timestamp.fromDate(sentAt!),
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'lastError': lastError,
      if (attachments != null) 'attachments': attachments,
      if (metadata != null) 'metadata': metadata,
    };
  }

  EmailNotification copyWith({
    String? notificationId,
    String? userId,
    String? userEmail,
    String? subject,
    String? body,
    String? htmlBody,
    String? category,
    String? relatedId,
    bool? isSent,
    DateTime? createdAt,
    DateTime? sentAt,
    int? attempts,
    String? lastError,
    List<String>? attachments,
    Map<String, dynamic>? metadata,
  }) {
    return EmailNotification(
      notificationId: notificationId ?? this.notificationId,
      userId: userId ?? this.userId,
      userEmail: userEmail ?? this.userEmail,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      htmlBody: htmlBody ?? this.htmlBody,
      category: category ?? this.category,
      relatedId: relatedId ?? this.relatedId,
      isSent: isSent ?? this.isSent,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      attachments: attachments ?? this.attachments,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() =>
      'EmailNotification(id: $notificationId, userId: $userId, email: $userEmail, isSent: $isSent)';
}
