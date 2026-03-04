import 'package:cloud_firestore/cloud_firestore.dart';
import 'board_roles.dart';

class BoardRequest {
  static const String typeRecruitment = 'recruitment';
  static const String typeApplication = 'application';
  static const Set<String> allowedTypes = {typeRecruitment, typeApplication};

  static String normalizeType(String? type) {
    final raw = (type ?? '').trim().toLowerCase();
    if (raw == typeRecruitment || raw == 'invitation') {
      return typeRecruitment;
    }
    if (raw == typeApplication || raw == 'join_request') {
      return typeApplication;
    }
    return typeRecruitment;
  }

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
  final String
  boardReqRequestedRole; // 'member' or 'supervisor' for invitations
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
    this.boardReqType = typeRecruitment,
    this.boardReqMessage,
    this.boardReqRequestedRole = BoardRoles.member,
    required this.boardReqCreatedAt,
    this.boardReqRespondedAt,
    this.boardReqRespondedBy,
    this.boardReqResponseMessage,
  });

  factory BoardRequest.fromMap(Map<String, dynamic> data, String documentId) {
    return BoardRequest(
      boardRequestId: documentId,
      boardId: data['boardId'] ?? '',
      boardTitle: data['boardTitle'] ?? 'Unknown',
      boardManagerId: data['boardManagerId'] ?? '',
      boardManagerName: data['boardManagerName'] ?? 'Unknown',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userProfilePicture: data['userProfilePicture'] as String?,
      boardReqStatus:
          data['boardReqStatus'] ?? data['requestStatus'] ?? 'pending',
      boardReqType: normalizeType(
        data['boardReqType']?.toString() ?? data['requestType']?.toString(),
      ),
      boardReqMessage:
          data['boardReqMessage'] ?? data['requestMessage'] as String?,
      boardReqRequestedRole: BoardRoles.normalize(
        data['boardReqRequestedRole'] as String?,
      ),
      boardReqCreatedAt:
          (data['boardReqCreatedAt'] as Timestamp?)?.toDate() ??
          (data['requestCreatedAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      boardReqRespondedAt:
          (data['boardReqRespondedAt'] as Timestamp?)?.toDate() ??
          (data['requestRespondedAt'] as Timestamp?)?.toDate(),
      boardReqRespondedBy:
          data['boardReqRespondedBy'] ?? data['requestRespondedBy'] as String?,
      boardReqResponseMessage:
          data['boardReqResponseMessage'] ??
          data['requestResponseMessage'] as String?,
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
      'boardReqType': normalizeType(boardReqType),
      if (boardReqMessage != null) 'boardReqMessage': boardReqMessage,
      'boardReqRequestedRole': boardReqRequestedRole,
      'boardReqCreatedAt': Timestamp.fromDate(boardReqCreatedAt),
      if (boardReqRespondedAt != null)
        'boardReqRespondedAt': Timestamp.fromDate(boardReqRespondedAt!),
      if (boardReqRespondedBy != null)
        'boardReqRespondedBy': boardReqRespondedBy,
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
    String? boardReqRequestedRole,
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
      boardReqType: normalizeType(boardReqType ?? this.boardReqType),
      boardReqMessage: boardReqMessage ?? this.boardReqMessage,
      boardReqRequestedRole: BoardRoles.normalize(
        boardReqRequestedRole ?? this.boardReqRequestedRole,
      ),
      boardReqCreatedAt: boardReqCreatedAt ?? this.boardReqCreatedAt,
      boardReqRespondedAt: boardReqRespondedAt ?? this.boardReqRespondedAt,
      boardReqRespondedBy: boardReqRespondedBy ?? this.boardReqRespondedBy,
      boardReqResponseMessage:
          boardReqResponseMessage ?? this.boardReqResponseMessage,
    );
  }
}
