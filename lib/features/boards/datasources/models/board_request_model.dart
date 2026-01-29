import 'package:cloud_firestore/cloud_firestore.dart';

class BoardRequest {
  final String boardRequestId;
  final String boardId;
  final String boardTitle;
  final String boardManagerId;
  final String boardManagerName;
  final String userId;
  final String userName;
  final String? userProfilePicture;
  final String boardReqStatus; // 'pending', 'approved', 'rejected'
  final String boardReqType; // 'recruitment' or 'application'
  final String? boardReqMessage; // User's message with the request
  final DateTime boardReqCreatedAt;
  final DateTime? boardReqRespondedAt;
  final String? boardReqRespondedBy; // Manager who approved/rejected
  final String? boardReqResponseMessage; // Manager's response message

  BoardRequest({
    required this.boardRequestId,
    required this.boardId,
    required this.boardTitle,
    required this.boardManagerId,
    required this.boardManagerName,
    required this.userId,
    required this.userName,
    this.userProfilePicture,
    required this.boardReqStatus,
    this.boardReqType = 'recruitment', // Default to recruitment for backward compatibility
    this.boardReqMessage,
    required this.boardReqCreatedAt,
    this.boardReqRespondedAt,
    this.boardReqRespondedBy,
    this.boardReqResponseMessage,
  });

  factory BoardRequest.fromMap(
    Map<String, dynamic> data,
    String documentId,
  ) {
    return BoardRequest(
      boardRequestId: documentId,
      boardId: data['boardId'] ?? '',
      boardTitle: data['boardTitle'] ?? 'Unknown',
      boardManagerId: data['boardManagerId'] ?? '',
      boardManagerName: data['boardManagerName'] ?? 'Unknown',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userProfilePicture: data['userProfilePicture'] as String?,
      boardReqStatus: data['boardReqStatus'] ?? data['requestStatus'] ?? 'pending',
      boardReqType: data['boardReqType'] ?? data['requestType'] ?? 'recruitment', // Handle migration from old field names
      boardReqMessage: data['boardReqMessage'] ?? data['requestMessage'] as String?,
      boardReqCreatedAt:
          (data['boardReqCreatedAt'] as Timestamp?)?.toDate() ?? (data['requestCreatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      boardReqRespondedAt: (data['boardReqRespondedAt'] as Timestamp?)?.toDate() ?? (data['requestRespondedAt'] as Timestamp?)?.toDate(),
      boardReqRespondedBy: data['boardReqRespondedBy'] ?? data['requestRespondedBy'] as String?,
      boardReqResponseMessage: data['boardReqResponseMessage'] ?? data['requestResponseMessage'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'boardRequestId': boardRequestId,
      'boardId': boardId,
      'boardTitle': boardTitle,
      'boardManagerId': boardManagerId,
      'boardManagerName': boardManagerName,
      'userId': userId,
      'userName': userName,
      if (userProfilePicture != null) 'userProfilePicture': userProfilePicture,
      'boardReqStatus': boardReqStatus,
      'boardReqType': boardReqType,
      if (boardReqMessage != null) 'boardReqMessage': boardReqMessage,
      'boardReqCreatedAt': Timestamp.fromDate(boardReqCreatedAt),
      if (boardReqRespondedAt != null)
        'boardReqRespondedAt': Timestamp.fromDate(boardReqRespondedAt!),
      if (boardReqRespondedBy != null) 'boardReqRespondedBy': boardReqRespondedBy,
      if (boardReqResponseMessage != null)
        'boardReqResponseMessage': boardReqResponseMessage,
    };
  }

  BoardRequest copyWith({
    String? boardRequestId,
    String? boardId,
    String? boardTitle,
    String? boardManagerId,
    String? boardManagerName,
    String? userId,
    String? userName,
    String? userProfilePicture,
    String? boardReqStatus,
    String? boardReqType,
    String? boardReqMessage,
    DateTime? boardReqCreatedAt,
    DateTime? boardReqRespondedAt,
    String? boardReqRespondedBy,
    String? boardReqResponseMessage,
  }) {
    return BoardRequest(
      boardRequestId: boardRequestId ?? this.boardRequestId,
      boardId: boardId ?? this.boardId,
      boardTitle: boardTitle ?? this.boardTitle,
      boardManagerId: boardManagerId ?? this.boardManagerId,
      boardManagerName: boardManagerName ?? this.boardManagerName,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfilePicture: userProfilePicture ?? this.userProfilePicture,
      boardReqStatus: boardReqStatus ?? this.boardReqStatus,
      boardReqType: boardReqType ?? this.boardReqType,
      boardReqMessage: boardReqMessage ?? this.boardReqMessage,
      boardReqCreatedAt: boardReqCreatedAt ?? this.boardReqCreatedAt,
      boardReqRespondedAt: boardReqRespondedAt ?? this.boardReqRespondedAt,
      boardReqRespondedBy: boardReqRespondedBy ?? this.boardReqRespondedBy,
      boardReqResponseMessage:
          boardReqResponseMessage ?? this.boardReqResponseMessage,
    );
  }
}
