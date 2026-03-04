import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/board_request_model.dart';
import '../models/board_roles.dart';
import 'board_services.dart';
import 'package:flutter/foundation.dart';
import '../../../notifications/datasources/helpers/notification_helper.dart';
import '../../../../shared/features/users/datasources/services/activity_event_services.dart';

class BoardRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BoardService _boardService = BoardService();
  final ActivityEventService _activityEventService = ActivityEventService();

  CollectionReference get _requestsCollection =>
      _firestore.collection('board_join_requests');

  // ========================
  // CREATE REQUEST
  // ========================

  /// Create an invitation request (manager inviting a user to join)
  Future<void> createInvitation({
    required String boardId,
    required String boardTitle,
    required String userId,
    String role = BoardRoles.member,
    String? message,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get user data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();

      // Get board data for manager info
      final boardDoc = await _firestore.collection('boards').doc(boardId).get();
      final boardData = boardDoc.data();

      final requestId = _requestsCollection.doc().id;

      final requestedRole = BoardRoles.normalize(role);
      if (!BoardRoles.isAssignable(requestedRole)) {
        throw Exception(
          'Invalid invitation role: $role. Allowed roles are member or supervisor.',
        );
      }

      final request = BoardRequest(
        boardRequestId: requestId,
        boardId: boardId,
        boardTitle: boardTitle,
        boardManagerId: boardData?['boardManagerId'] ?? '',
        boardManagerName: boardData?['boardManagerName'] ?? 'Unknown',
        userId: userId,
        userName: userData?['userName'] ?? 'Unknown User',
        userProfilePicture: userData?['userProfilePicture'],
        boardReqStatus: 'pending',
        boardReqType: BoardRequest.typeRecruitment,
        boardReqMessage: message ?? 'You have been invited to join this board',
        boardReqRequestedRole: requestedRole,
        boardReqCreatedAt: DateTime.now(),
      );

      await _requestsCollection.doc(requestId).set(request.toMap());

      await _activityEventService.logEvent(
        userId: currentUser.uid,
        userName: boardData?['boardManagerName'] ?? 'Unknown User',
        activityType: 'board_invitation_sent',
        boardId: boardId,
        description: 'sent a board invitation',
        metadata: {
          'boardRequestId': requestId,
          'invitedUserId': userId,
          'invitedUserName': userData?['userName'] ?? 'Unknown User',
          'requestedRole': requestedRole,
        },
      );

      await NotificationHelper.createNotificationPair(
        userId: userId,
        title: 'Board Invitation',
        message:
            '${boardData?['boardManagerName'] ?? 'A manager'} invited you to join "$boardTitle".',
        category: NotificationHelper.categoryInvitation,
        relatedId: requestId,
        metadata: {
          'boardId': boardId,
          'boardTitle': boardTitle,
          'boardRequestId': requestId,
          'boardReqType': BoardRequest.typeRecruitment,
          'requestedRole': requestedRole,
          'managerId': boardData?['boardManagerId'] ?? '',
          'managerName': boardData?['boardManagerName'] ?? 'Unknown',
        },
      );

      debugPrint('✅ Invitation created for user $userId to board $boardId');
    } catch (e) {
      debugPrint('⚠️ Error creating invitation: $e');
      rethrow;
    }
  }

  /// Create a join request (user requesting to join a public board)
  Future<void> createJoinRequest({
    required String boardId,
    required String boardTitle,
    String? message,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get user data
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userData = userDoc.data();

      // Get board data for manager info
      final boardDoc = await _firestore.collection('boards').doc(boardId).get();
      final boardData = boardDoc.data();

      // Check if board is public
      final isPublic = boardData?['boardIsPublic'] ?? false;
      if (!isPublic) {
        throw Exception(
          'This board is private and does not accept join requests',
        );
      }

      final requestId = _requestsCollection.doc().id;

      final request = BoardRequest(
        boardRequestId: requestId,
        boardId: boardId,
        boardTitle: boardTitle,
        boardManagerId: boardData?['boardManagerId'] ?? '',
        boardManagerName: boardData?['boardManagerName'] ?? 'Unknown',
        userId: currentUser.uid,
        userName: userData?['userName'] ?? 'Unknown User',
        userProfilePicture: userData?['userProfilePicture'],
        boardReqStatus: 'pending',
        boardReqType: BoardRequest.typeApplication,
        boardReqMessage: message,
        boardReqCreatedAt: DateTime.now(),
      );

      await _requestsCollection.doc(requestId).set(request.toMap());

      await _activityEventService.logEvent(
        userId: currentUser.uid,
        userName: userData?['userName'] ?? 'Unknown User',
        userProfilePicture: userData?['userProfilePicture'] as String?,
        activityType: 'board_join_requested',
        boardId: boardId,
        description: 'requested to join a board',
        metadata: {'boardRequestId': requestId, 'boardTitle': boardTitle},
      );

      debugPrint(
        '✅ Join request created by ${currentUser.uid} for board $boardId',
      );
    } catch (e) {
      debugPrint('⚠️ Error creating join request: $e');
      rethrow;
    }
  }

  // ========================
  // READ REQUESTS
  // ========================

  /// Get all pending requests for a board (for managers)
  Stream<List<BoardRequest>> streamPendingRequestsForBoard(String boardId) {
    return _requestsCollection
        .where('boardId', isEqualTo: boardId)
        .where('boardReqStatus', isEqualTo: 'pending')
        .orderBy('boardReqCreatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => BoardRequest.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
        });
  }

  /// Get pending invitations for a board (manager inviting users)
  Stream<List<BoardRequest>> streamPendingInvitationsForBoard(String boardId) {
    return _requestsCollection
        .where('boardId', isEqualTo: boardId)
        .where('boardReqStatus', isEqualTo: 'pending')
        .where('boardReqType', isEqualTo: BoardRequest.typeRecruitment)
        .orderBy('boardReqCreatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => BoardRequest.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
        });
  }

  /// Get pending join requests for a board (users requesting to join)
  Stream<List<BoardRequest>> streamPendingJoinRequestsForBoard(String boardId) {
    return _requestsCollection
        .where('boardId', isEqualTo: boardId)
        .where('boardReqStatus', isEqualTo: 'pending')
        .where('boardReqType', isEqualTo: BoardRequest.typeApplication)
        .orderBy('boardReqCreatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => BoardRequest.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
        });
  }

  /// Get all invitations received by a user
  Stream<List<BoardRequest>> streamInvitationsByUser(String userId) {
    return _requestsCollection
        .where('userId', isEqualTo: userId)
        .where('boardReqType', isEqualTo: BoardRequest.typeRecruitment)
        .orderBy('boardReqCreatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return BoardRequest.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
        });
  }

  /// Get all invitations sent by a manager
  Stream<List<BoardRequest>> streamInvitationsSentByManager(String managerId) {
    return _requestsCollection
        .where('boardManagerId', isEqualTo: managerId)
        .where('boardReqType', isEqualTo: BoardRequest.typeRecruitment)
        .orderBy('boardReqCreatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return BoardRequest.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
        });
  }

  /// Get all join requests made by a user
  Stream<List<BoardRequest>> streamJoinRequestsByUser(String userId) {
    return _requestsCollection
        .where('userId', isEqualTo: userId)
        .where('boardReqType', isEqualTo: BoardRequest.typeApplication)
        .orderBy('boardReqCreatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return BoardRequest.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();
        });
  }

  /// Get all requests made by a user
  Stream<List<BoardRequest>> streamRequestsByUser(String userId) {
    debugPrint('[BoardRequestService] Setting up stream for userId: $userId');
    try {
      return _requestsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('boardReqCreatedAt', descending: true)
          .snapshots()
          .handleError((error) {
            debugPrint('[BoardRequestService] ERROR in stream: $error');
            throw error;
          })
          .map((snapshot) {
            debugPrint(
              '[BoardRequestService] Snapshot received with ${snapshot.docs.length} documents',
            );
            return snapshot.docs.map((doc) {
              debugPrint('[BoardRequestService] Request: ${doc.data()}');
              return BoardRequest.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList();
          });
    } catch (e) {
      debugPrint('[BoardRequestService] Exception setting up stream: $e');
      rethrow;
    }
  }

  /// Check if user has pending request for a board
  Future<bool> hasPendingRequest(String boardId, String userId) async {
    final snapshot = await _requestsCollection
        .where('boardId', isEqualTo: boardId)
        .where('userId', isEqualTo: userId)
        .where('boardReqStatus', isEqualTo: 'pending')
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // ========================
  // UPDATE REQUEST
  // ========================

  /// Approve a board request.
  /// - application: manager approves and user is added immediately.
  /// - recruitment: invitee accepts; backend trigger adds user to board.
  Future<void> approveRequest(
    BoardRequest request, {
    String? responseMessage,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final requestType = BoardRequest.normalizeType(request.boardReqType);
      final isRecruitment = requestType == BoardRequest.typeRecruitment;
      if (isRecruitment && currentUser.uid != request.userId) {
        throw Exception('Only the invited user can accept this invitation.');
      }
      if (!isRecruitment && currentUser.uid == request.userId) {
        throw Exception(
          'Only the board manager can approve this join request.',
        );
      }

      // Update request status
      await _requestsCollection.doc(request.boardRequestId).update({
        'boardReqStatus': 'approved',
        'boardReqRespondedAt': Timestamp.fromDate(DateTime.now()),
        'boardReqRespondedBy': currentUser.uid,
        if (responseMessage != null) 'boardReqResponseMessage': responseMessage,
      });

      if (requestType == BoardRequest.typeApplication) {
        await _boardService.addMemberToBoard(
          boardId: request.boardId,
          userId: request.userId,
          role: request.boardReqRequestedRole,
        );
      } else {
        // Recruitment (invite) path: invited user accepts and is added immediately.
        await _boardService.addMemberToBoard(
          boardId: request.boardId,
          userId: request.userId,
          role: request.boardReqRequestedRole,
          invitationRequestId: request.boardRequestId,
        );
      }

      await _activityEventService.logEvent(
        userId: currentUser.uid,
        userName: currentUser.displayName ?? request.userName,
        userProfilePicture: currentUser.photoURL,
        activityType: requestType == BoardRequest.typeRecruitment
            ? 'board_invitation_accepted'
            : 'board_join_request_approved',
        boardId: request.boardId,
        description: requestType == BoardRequest.typeRecruitment
            ? 'accepted a board invitation'
            : 'approved a board join request',
        metadata: {
          'boardRequestId': request.boardRequestId,
          'targetUserId': request.userId,
          'targetUserName': request.userName,
        },
      );

      debugPrint(
        '✅ ${requestType == BoardRequest.typeRecruitment ? 'Recruitment' : 'Application'} approved for user ${request.userId}',
      );
    } catch (e) {
      debugPrint('⚠️ Error approving join request: $e');
      rethrow;
    }
  }

  /// Reject a join request
  Future<void> rejectRequest(
    BoardRequest request, {
    String? responseMessage,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');
      final requestType = BoardRequest.normalizeType(request.boardReqType);
      final isRecruitment = requestType == BoardRequest.typeRecruitment;
      if (isRecruitment && currentUser.uid != request.userId) {
        throw Exception('Only the invited user can decline this invitation.');
      }
      if (!isRecruitment && currentUser.uid == request.userId) {
        throw Exception('Only the board manager can reject this join request.');
      }

      await _requestsCollection.doc(request.boardRequestId).update({
        'boardReqStatus': 'rejected',
        'boardReqRespondedAt': Timestamp.fromDate(DateTime.now()),
        'boardReqRespondedBy': currentUser.uid,
        if (responseMessage != null) 'boardReqResponseMessage': responseMessage,
      });

      await _activityEventService.logEvent(
        userId: currentUser.uid,
        userName: currentUser.displayName ?? request.userName,
        userProfilePicture: currentUser.photoURL,
        activityType: requestType == BoardRequest.typeRecruitment
            ? 'board_invitation_declined'
            : 'board_join_request_rejected',
        boardId: request.boardId,
        description: requestType == BoardRequest.typeRecruitment
            ? 'declined a board invitation'
            : 'rejected a board join request',
        metadata: {
          'boardRequestId': request.boardRequestId,
          'targetUserId': request.userId,
          'targetUserName': request.userName,
        },
      );

      debugPrint('✅ Join request rejected for user ${request.userId}');
    } catch (e) {
      debugPrint('⚠️ Error rejecting join request: $e');
      rethrow;
    }
  }

  // ========================
  // DELETE REQUEST
  // ========================

  /// Cancel a pending request (by the requester)
  Future<void> cancelRequest(String requestId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');
      final requestDoc = await _requestsCollection.doc(requestId).get();
      final requestData = requestDoc.data() as Map<String, dynamic>?;

      await _requestsCollection.doc(requestId).delete();

      if (requestData != null) {
        final requestType = BoardRequest.normalizeType(
          requestData['boardReqType']?.toString() ??
              requestData['requestType']?.toString(),
        );
        await _activityEventService.logEvent(
          userId: currentUser.uid,
          userName:
              currentUser.displayName ??
              requestData['userName']?.toString() ??
              'Unknown User',
          userProfilePicture: currentUser.photoURL,
          activityType: requestType == BoardRequest.typeRecruitment
              ? 'board_invitation_cancelled'
              : 'board_join_request_cancelled',
          boardId: requestData['boardId']?.toString(),
          description: requestType == BoardRequest.typeRecruitment
              ? 'cancelled a board invitation'
              : 'cancelled a board join request',
          metadata: {'boardRequestId': requestId},
        );
      }

      debugPrint('✅ Join request cancelled');
    } catch (e) {
      debugPrint('⚠️ Error cancelling join request: $e');
      rethrow;
    }
  }
}
