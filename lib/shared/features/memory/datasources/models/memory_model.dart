import 'package:cloud_firestore/cloud_firestore.dart';

class MemoryModel {
  static const String timingNow = 'now';
  static const String timingLater = 'later';

  static const String targetUser = 'user';
  static const String targetBoard = 'board';
  static const String targetTask = 'task';

  static const String statusPending = 'pending';
  static const String statusSent = 'sent';
  static const String statusScheduled = 'scheduled';

  final String memoryId;
  final String createdByUserId;
  final String createdByUserName;
  final String targetType;
  final String targetId;
  final String targetLabel;
  final String? subject;
  final String message;
  final String? threadId;
  final String? inReplyToMemoryId;
  final String timing;
  final DateTime? scheduledAt;
  final String status;
  final String? recipientUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MemoryModel({
    required this.memoryId,
    required this.createdByUserId,
    required this.createdByUserName,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
    this.subject,
    required this.message,
    this.threadId,
    this.inReplyToMemoryId,
    required this.timing,
    required this.createdAt,
    required this.updatedAt,
    this.scheduledAt,
    this.status = statusPending,
    this.recipientUserId,
  });

  factory MemoryModel.fromMap(Map<String, dynamic> map, String id) {
    return MemoryModel(
      memoryId: (map['memoryId'] as String?) ??
          (map['pokeId'] as String?) ??
          id,
      createdByUserId: map['createdByUserId'] as String? ?? '',
      createdByUserName: map['createdByUserName'] as String? ?? 'Unknown',
      targetType: map['targetType'] as String? ?? targetUser,
      targetId: map['targetId'] as String? ?? '',
      targetLabel: map['targetLabel'] as String? ?? '',
      subject: map['subject'] as String?,
      message: map['message'] as String? ?? '',
      threadId: map['threadId'] as String?,
      inReplyToMemoryId: (map['inReplyToMemoryId'] as String?) ??
          (map['inReplyToPokeId'] as String?),
      timing: map['timing'] as String? ?? timingNow,
      scheduledAt: (map['scheduledAt'] as Timestamp?)?.toDate(),
      status: map['status'] as String? ?? statusPending,
      recipientUserId: map['recipientUserId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ??
          (map['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'memoryId': memoryId,
      // Backward compatibility for existing consumers/data.
      'pokeId': memoryId,
      'createdByUserId': createdByUserId,
      'createdByUserName': createdByUserName,
      'targetType': targetType,
      'targetId': targetId,
      'targetLabel': targetLabel,
      if (subject != null && subject!.trim().isNotEmpty) 'subject': subject,
      'message': message,
      if (threadId != null && threadId!.trim().isNotEmpty) 'threadId': threadId,
      if (inReplyToMemoryId != null && inReplyToMemoryId!.trim().isNotEmpty) ...{
        'inReplyToMemoryId': inReplyToMemoryId,
        // Backward compatibility for existing consumers/data.
        'inReplyToPokeId': inReplyToMemoryId,
      },
      'timing': timing,
      if (scheduledAt != null) 'scheduledAt': Timestamp.fromDate(scheduledAt!),
      'status': status,
      if (recipientUserId != null) 'recipientUserId': recipientUserId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  String get effectiveThreadId => (threadId ?? '').trim().isEmpty
      ? (memoryId.trim().isEmpty ? targetId : memoryId)
      : threadId!.trim();
}
