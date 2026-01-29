import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/board_request_model.dart';
import 'board_services.dart';

class BoardRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BoardService _boardService = BoardService();

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
        boardReqType: 'recruitment',
        boardReqMessage: message ?? 'You have been invited to join this board',
        boardReqCreatedAt: DateTime.now(),
      );

      await _requestsCollection.doc(requestId).set(request.toMap());
      
      print('✅ Invitation created for user $userId to board $boardId');
    } catch (e) {
      print('⚠️ Error creating invitation: $e');
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
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data();

      // Get board data for manager info
      final boardDoc = await _firestore.collection('boards').doc(boardId).get();
      final boardData = boardDoc.data();

      // Check if board is public
      final isPublic = boardData?['boardIsPublic'] ?? false;
      if (!isPublic) {
        throw Exception('This board is private and does not accept join requests');
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
        boardReqType: 'application',
        boardReqMessage: message,
        boardReqCreatedAt: DateTime.now(),
      );

      await _requestsCollection.doc(requestId).set(request.toMap());
      
      print('✅ Join request created by ${currentUser.uid} for board $boardId');
    } catch (e) {
      print('⚠️ Error creating join request: $e');
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
        .where('boardReqType', isEqualTo: 'recruitment')
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
        .where('boardReqType', isEqualTo: 'application')
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
        .where('boardReqType', isEqualTo: 'recruitment')
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
        .where('boardReqType', isEqualTo: 'application')
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
    print('[BoardRequestService] Setting up stream for userId: $userId');
    try {
      return _requestsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('boardReqCreatedAt', descending: true)
          .snapshots()
          .handleError((error) {
            print('[BoardRequestService] ERROR in stream: $error');
            throw error;
          })
          .map((snapshot) {
            print(
              '[BoardRequestService] Snapshot received with ${snapshot.docs.length} documents',
            );
            return snapshot.docs.map((doc) {
              print('[BoardRequestService] Request: ${doc.data()}');
              return BoardRequest.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList();
          });
    } catch (e) {
      print('[BoardRequestService] Exception setting up stream: $e');
      rethrow;
    }
  }

  /// Check if user has pending request for a board
  Future<bool> hasPendingRequest(String boardId, String userId) async {
    final snapshot =
        await _requestsCollection
            .where('boardId', isEqualTo: boardId)
            .where('userId', isEqualTo: userId)
            .where('boardReqStatus', isEqualTo: 'pending')
            .get();

    return snapshot.docs.isNotEmpty;
  }

  // ========================
  // UPDATE REQUEST
  // ========================

  /// Approve a join request and add user to board
  Future<void> approveRequest(
    BoardRequest request, {
    String? responseMessage,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Add user to board
      await _boardService.addMemberToBoard(
        boardId: request.boardId,
        userId: request.userId,
      );

      // Update request status
      await _requestsCollection.doc(request.boardRequestId).update({
        'boardReqStatus': 'approved',
        'boardReqRespondedAt': Timestamp.fromDate(DateTime.now()),
        'boardReqRespondedBy': currentUser.uid,
        if (responseMessage != null) 'boardReqResponseMessage': responseMessage,
      });

      print('✅ Join request approved for user ${request.userId}');
    } catch (e) {
      print('⚠️ Error approving join request: $e');
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

      await _requestsCollection.doc(request.boardRequestId).update({
        'boardReqStatus': 'rejected',
        'boardReqRespondedAt': Timestamp.fromDate(DateTime.now()),
        'boardReqRespondedBy': currentUser.uid,
        if (responseMessage != null) 'boardReqResponseMessage': responseMessage,
      });

      print('✅ Join request rejected for user ${request.userId}');
    } catch (e) {
      print('⚠️ Error rejecting join request: $e');
      rethrow;
    }
  }

  // ========================
  // DELETE REQUEST
  // ========================

  /// Cancel a pending request (by the requester)
  Future<void> cancelRequest(String requestId) async {
    try {
      await _requestsCollection.doc(requestId).delete();
      print('✅ Join request cancelled');
    } catch (e) {
      print('⚠️ Error cancelling join request: $e');
      rethrow;
    }
  }
}
