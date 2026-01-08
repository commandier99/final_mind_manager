import 'package:cloud_firestore/cloud_firestore.dart';

class BoardMember {
  final String boardMemberId;
  final String boardId;
  final String userId;
  final String userName;
  final String? userProfilePicture;
  final String memberRole; // 'manager', 'member', 'inspector'
  final int memberTaskLimit; // Max tasks they can be assigned
  final int memberCurrentTaskCount; // Current tasks assigned
  final DateTime memberJoinedAt;
  final DateTime memberLastActiveAt;

  BoardMember({
    required this.boardMemberId,
    required this.boardId,
    required this.userId,
    required this.userName,
    this.userProfilePicture,
    required this.memberRole,
    required this.memberTaskLimit,
    this.memberCurrentTaskCount = 0,
    required this.memberJoinedAt,
    required this.memberLastActiveAt,
  });

  factory BoardMember.fromMap(Map<String, dynamic> data, String documentId) {
    return BoardMember(
      boardMemberId: documentId,
      boardId: data['boardId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userProfilePicture: data['userProfilePicture'] as String?,
      memberRole: data['memberRole'] ?? 'member',
      memberTaskLimit: data['memberTaskLimit'] ?? 0,
      memberCurrentTaskCount: data['memberCurrentTaskCount'] ?? 0,
      memberJoinedAt: (data['memberJoinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memberLastActiveAt: (data['memberLastActiveAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'boardMemberId': boardMemberId,
      'boardId': boardId,
      'userId': userId,
      'userName': userName,
      if (userProfilePicture != null) 'userProfilePicture': userProfilePicture,
      'memberRole': memberRole,
      'memberTaskLimit': memberTaskLimit,
      'memberCurrentTaskCount': memberCurrentTaskCount,
      'memberJoinedAt': Timestamp.fromDate(memberJoinedAt),
      'memberLastActiveAt': Timestamp.fromDate(memberLastActiveAt),
    };
  }

  BoardMember copyWith({
    String? boardMemberId,
    String? boardId,
    String? userId,
    String? userName,
    String? userProfilePicture,
    String? memberRole,
    int? memberTaskLimit,
    int? memberCurrentTaskCount,
    DateTime? memberJoinedAt,
    DateTime? memberLastActiveAt,
  }) {
    return BoardMember(
      boardMemberId: boardMemberId ?? this.boardMemberId,
      boardId: boardId ?? this.boardId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfilePicture: userProfilePicture ?? this.userProfilePicture,
      memberRole: memberRole ?? this.memberRole,
      memberTaskLimit: memberTaskLimit ?? this.memberTaskLimit,
      memberCurrentTaskCount: memberCurrentTaskCount ?? this.memberCurrentTaskCount,
      memberJoinedAt: memberJoinedAt ?? this.memberJoinedAt,
      memberLastActiveAt: memberLastActiveAt ?? this.memberLastActiveAt,
    );
  }
}
