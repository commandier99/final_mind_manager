import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/board_join_request_model.dart';
import 'board_services.dart';

class BoardJoinRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final BoardService _boardService = BoardService();

  CollectionReference get _requestsCollection =>
      _firestore.collection('board_join_requests');

  // ========================
  // CREATE REQUEST
  // ========================

  Future<void> createJoinRequest({
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

      final request = BoardJoinRequest(
        boardJoinRequestId: requestId,
        boardId: boardId,
        boardTitle: boardTitle,
        boardManagerId: boardData?['boardManagerId'] ?? '',
        boardManagerName: boardData?['boardManagerName'] ?? 'Unknown',
        userId: userId,
        userName: userData?['userName'] ?? 'Unknown User',
        userProfilePicture: userData?['userProfilePicture'],
        requestStatus: 'pending',
        requestMessage: message,
        requestCreatedAt: DateTime.now(),
      );

      await _requestsCollection.doc(requestId).set(request.toMap());
      print('✅ Join request created for board $boardId');
    } catch (e) {
      print('⚠️ Error creating join request: $e');
      rethrow;
    }
  }

  // ========================
  // READ REQUESTS
  // ========================

  /// Get all pending requests for a board (for managers)
  Stream<List<BoardJoinRequest>> streamPendingRequestsForBoard(String boardId) {
    return _requestsCollection
        .where('boardId', isEqualTo: boardId)
        .where('requestStatus', isEqualTo: 'pending')
        .orderBy('requestCreatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => BoardJoinRequest.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
        });
  }

  /// Get all requests made by a user
  Stream<List<BoardJoinRequest>> streamRequestsByUser(String userId) {
    print('[BoardJoinRequestService] Setting up stream for userId: $userId');
    try {
      return _requestsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('requestCreatedAt', descending: true)
          .snapshots()
          .handleError((error) {
            print('[BoardJoinRequestService] ERROR in stream: $error');
            throw error;
          })
          .map((snapshot) {
            print(
              '[BoardJoinRequestService] Snapshot received with ${snapshot.docs.length} documents',
            );
            return snapshot.docs.map((doc) {
              print('[BoardJoinRequestService] Request: ${doc.data()}');
              return BoardJoinRequest.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList();
          });
    } catch (e) {
      print('[BoardJoinRequestService] Exception setting up stream: $e');
      rethrow;
    }
  }

  /// Check if user has pending request for a board
  Future<bool> hasPendingRequest(String boardId, String userId) async {
    final snapshot =
        await _requestsCollection
            .where('boardId', isEqualTo: boardId)
            .where('userId', isEqualTo: userId)
            .where('requestStatus', isEqualTo: 'pending')
            .get();

    return snapshot.docs.isNotEmpty;
  }

  // ========================
  // UPDATE REQUEST
  // ========================

  /// Approve a join request and add user to board
  Future<void> approveRequest(
    BoardJoinRequest request, {
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
      await _requestsCollection.doc(request.boardJoinRequestId).update({
        'requestStatus': 'approved',
        'requestRespondedAt': Timestamp.fromDate(DateTime.now()),
        'requestRespondedBy': currentUser.uid,
        if (responseMessage != null) 'requestResponseMessage': responseMessage,
      });

      print('✅ Join request approved for user ${request.userId}');
    } catch (e) {
      print('⚠️ Error approving join request: $e');
      rethrow;
    }
  }

  /// Reject a join request
  Future<void> rejectRequest(
    BoardJoinRequest request, {
    String? responseMessage,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      await _requestsCollection.doc(request.boardJoinRequestId).update({
        'requestStatus': 'rejected',
        'requestRespondedAt': Timestamp.fromDate(DateTime.now()),
        'requestRespondedBy': currentUser.uid,
        if (responseMessage != null) 'requestResponseMessage': responseMessage,
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
