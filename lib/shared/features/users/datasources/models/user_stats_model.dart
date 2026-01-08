class UserStatsModel {
  final String userId;

  // Boards
  final int userBoardsCreatedCount;
  final int userBoardsDeletedCount;

  // Tasks
  final int userTasksCreatedCount;
  final int userTasksCompletedCount;
  final int userTasksDeletedCount;

  // Subtasks
  final int userSubtasksCreatedCount;
  final int userSubtasksCompletedCount;
  final int userSubtasksDeletedCount;

  // Time
  final int userTimeOnTasksMinutes; // focus / work time

  const UserStatsModel({
    required this.userId,
    this.userBoardsCreatedCount = 0,
    this.userBoardsDeletedCount = 0,
    this.userTasksCreatedCount = 0,
    this.userTasksCompletedCount = 0,
    this.userTasksDeletedCount = 0,
    this.userSubtasksCreatedCount = 0,
    this.userSubtasksCompletedCount = 0,
    this.userSubtasksDeletedCount = 0,
    this.userTimeOnTasksMinutes = 0,
  });

  UserStatsModel copyWith({
    int? userBoardsCreatedCount,
    int? userBoardsDeletedCount,
    int? userTasksCreatedCount,
    int? userTasksCompletedCount,
    int? userTasksDeletedCount,
    int? userSubtasksCreatedCount,
    int? userSubtasksCompletedCount,
    int? userSubtasksDeletedCount,
    int? userTimeOnTasksMinutes,
  }) {
    return UserStatsModel(
      userId: userId,
      userBoardsCreatedCount:
          userBoardsCreatedCount ?? this.userBoardsCreatedCount,
      userBoardsDeletedCount:
          userBoardsDeletedCount ?? this.userBoardsDeletedCount,
      userTasksCreatedCount:
          userTasksCreatedCount ?? this.userTasksCreatedCount,
      userTasksCompletedCount:
          userTasksCompletedCount ?? this.userTasksCompletedCount,
      userTasksDeletedCount:
          userTasksDeletedCount ?? this.userTasksDeletedCount,
      userSubtasksCreatedCount:
          userSubtasksCreatedCount ?? this.userSubtasksCreatedCount,
      userSubtasksCompletedCount:
          userSubtasksCompletedCount ?? this.userSubtasksCompletedCount,
      userSubtasksDeletedCount:
          userSubtasksDeletedCount ?? this.userSubtasksDeletedCount,
      userTimeOnTasksMinutes:
          userTimeOnTasksMinutes ?? this.userTimeOnTasksMinutes,
    );
  }

  factory UserStatsModel.fromMap(Map<String, dynamic> map, String userId) {
    return UserStatsModel(
      userId: userId,
      userBoardsCreatedCount: map['userBoardsCreatedCount'] ?? 0,
      userBoardsDeletedCount: map['userBoardsDeletedCount'] ?? 0,
      userTasksCreatedCount: map['userTasksCreatedCount'] ?? 0,
      userTasksCompletedCount: map['userTasksCompletedCount'] ?? 0,
      userTasksDeletedCount: map['userTasksDeletedCount'] ?? 0,
      userSubtasksCreatedCount: map['userSubtasksCreatedCount'] ?? 0,
      userSubtasksCompletedCount: map['userSubtasksCompletedCount'] ?? 0,
      userSubtasksDeletedCount: map['userSubtasksDeletedCount'] ?? 0,
      userTimeOnTasksMinutes: map['userTimeOnTasksMinutes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userBoardsCreatedCount': userBoardsCreatedCount,
      'userBoardsDeletedCount': userBoardsDeletedCount,
      'userTasksCreatedCount': userTasksCreatedCount,
      'userTasksCompletedCount': userTasksCompletedCount,
      'userTasksDeletedCount': userTasksDeletedCount,
      'userSubtasksCreatedCount': userSubtasksCreatedCount,
      'userSubtasksCompletedCount': userSubtasksCompletedCount,
      'userSubtasksDeletedCount': userSubtasksDeletedCount,
      'userTimeOnTasksMinutes': userTimeOnTasksMinutes,
    };
  }
}
