import 'package:flutter/material.dart';
import '../models/board_join_request_model.dart';
import '../services/board_join_request_services.dart';

class BoardJoinRequestProvider extends ChangeNotifier {
  final BoardJoinRequestService _service = BoardJoinRequestService();

  List<BoardJoinRequest> _pendingRequests = [];
  List<BoardJoinRequest> _userRequests = [];

  bool _isLoading = false;

  List<BoardJoinRequest> get pendingRequests => _pendingRequests;
  List<BoardJoinRequest> get userRequests => _userRequests;
  bool get isLoading => _isLoading;

  // ========================
  // STREAM REQUESTS
  // ========================

  /// Stream pending requests for a board (for managers)
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
              '[BoardJoinRequestProvider] ERROR streaming pending requests: $error',
            );
          },
        );
  }

  /// Stream requests by user (for users to track their own requests)
  void streamRequestsByUser(String userId) {
    print('[BoardJoinRequestProvider] Streaming requests for user: $userId');
    _service
        .streamRequestsByUser(userId)
        .listen(
          (requests) {
            print(
              '[BoardJoinRequestProvider] Received ${requests.length} requests',
            );
            _userRequests = requests;
            notifyListeners();
          },
          onError: (error) {
            print(
              '[BoardJoinRequestProvider] ERROR streaming requests: $error',
            );
          },
        );
  }

  // ========================
  // CREATE REQUEST
  // ========================

  /// Create a board join request (for board invitation/recruitment)
  Future<void> createJoinRequest({
    required String boardId,
    required String boardTitle,
    required String userId,
    String? message,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _service.createJoinRequest(
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

  // ========================
  // UPDATE REQUEST
  // ========================

  /// Approve a join request
  Future<void> approveRequest(
    BoardJoinRequest request, {
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
    BoardJoinRequest request, {
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
