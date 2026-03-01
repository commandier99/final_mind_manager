import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/board_model.dart';
import '../models/board_roles.dart';
import '../models/board_stats_model.dart';
import '../../../../shared/features/users/datasources/services/activity_event_services.dart';
import 'package:flutter/foundation.dart';

class BoardService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _boardCollection = FirebaseFirestore.instance
      .collection('boards');
  final ActivityEventService _activityEventService = ActivityEventService();
  static String _personalBoardDocId(String userId) => 'personal_$userId';

  String? get currentUserId => _auth.currentUser?.uid;

  Future<Board?> _findPersonalBoardForUser(String userId) async {
    final personalByTypeSnapshot = await _boardCollection
        .where('boardManagerId', isEqualTo: userId)
        .where('boardIsDeleted', isEqualTo: false)
        .where('boardType', isEqualTo: 'personal')
        .limit(1)
        .get();

    if (personalByTypeSnapshot.docs.isNotEmpty) {
      final doc = personalByTypeSnapshot.docs.first;
      return Board.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }

    // Legacy fallback for older records that may not have boardType set.
    final legacyPersonalSnapshot = await _boardCollection
        .where('boardManagerId', isEqualTo: userId)
        .where('boardIsDeleted', isEqualTo: false)
        .where('boardTitle', isEqualTo: 'Personal')
        .limit(1)
        .get();

    if (legacyPersonalSnapshot.docs.isNotEmpty) {
      final doc = legacyPersonalSnapshot.docs.first;
      return Board.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }

    return null;
  }

  Future<Board> ensurePersonalBoardForCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not signed in");

    final existing = await _findPersonalBoardForUser(user.uid);
    if (existing != null) return existing;
    final now = DateTime.now();
    final personalRef = _boardCollection.doc(_personalBoardDocId(user.uid));

    final personalBoard = Board(
      boardId: personalRef.id,
      boardManagerId: user.uid,
      boardManagerName: user.displayName ?? 'Unknown',
      boardCreatedAt: now,
      boardTitle: 'Personal',
      boardGoal: 'Personal tasks and projects',
      boardGoalDescription: 'A space to manage your personal tasks and projects',
      stats: BoardStats(),
      memberIds: [user.uid],
      boardDeletedAt: null,
      boardIsDeleted: false,
      boardIsPublic: false,
      boardRequiresApproval: true,
      boardDescription: null,
      boardMemberLimit: 0,
      boardType: 'personal',
      boardPurpose: 'category',
      memberRoles: {user.uid: BoardRoles.manager},
      memberTaskLimits: {},
      boardTaskCapacity: Board.defaultMemberTaskLimit,
      boardLastModifiedAt: now,
      boardLastModifiedBy: user.uid,
    );

    // Deterministic ID prevents duplicate Personal boards during concurrent calls.
    await personalRef.set(personalBoard.toMap(), SetOptions(merge: true));

    final created = await _findPersonalBoardForUser(user.uid);
    if (created != null) return created;
    throw Exception('Failed to provision Personal board for user ${user.uid}');
  }

  // ------------------------
  // CREATE
  // ------------------------
  Future<void> addBoard({
    String? boardTitle,
    String? boardGoal,
    String? boardGoalDescription,
    String? boardType,
    String? boardPurpose,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not signed in");

    final boardRef = _boardCollection.doc();
    final now = DateTime.now();

    debugPrint(
      '[DEBUG] BoardService: Creating new board with ID = ${boardRef.id}',
    );
    debugPrint('[DEBUG] BoardService: Title = $boardTitle');

    final newBoard = Board(
      boardId: boardRef.id,
      boardManagerId: user.uid,
      boardManagerName: user.displayName ?? 'Unknown',
      boardCreatedAt: now,
      boardTitle: boardTitle?.isNotEmpty == true
          ? boardTitle!
          : 'Untitled Board',
      boardGoal: boardGoal?.isNotEmpty == true ? boardGoal! : 'No goal set',
      boardGoalDescription: boardGoalDescription?.isNotEmpty == true
          ? boardGoalDescription!
          : 'No description',
      stats: BoardStats(),
      memberIds: [user.uid],
      boardDeletedAt: null,
      boardIsDeleted: false,
      boardIsPublic: false,
      boardRequiresApproval: true,
      boardDescription: null,
      boardMemberLimit: 0,
      boardType: boardType ?? 'team', // Default to team
      boardPurpose: boardPurpose ?? 'project',
      memberRoles: {user.uid: BoardRoles.manager},
      memberTaskLimits: {},
      boardTaskCapacity: Board.defaultMemberTaskLimit,
      boardLastModifiedAt: now,
      boardLastModifiedBy: user.uid,
    );

    await boardRef.set(newBoard.toMap());

    // Log activity event
    await _activityEventService.logEvent(
      userId: user.uid,
      userName: user.displayName ?? 'Unknown User',
      activityType: 'board_created',
      userProfilePicture: user.photoURL,
      boardId: boardRef.id,
      description: 'created a board',
      metadata: {'boardName': newBoard.boardTitle},
    );
  }

  // ------------------------
  // READ / STREAM
  // ------------------------
  Stream<List<Board>> streamBoardsForCurrentUser() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Stream.empty();

    // Boards where user is a manager
    final managerQuery = _boardCollection
        .where('boardManagerId', isEqualTo: userId)
        .where('boardIsDeleted', isEqualTo: false)
        .orderBy('boardCreatedAt', descending: true)
        .snapshots()
        .map(_mapBoardSnapshot);

    // Boards where user is a member
    final memberQuery = _boardCollection
        .where('memberIds', arrayContains: userId)
        .where('boardIsDeleted', isEqualTo: false)
        .orderBy('boardCreatedAt', descending: true)
        .snapshots()
        .map(_mapBoardSnapshot);

    // Combine both streams and remove duplicates
    return StreamZip([managerQuery, memberQuery]).map((lists) {
      final combined = [...lists[0], ...lists[1]];
      // Remove duplicates by boardId
      final uniqueBoards = <String, Board>{};
      for (var board in combined) {
        uniqueBoards[board.boardId] = board;
      }
      return uniqueBoards.values.toList();
    });
  }

  Future<List<Board>> getBoardsForCurrentUser() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    // Get boards where user is manager
    final managerSnapshot = await _boardCollection
        .where('boardManagerId', isEqualTo: userId)
        .where('boardIsDeleted', isEqualTo: false)
        .get();

    // Get boards where user is a member
    final memberSnapshot = await _boardCollection
        .where('memberIds', arrayContains: userId)
        .where('boardIsDeleted', isEqualTo: false)
        .get();

    final allBoards = [...managerSnapshot.docs, ...memberSnapshot.docs];

    // Remove duplicates by boardId
    final uniqueBoards = <String, Board>{};
    for (var doc in allBoards) {
      final board = Board.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      uniqueBoards[board.boardId] = board;
    }

    return uniqueBoards.values.toList();
  }

  Stream<Board?> streamBoardById(String boardId) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Stream.empty();

    final boardRef = _boardCollection.doc(boardId);

    return boardRef.snapshots().asyncMap((snapshot) async {
      if (!snapshot.exists) return null;

      final board = Board.fromMap(
        snapshot.data() as Map<String, dynamic>,
        snapshot.id,
      );

      // Check if current user is manager or member
      if (board.boardManagerId != userId && !board.memberIds.contains(userId)) {
        return null; // No access
      }

      return board;
    });
  }

  Future<Board?> getBoardById(String boardId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    final doc = await _boardCollection.doc(boardId).get();
    if (!doc.exists) return null;

    final board = Board.fromMap(doc.data() as Map<String, dynamic>, doc.id);

    // Only allow if current user is manager or member
    if (board.boardManagerId != userId && !board.memberIds.contains(userId)) {
      return null;
    }

    return board;
  }

  // ------------------------
  // UPDATE
  // ------------------------
  Future<void> updateBoard(
    String boardId, {
    String? newTitle,
    String? newGoal,
    String? newGoalDescription,
    BoardStats? newStats,
    Map<String, String>? memberRoles,
    int? boardTaskCapacity,
  }) async {
    final updateData = <String, dynamic>{};

    if (newTitle != null) updateData['boardTitle'] = newTitle;
    if (newGoal != null) updateData['boardGoal'] = newGoal;
    if (newGoalDescription != null) {
      updateData['boardGoalDescription'] = newGoalDescription;
    }
    if (newStats != null) updateData['stats'] = newStats.toMap();
    if (memberRoles != null) updateData['memberRoles'] = memberRoles;
    if (boardTaskCapacity != null) {
      updateData['boardTaskCapacity'] = boardTaskCapacity;
    }

    if (updateData.isNotEmpty) {
      updateData['boardLastModifiedAt'] = FieldValue.serverTimestamp();
      updateData['boardLastModifiedBy'] = _auth.currentUser?.uid ?? '';

      await _boardCollection.doc(boardId).update(updateData);
    }
  }

  // ------------------------
  // MEMBERS MANAGEMENT
  // ------------------------
  Future<void> addMemberToBoard({
    required String boardId,
    required String userId,
    String role = BoardRoles.member, // Assignable roles: member/supervisor
  }) async {
    final boardRef = _boardCollection.doc(boardId);

    // Get current board data to update roles
    final boardDoc = await boardRef.get();
    final data = boardDoc.data() as Map<String, dynamic>?;
    final boardType = (data?['boardType'] as String? ?? 'team').toLowerCase();
    final canAcceptMembers = boardType == 'team';
    if (!canAcceptMembers) {
      throw Exception(
        'Only Team boards can add members. Change this board type to Team first.',
      );
    }

    final normalizedRole = BoardRoles.normalize(role);
    if (!BoardRoles.isAssignable(normalizedRole)) {
      throw Exception(
        'Invalid role: $role. Allowed roles are member or supervisor.',
      );
    }

    final currentRoles = Map<String, String>.from(data?['memberRoles'] ?? {});
    currentRoles[userId] = normalizedRole;

    await boardRef.update({
      'memberIds': FieldValue.arrayUnion([userId]),
      'memberRoles': currentRoles,
    });

    // Log user activity event
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _activityEventService.logEvent(
          userId: user.uid,
          userName: user.displayName ?? 'Unknown User',
          activityType: 'member_joined',
          userProfilePicture: user.photoURL,
          boardId: boardId,
          description: 'joined a board',
          metadata: {'boardId': boardId},
        );
      } catch (e) {
        debugPrint('[ERROR] Failed to log member joined event: $e');
      }
    }
  }

  Future<void> removeMemberFromBoard({
    required String boardId,
    required String userId,
  }) async {
    final boardRef = _boardCollection.doc(boardId);

    // Get current board data to remove role
    final boardDoc = await boardRef.get();
    final data = boardDoc.data() as Map<String, dynamic>?;
    final currentRoles = Map<String, String>.from(data?['memberRoles'] ?? {});
    currentRoles.remove(userId);

    await boardRef.update({
      'memberIds': FieldValue.arrayRemove([userId]),
      'memberRoles': currentRoles,
    });

    // Log activity event
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _activityEventService.logEvent(
          userId: user.uid,
          userName: user.displayName ?? 'Unknown User',
          activityType: 'member_removed',
          userProfilePicture: user.photoURL,
          boardId: boardId,
          description: 'removed a member from the board',
          metadata: {'boardId': boardId},
        );
      } catch (e) {
        debugPrint('[ERROR] Failed to log member removed event: $e');
      }
    }
  }

  /// Member voluntarily leaves the board
  Future<void> leaveBoard({required String boardId}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception("User not signed in");

    final boardRef = _boardCollection.doc(boardId);
    final boardDoc = await boardRef.get();

    if (!boardDoc.exists) throw Exception("Board not found");

    final data = boardDoc.data() as Map<String, dynamic>;
    final boardManagerId = data['boardManagerId'] as String;

    // Manager cannot leave their own board
    if (userId == boardManagerId) {
      throw Exception(
        "Board manager cannot leave the board. Transfer ownership or delete the board instead.",
      );
    }

    // Remove member
    final currentRoles = Map<String, String>.from(data['memberRoles'] ?? {});
    currentRoles.remove(userId);

    await boardRef.update({
      'memberIds': FieldValue.arrayRemove([userId]),
      'memberRoles': currentRoles,
      'boardLastModifiedAt': FieldValue.serverTimestamp(),
      'boardLastModifiedBy': userId,
    });
  }

  /// Board manager kicks a member from the board
  Future<void> kickMember({
    required String boardId,
    required String memberIdToKick,
    String? memberName,
  }) async {
    debugPrint(
      '[DEBUG] BoardService.kickMember called - boardId: $boardId, memberName: $memberName',
    );
    final managerId = _auth.currentUser?.uid;
    if (managerId == null) throw Exception("User not signed in");

    final boardRef = _boardCollection.doc(boardId);
    final boardDoc = await boardRef.get();

    if (!boardDoc.exists) throw Exception("Board not found");

    final data = boardDoc.data() as Map<String, dynamic>;
    final boardManagerId = data['boardManagerId'] as String;

    // Only board manager can kick members
    if (managerId != boardManagerId) {
      throw Exception("Only the board manager can kick members");
    }

    // Cannot kick yourself
    if (memberIdToKick == managerId) {
      throw Exception("You cannot kick yourself from the board");
    }

    // Remove member
    final currentRoles = Map<String, String>.from(data['memberRoles'] ?? {});
    currentRoles.remove(memberIdToKick);

    await boardRef.update({
      'memberIds': FieldValue.arrayRemove([memberIdToKick]),
      'memberRoles': currentRoles,
      'boardLastModifiedAt': FieldValue.serverTimestamp(),
      'boardLastModifiedBy': managerId,
    });
  }

  Future<bool> isMember({required Board board, required String userId}) async {
    return board.memberIds.contains(userId);
  }

  Stream<List<Board>> streamUserBoardsWithMembership(String userId) {
    return _boardCollection
        .where('memberIds', arrayContains: userId)
        .where('boardIsDeleted', isEqualTo: false)
        .snapshots()
        .map(_mapBoardSnapshot);
  }

  Future<List<Board>> getBoardsForUserWithMembership(String userId) async {
    final snapshot = await _boardCollection
        .where('memberIds', arrayContains: userId)
        .where('boardIsDeleted', isEqualTo: false)
        .get();

    return snapshot.docs
        .map((doc) => Board.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  // ------------------------
  // DELETE / SOFT DELETE
  // ------------------------
  Future<void> deleteBoard(String boardId) async {
    await _boardCollection.doc(boardId).delete();
  }

  Future<void> softDeleteBoard(Board board) async {
    debugPrint(
      '[DEBUG] BoardService: soft deleting board ${board.boardId} with title ${board.boardTitle}',
    );
    final user = _auth.currentUser;
    final updatedBoard = board.copyWith(
      boardIsDeleted: true,
      boardDeletedAt: DateTime.now(),
      boardLastModifiedAt: DateTime.now(),
      boardLastModifiedBy: user?.uid,
    );

    await _boardCollection.doc(board.boardId).update(updatedBoard.toMap());
    debugPrint(
      '[DEBUG] BoardService: board ${board.boardId} soft-deleted successfully',
    );
  }

  Future<void> restoreBoard(Board board) async {
    final user = _auth.currentUser;
    final updatedBoard = board.copyWith(
      boardIsDeleted: false,
      boardDeletedAt: null,
      boardLastModifiedAt: DateTime.now(),
      boardLastModifiedBy: user?.uid,
    );

    await _boardCollection.doc(board.boardId).update(updatedBoard.toMap());
  }

  // ------------------------
  // PRIVATE UTIL
  // ------------------------
  List<Board> _mapBoardSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs
        .map((doc) => Board.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
}
