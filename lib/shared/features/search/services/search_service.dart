import 'package:cloud_firestore/cloud_firestore.dart';
import '../../users/datasources/models/user_model.dart';
import '../../../../features/boards/datasources/models/board_model.dart';
import '../../../../features/tasks/datasources/models/task_model.dart';

class SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ========================
  // USER SEARCH
  // ========================

  /// Stream all discoverable users in real-time
  /// Returns users who have public profiles (userIsPublic = true) or allow search (userAllowSearch = true)
  Stream<List<UserModel>> streamDiscoverableUsers() {
    // First, get public users
    final publicUsersStream = _firestore
        .collection('users')
        .where('userIsPublic', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final users =
              snapshot.docs
                  .map((doc) => UserModel.fromMap(doc.data(), doc.id))
                  .where((user) => user.userIsActive && !user.userIsBanned)
                  .toList();

          print('[SearchService] Streaming ${users.length} public users');
          return users;
        });

    return publicUsersStream;
  }

  /// Search users by name, handle, or skills
  /// Returns users who allow search (userAllowSearch = true) or have public profiles (userIsPublic = true)
  /// If query is empty, returns all discoverable users
  Future<List<UserModel>> searchUsers(String query) async {
    final lowerQuery = query.toLowerCase().trim();

    try {
      // Get all active, non-banned users
      final snapshot =
          await _firestore
              .collection('users')
              .where('userIsActive', isEqualTo: true)
              .where('userIsBanned', isEqualTo: false)
              .get();

      // Filter results by search permissions and query match
      final results =
          snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data(), doc.id))
              .where((user) {
                // Only include users who allow search OR have public profiles
                if (!user.userAllowSearch && !user.userIsPublic) return false;

                // If no query, include all discoverable users
                if (lowerQuery.isEmpty) return true;

                // Otherwise, filter by query match
                final nameMatch = user.userName.toLowerCase().contains(
                  lowerQuery,
                );
                final handleMatch = user.userHandle.toLowerCase().contains(
                  lowerQuery,
                );
                final skillsMatch = user.userSkills.any(
                  (skill) => skill.toLowerCase().contains(lowerQuery),
                );
                return nameMatch || handleMatch || skillsMatch;
              })
              .toList();

      return results;
    } catch (e) {
      print('[SearchService] Error searching users: $e');
      return [];
    }
  }

  // ========================
  // BOARD SEARCH
  // ========================

  /// Search public boards that users can discover and join
  Future<List<Board>> searchPublicBoards(
    String query, {
    String? currentUserId,
  }) async {
    try {
      // Get all public boards
      final snapshot =
          await _firestore
              .collection('boards')
              .where('boardIsPublic', isEqualTo: true)
              .where('boardIsDeleted', isEqualTo: false)
              .get();

      final lowerQuery = query.toLowerCase().trim();

      // Filter by query and exclude boards user is already in
      final results =
          snapshot.docs.map((doc) => Board.fromMap(doc.data(), doc.id)).where((
            board,
          ) {
            // Exclude boards where user is already manager or member
            if (currentUserId != null) {
              if (board.boardManagerId == currentUserId ||
                  board.memberIds.contains(currentUserId)) {
                return false;
              }
            }

            // Filter by query
            if (lowerQuery.isEmpty) return true;

            final titleMatch = board.boardTitle.toLowerCase().contains(
              lowerQuery,
            );
            final goalMatch = board.boardGoal.toLowerCase().contains(
              lowerQuery,
            );
            final descMatch =
                board.boardDescription?.toLowerCase().contains(lowerQuery) ??
                false;

            return titleMatch || goalMatch || descMatch;
          }).toList();

      // Sort by creation date (newest first)
      results.sort((a, b) => b.boardCreatedAt.compareTo(a.boardCreatedAt));

      return results;
    } catch (e) {
      print('[SearchService] Error searching public boards: $e');
      return [];
    }
  }

  // ========================
  // TASK SEARCH
  // ========================

  /// Search tasks within user's boards (where user is manager or member)
  Future<List<Task>> searchUserTasks(String query, String userId) async {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase().trim();

    try {
      // Get all tasks where user is involved (owner or assigned)
      final snapshot =
          await _firestore
              .collection('tasks')
              .where('taskIsDeleted', isEqualTo: false)
              .get();

      // Filter by query and user access
      final results =
          snapshot.docs.map((doc) => Task.fromMap(doc.data(), doc.id)).where((
            task,
          ) {
            // Check if user has access to this task
            final hasAccess =
                task.taskOwnerId == userId ||
                task.taskAssignedTo == userId ||
                task.taskAssignedBy == userId;

            if (!hasAccess) return false;

            // Filter by query
            final titleMatch = task.taskTitle.toLowerCase().contains(
              lowerQuery,
            );
            final descMatch = task.taskDescription.toLowerCase().contains(
              lowerQuery,
            );
            final boardMatch =
                task.taskBoardTitle?.toLowerCase().contains(lowerQuery) ??
                false;

            return titleMatch || descMatch || boardMatch;
          }).toList();

      // Sort by creation date (newest first)
      results.sort((a, b) => b.taskCreatedAt.compareTo(a.taskCreatedAt));

      return results;
    } catch (e) {
      print('[SearchService] Error searching tasks: $e');
      return [];
    }
  }

  // ========================
  // ADVANCED FILTERS
  // ========================

  /// Filter tasks by priority
  List<Task> filterTasksByPriority(List<Task> tasks, String priority) {
    if (priority.isEmpty) return tasks;
    return tasks.where((task) => task.taskPriorityLevel == priority).toList();
  }

  /// Filter tasks by status
  List<Task> filterTasksByStatus(List<Task> tasks, String status) {
    if (status.isEmpty) return tasks;
    return tasks.where((task) => task.taskStatus == status).toList();
  }

  /// Filter tasks by completion
  List<Task> filterTasksByCompletion(List<Task> tasks, bool? isDone) {
    if (isDone == null) return tasks;
    return tasks.where((task) => task.taskIsDone == isDone).toList();
  }

  /// Filter tasks by deadline (upcoming, overdue, no deadline)
  List<Task> filterTasksByDeadline(List<Task> tasks, String deadlineFilter) {
    final now = DateTime.now();

    switch (deadlineFilter) {
      case 'upcoming':
        return tasks.where((task) {
          return task.taskDeadline != null &&
              task.taskDeadline!.isAfter(now) &&
              !task.taskIsDone;
        }).toList();
      case 'overdue':
        return tasks.where((task) {
          return task.taskDeadline != null &&
              task.taskDeadline!.isBefore(now) &&
              !task.taskIsDone;
        }).toList();
      case 'noDeadline':
        return tasks.where((task) => task.taskDeadline == null).toList();
      default:
        return tasks;
    }
  }

  /// Sort tasks by various criteria
  List<Task> sortTasks(List<Task> tasks, String sortBy) {
    final sortedTasks = List<Task>.from(tasks);

    switch (sortBy) {
      case 'dateNewest':
        sortedTasks.sort((a, b) => b.taskCreatedAt.compareTo(a.taskCreatedAt));
        break;
      case 'dateOldest':
        sortedTasks.sort((a, b) => a.taskCreatedAt.compareTo(b.taskCreatedAt));
        break;
      case 'priority':
        final priorityOrder = {'High': 0, 'Medium': 1, 'Low': 2};
        sortedTasks.sort((a, b) {
          final aPriority = priorityOrder[a.taskPriorityLevel] ?? 3;
          final bPriority = priorityOrder[b.taskPriorityLevel] ?? 3;
          return aPriority.compareTo(bPriority);
        });
        break;
      case 'deadline':
        sortedTasks.sort((a, b) {
          if (a.taskDeadline == null && b.taskDeadline == null) return 0;
          if (a.taskDeadline == null) return 1;
          if (b.taskDeadline == null) return -1;
          return a.taskDeadline!.compareTo(b.taskDeadline!);
        });
        break;
      case 'title':
        sortedTasks.sort((a, b) => a.taskTitle.compareTo(b.taskTitle));
        break;
    }

    return sortedTasks;
  }
}
