import 'package:cloud_firestore/cloud_firestore.dart';

class TaskAppeal {
  final String userId;
  final String userName;
  final String userProfilePicture;
  final String appealText;
  final Timestamp createdAt;

  const TaskAppeal({
    required this.userId,
    required this.userName,
    required this.userProfilePicture,
    required this.appealText,
    required this.createdAt,
  });

  /// Create a TaskAppeal from a map
  factory TaskAppeal.fromMap(Map<String, dynamic> map) {
    return TaskAppeal(
      userId: map['userId'] as String,
      userName: map['userName'] as String,
      userProfilePicture: map['userProfilePicture'] as String? ?? '',
      appealText: map['appealText'] as String,
      createdAt: map['createdAt'] as Timestamp,
    );
  }

  /// Convert TaskAppeal to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userProfilePicture': userProfilePicture,
      'appealText': appealText,
      'createdAt': createdAt,
    };
  }

  /// Create a copy with optional field updates
  TaskAppeal copyWith({
    String? userId,
    String? userName,
    String? userProfilePicture,
    String? appealText,
    Timestamp? createdAt,
  }) {
    return TaskAppeal(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfilePicture: userProfilePicture ?? this.userProfilePicture,
      appealText: appealText ?? this.appealText,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'TaskAppeal(userId: $userId, userName: $userName, appealText: $appealText, createdAt: $createdAt)';
  }
}
