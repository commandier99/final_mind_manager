import 'package:cloud_firestore/cloud_firestore.dart';

class PokeModel {
  static const String timingNow = 'now';
  static const String timingLater = 'later';

  static const String targetUser = 'user';
  static const String targetBoard = 'board';
  static const String targetTask = 'task';

  static const String statusPending = 'pending';
  static const String statusSent = 'sent';
  static const String statusScheduled = 'scheduled';

  final String pokeId;
  final String createdByUserId;
  final String createdByUserName;
  final String targetType;
  final String targetId;
  final String targetLabel;
  final String message;
  final String timing;
  final DateTime? scheduledAt;
  final String status;
  final String? recipientUserId;
  final DateTime createdAt;

  const PokeModel({
    required this.pokeId,
    required this.createdByUserId,
    required this.createdByUserName,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
    required this.message,
    required this.timing,
    required this.createdAt,
    this.scheduledAt,
    this.status = statusPending,
    this.recipientUserId,
  });

  factory PokeModel.fromMap(Map<String, dynamic> map, String id) {
    return PokeModel(
      pokeId: id,
      createdByUserId: map['createdByUserId'] as String? ?? '',
      createdByUserName: map['createdByUserName'] as String? ?? 'Unknown',
      targetType: map['targetType'] as String? ?? targetUser,
      targetId: map['targetId'] as String? ?? '',
      targetLabel: map['targetLabel'] as String? ?? '',
      message: map['message'] as String? ?? '',
      timing: map['timing'] as String? ?? timingNow,
      scheduledAt: (map['scheduledAt'] as Timestamp?)?.toDate(),
      status: map['status'] as String? ?? statusPending,
      recipientUserId: map['recipientUserId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'createdByUserId': createdByUserId,
      'createdByUserName': createdByUserName,
      'targetType': targetType,
      'targetId': targetId,
      'targetLabel': targetLabel,
      'message': message,
      'timing': timing,
      if (scheduledAt != null) 'scheduledAt': Timestamp.fromDate(scheduledAt!),
      'status': status,
      if (recipientUserId != null) 'recipientUserId': recipientUserId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

