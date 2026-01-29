import 'package:flutter/material.dart';
import '../models/board_request_model.dart';
import '../services/board_request_services.dart';

class BoardRequestProvider extends ChangeNotifier {
  final BoardRequestService _service = BoardRequestService();

  List<BoardRequest> _pendingRequests = [];
  List<BoardRequest> _userRequests = [];
  List<BoardRequest> _invitations = [];
  List<BoardRequest> _joinRequests = [];

  bool _isLoading = false;

  List<BoardRequest> get pendingRequests => _pendingRequests;
  List<BoardRequest> get userRequests => _userRequests;
  List<BoardRequest> get invitations => _invitations;
  List<BoardRequest> get joinRequests => _joinRequests;
  bool get isLoading => _isLoading;

  // ========================
  // STREAM REQUESTS
  // ========================

  /// Stream pending requests for a board (for managers) - all types
  void streamPendingRequestsForBoard(String boardId) {
    _service
        .streamPendingRequestsForBoard(boardId)
        .listen(
          (requests) {
            _pendingRequests = requests;
            notifyListeners();
          },
          onError: (error) {
            print(
              '[BoardRequestProvider] ERROR streaming pending requests: $error',
            );
          },
        );
  }

  /// Stream pending invitations for a board (manager inviting users)
  void streamPendingInvitationsForBoard(String boardId) {
    _service
        .streamPendingInvitationsForBoard(boardId)
        .listen(
          (requests) {
            _invitations = requests;
            notifyListeners();
          },
          onError: (error) {
            print('[BoardRequestProvider] ERROR streaming invitations: $error');
          },
        );
  }

  /// Stream pending join requests for a board (users requesting to join)
  void streamPendingJoinRequestsForBoard(String boardId) {
    _service
        .streamPendingJoinRequestsForBoard(boardId)
        .listen(
          (requests) {
            _joinRequests = requests;
            notifyListeners();
          },
          onError: (error) {
            print('[BoardRequestProvider] ERROR streaming join requests: $error');
          },
        );
  }

  /// Stream invitations received by a user
  void streamInvitationsByUser(String userId) {
    _service
        .streamInvitationsByUser(userId)
        .listen(
          (requests) {
            _invitations = requests;
            notifyListeners();
          },
          onError: (error) {
            print('[BoardRequestProvider] ERROR streaming user invitations: $error');
          },
        );
  }

  /// Stream join requests made by a user
  void streamJoinRequestsByUser(String userId) {
    _service
        .streamJoinRequestsByUser(userId)
        .listen(
          (requests) {
            _joinRequests = requests;
            notifyListeners();
          },
          onError: (error) {
            print('[BoardRequestProvider] ERROR streaming user join requests: $error');
          },
        );
  }

  /// Stream requests by user (for users to track their own requests)
  void streamRequestsByUser(String userId) {
    print('[BoardRequestProvider] Streaming requests for user: $userId');
    _service
        .streamRequestsByUser(userId)
        .listen(
          (requests) {
            print(
              '[BoardRequestProvider] Received ${requests.length} requests',
            );
            _userRequests = requests;
            notifyListeners();
          },
          onError: (error) {
            print(
              '[BoardRequestProvider] ERROR streaming requests: $error',
            );
          },
        );
  }

  // ========================
  // CREATE REQUEST
  // ========================

  /// Create an invitation (manager inviting a user to join)
  Future<void> createInvitation({
    required String boardId,
    required String boardTitle,
    required String userId,
    String? message,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.createInvitation(
        boardId: boardId,
        boardTitle: boardTitle,
        userId: userId,
        message: message,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a join request (user requesting to join a public board)
  Future<void> createJoinRequest({
    required String boardId,
    required String boardTitle,
    String? message,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.createJoinRequest(
        boardId: boardId,
        boardTitle: boardTitle,
        message: message,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Legacy method for backward compatibility - creates an invitation
  @Deprecated('Use createInvitation instead')
  Future<void> createJoinRequestLegacy({
    required String boardId,
    required String boardTitle,
    required String userId,
    String? message,
  }) async {
    await createInvitation(
      boardId: boardId,
      boardTitle: boardTitle,
      userId: userId,
      message: message,
    );
  }

  // ========================
  // UPDATE REQUEST
  // ========================

  /// Approve a join request
  Future<void> approveRequest(
    BoardRequest request, {
    String? responseMessage,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.approveRequest(request, responseMessage: responseMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reject a join request
  Future<void> rejectRequest(
    BoardRequest request, {
    String? responseMessage,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.rejectRequest(request, responseMessage: responseMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cancel a pending request (by the requester)
  Future<void> cancelRequest(String requestId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.cancelRequest(requestId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ========================
  // CHECK REQUEST
  // ========================

  /// Check if user has pending request for a board
  Future<bool> hasPendingRequest(String boardId, String userId) async {
    return await _service.hasPendingRequest(boardId, userId);
  }
}
