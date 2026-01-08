import 'package:cloud_firestore/cloud_firestore.dart';

class BoardJoinRequest {
  final String boardJoinRequestId;
  final String boardId;
  final String boardTitle;
  final String boardManagerId;
  final String boardManagerName;
  final String userId;
  final String userName;
  final String? userProfilePicture;
  final String requestStatus; // 'pending', 'approved', 'rejected'
  final String? requestMessage; // User's message with the request
  final DateTime requestCreatedAt;
  final DateTime? requestRespondedAt;
  final String? requestRespondedBy; // Manager who approved/rejected
  final String? requestResponseMessage; // Manager's response message

  BoardJoinRequest({
    required this.boardJoinRequestId,
    required this.boardId,
    required this.boardTitle,
    required this.boardManagerId,
    required this.boardManagerName,
    required this.userId,
    required this.userName,
    this.userProfilePicture,
    required this.requestStatus,
    this.requestMessage,
    required this.requestCreatedAt,
    this.requestRespondedAt,
    this.requestRespondedBy,
    this.requestResponseMessage,
  });

  factory BoardJoinRequest.fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return BoardJoinRequest(
      boardJoinRequestId: documentId,
      boardId: data['boardId'] ?? '',
      boardTitle: data['boardTitle'] ?? 'Unknown',
      boardManagerId: data['boardManagerId'] ?? '',
      boardManagerName: data['boardManagerName'] ?? 'Unknown',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userProfilePicture: data['userProfilePicture'] as String?,
      requestStatus: data['requestStatus'] ?? 'pending',
      requestMessage: data['requestMessage'] as String?,
      requestCreatedAt:
          (data['requestCreatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      requestRespondedAt: (data['requestRespondedAt'] as Timestamp?)?.toDate(),
      requestRespondedBy: data['requestRespondedBy'] as String?,
      requestResponseMessage: data['requestResponseMessage'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'boardJoinRequestId': boardJoinRequestId,
      'boardId': boardId,
      'boardTitle': boardTitle,
      'boardManagerId': boardManagerId,
      'boardManagerName': boardManagerName,
      'userId': userId,
      'userName': userName,
      if (userProfilePicture != null) 'userProfilePicture': userProfilePicture,
      'requestStatus': requestStatus,
      if (requestMessage != null) 'requestMessage': requestMessage,
      'requestCreatedAt': Timestamp.fromDate(requestCreatedAt),
      if (requestRespondedAt != null)
        'requestRespondedAt': Timestamp.fromDate(requestRespondedAt!),
      if (requestRespondedBy != null) 'requestRespondedBy': requestRespondedBy,
      if (requestResponseMessage != null)
        'requestResponseMessage': requestResponseMessage,
    };
  }

  BoardJoinRequest copyWith({
    String? boardJoinRequestId,
    String? boardId,
    String? boardTitle,
    String? boardManagerId,
    String? boardManagerName,
    String? userId,
    String? userName,
    String? userProfilePicture,
    String? requestStatus,
    String? requestMessage,
    DateTime? requestCreatedAt,
    DateTime? requestRespondedAt,
    String? requestRespondedBy,
    String? requestResponseMessage,
  }) {
    return BoardJoinRequest(
      boardJoinRequestId: boardJoinRequestId ?? this.boardJoinRequestId,
      boardId: boardId ?? this.boardId,
      boardTitle: boardTitle ?? this.boardTitle,
      boardManagerId: boardManagerId ?? this.boardManagerId,
      boardManagerName: boardManagerName ?? this.boardManagerName,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfilePicture: userProfilePicture ?? this.userProfilePicture,
      requestStatus: requestStatus ?? this.requestStatus,
      requestMessage: requestMessage ?? this.requestMessage,
      requestCreatedAt: requestCreatedAt ?? this.requestCreatedAt,
      requestRespondedAt: requestRespondedAt ?? this.requestRespondedAt,
      requestRespondedBy: requestRespondedBy ?? this.requestRespondedBy,
      requestResponseMessage:
          requestResponseMessage ?? this.requestResponseMessage,
    );
  }
}
