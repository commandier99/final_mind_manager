import 'package:cloud_firestore/cloud_firestore.dart';

class TaskVolunteerRequest {
  final String requestId;
  final String taskId;
  final String boardId;
  final String userId;
  final String userName;
  final String status; // 'pending', 'accepted', 'declined'
  final DateTime createdAt;
  final DateTime? respondedAt;
  final String? respondedBy;
  final String? respondedByName;

  TaskVolunteerRequest({
    required this.requestId,
    required this.taskId,
    required this.boardId,
    required this.userId,
    required this.userName,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.respondedBy,
    this.respondedByName,
  });

  factory TaskVolunteerRequest.fromMap(Map<String, dynamic> map, String id) {
    return TaskVolunteerRequest(
      requestId: id,
      taskId: map['taskId'] ?? '',
      boardId: map['boardId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (map['respondedAt'] as Timestamp?)?.toDate(),
      respondedBy: map['respondedBy'],
      respondedByName: map['respondedByName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'boardId': boardId,
      'userId': userId,
      'userName': userName,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'respondedBy': respondedBy,
      'respondedByName': respondedByName,
    };
  }

  TaskVolunteerRequest copyWith({
    String? requestId,
    String? taskId,
    String? boardId,
    String? userId,
    String? userName,
    String? status,
    DateTime? createdAt,
    DateTime? respondedAt,
    String? respondedBy,
    String? respondedByName,
  }) {
    return TaskVolunteerRequest(
      requestId: requestId ?? this.requestId,
      taskId: taskId ?? this.taskId,
      boardId: boardId ?? this.boardId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
      respondedBy: respondedBy ?? this.respondedBy,
      respondedByName: respondedByName ?? this.respondedByName,
    );
  }
}
