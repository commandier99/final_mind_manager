class UserStatsModel {
  final String userId;

  // Boards
  final int userBoardsCreatedCount;
  final int userBoardsDeletedCount;

  // Tasks
  final int userTasksCreatedCount;
  final int userTasksCompletedCount;
  final int userTasksDeletedCount;

  // Steps
  final int userStepsCreatedCount;
  final int userStepsCompletedCount;
  final int userStepsDeletedCount;

  // Time
  final int userTimeOnTasksMinutes; // focus / work time

  const UserStatsModel({
    required this.userId,
    this.userBoardsCreatedCount = 0,
    this.userBoardsDeletedCount = 0,
    this.userTasksCreatedCount = 0,
    this.userTasksCompletedCount = 0,
    this.userTasksDeletedCount = 0,
    this.userStepsCreatedCount = 0,
    this.userStepsCompletedCount = 0,
    this.userStepsDeletedCount = 0,
    this.userTimeOnTasksMinutes = 0,
  });

  UserStatsModel copyWith({
    int? userBoardsCreatedCount,
    int? userBoardsDeletedCount,
    int? userTasksCreatedCount,
    int? userTasksCompletedCount,
    int? userTasksDeletedCount,
    int? userStepsCreatedCount,
    int? userStepsCompletedCount,
    int? userStepsDeletedCount,
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
      userStepsCreatedCount:
          userStepsCreatedCount ?? this.userStepsCreatedCount,
      userStepsCompletedCount:
          userStepsCompletedCount ?? this.userStepsCompletedCount,
      userStepsDeletedCount:
          userStepsDeletedCount ?? this.userStepsDeletedCount,
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
      userStepsCreatedCount: map['userStepsCreatedCount'] ?? 0,
      userStepsCompletedCount: map['userStepsCompletedCount'] ?? 0,
      userStepsDeletedCount: map['userStepsDeletedCount'] ?? 0,
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
      'userStepsCreatedCount': userStepsCreatedCount,
      'userStepsCompletedCount': userStepsCompletedCount,
      'userStepsDeletedCount': userStepsDeletedCount,
      'userTimeOnTasksMinutes': userTimeOnTasksMinutes,
    };
  }
}

