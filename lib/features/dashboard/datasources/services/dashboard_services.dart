/*import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/features/user/user_stats_model.dart';

class DashboardServices {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get stats for a single user
  Future<UserStatsModel> getUserStats(String userId) async {
    if (userId.isEmpty) {
      throw ArgumentError('userId cannot be empty');
    }

    final doc = await _firestore.collection('user_stats').doc(userId).get();
    if (doc.exists && doc.data() != null) {
      return UserStatsModel.fromMap(doc.data()!, doc.id);
    } else {
      // Return default stats if none exist
      return UserStatsModel(userId: userId);
    }
  }

  /// Stream stats for real-time updates
  Stream<UserStatsModel> streamUserStats(String userId) {
    if (userId.isEmpty) {
      // Return an empty stream that never emits to avoid crashing
      return const Stream.empty();
    }

    return _firestore.collection('user_stats').doc(userId).snapshots().map(
        (snapshot) => snapshot.exists && snapshot.data() != null
            ? UserStatsModel.fromMap(snapshot.data()!, snapshot.id)
            : UserStatsModel(userId: userId));
  }

  /// Optional: aggregate stats across multiple users
  Future<UserStatsModel> calculateGlobalStats() async {
    final querySnapshot = await _firestore.collection('user_stats').get();

    int boardsCreated = 0,
        boardsDeleted = 0,
        tasksCreated = 0,
        tasksCompleted = 0,
        tasksDeleted = 0,
        stepsCreated = 0,
        stepsCompleted = 0,
        stepsDeleted = 0,
        timeOnTasks = 0;

    for (var doc in querySnapshot.docs) {
      final stats = UserStatsModel.fromMap(doc.data(), doc.id);
      boardsCreated += stats.userAmountOfBoardsCreated;
      boardsDeleted += stats.userAmountOfBoardsDeleted;
      tasksCreated += stats.userAmountOfTasksCreated;
      tasksCompleted += stats.userAmountOfTasksCompleted;
      tasksDeleted += stats.userAmountOfTasksDeleted;
      stepsCreated += stats.userAmountOfStepsCreated;
      stepsCompleted += stats.userAmountOfStepsCompleted;
      stepsDeleted += stats.userAmountOfStepsDeleted;
      timeOnTasks += stats.userTimeAmountOnTask;
    }

    return UserStatsModel(
      userId: 'global',
      userAmountOfBoardsCreated: boardsCreated,
      userAmountOfBoardsDeleted: boardsDeleted,
      userAmountOfTasksCreated: tasksCreated,
      userAmountOfTasksCompleted: tasksCompleted,
      userAmountOfTasksDeleted: tasksDeleted,
      userAmountOfStepsCreated: stepsCreated,
      userAmountOfStepsCompleted: stepsCompleted,
      userAmountOfStepsDeleted: stepsDeleted,
      userTimeAmountOnTask: timeOnTasks,
    );
  }
}
*/
