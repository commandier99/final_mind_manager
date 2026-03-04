import 'package:cloud_firestore/cloud_firestore.dart';

class TaskApplication {
  final String userId;
  final String userName;
  final String userProfilePicture;
  final String applicationText;
  final Timestamp createdAt;

  const TaskApplication({
    required this.userId,
    required this.userName,
    required this.userProfilePicture,
    required this.applicationText,
    required this.createdAt,
  });

  /// Create a TaskApplication from a map
  factory TaskApplication.fromMap(Map<String, dynamic> map) {
    return TaskApplication(
      userId: map['userId'] as String,
      userName: map['userName'] as String,
      userProfilePicture: map['userProfilePicture'] as String? ?? '',
      applicationText:
          (map['applicationText'] ?? map['appealText'] ?? '') as String,
      createdAt: map['createdAt'] as Timestamp,
    );
  }

  /// Convert TaskApplication to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userProfilePicture': userProfilePicture,
      'applicationText': applicationText,
      'createdAt': createdAt,
    };
  }

  /// Create a copy with optional field updates
  TaskApplication copyWith({
    String? userId,
    String? userName,
    String? userProfilePicture,
    String? applicationText,
    Timestamp? createdAt,
  }) {
    return TaskApplication(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfilePicture: userProfilePicture ?? this.userProfilePicture,
      applicationText: applicationText ?? this.applicationText,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'TaskApplication(userId: $userId, userName: $userName, applicationText: $applicationText, createdAt: $createdAt)';
  }
}
