class BoardStats {
  final int boardTasksCount;
  final int boardTasksDoneCount;
  final int boardTasksDeletedCount;

  final int boardStepsCount;
  final int boardStepsDoneCount;
  final int boardStepsDeletedCount;

  final int boardMessageCount;

  BoardStats({
    this.boardTasksCount = 0,
    this.boardTasksDoneCount = 0,
    this.boardTasksDeletedCount = 0,
    this.boardStepsCount = 0,
    this.boardStepsDoneCount = 0,
    this.boardStepsDeletedCount = 0,
    this.boardMessageCount = 0,
  });

  factory BoardStats.fromMap(Map<String, dynamic> data) {
    return BoardStats(
      boardTasksCount: data['boardTasksCount'] ?? 0,
      boardTasksDoneCount: data['boardTasksDoneCount'] ?? 0,
      boardTasksDeletedCount: data['boardTasksDeletedCount'] ?? 0,
      boardStepsCount: data['boardStepsCount'] ?? 0,
      boardStepsDoneCount: data['boardStepsDoneCount'] ?? 0,
      boardStepsDeletedCount: data['boardStepsDeletedCount'] ?? 0,
      boardMessageCount: data['boardMessageCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'boardTasksCount': boardTasksCount,
      'boardTasksDoneCount': boardTasksDoneCount,
      'boardTasksDeletedCount': boardTasksDeletedCount,
      'boardStepsCount': boardStepsCount,
      'boardStepsDoneCount': boardStepsDoneCount,
      'boardStepsDeletedCount': boardStepsDeletedCount,
      'boardMessageCount': boardMessageCount,
    };
  }

  BoardStats copyWith({
    int? boardTasksCount,
    int? boardTasksDoneCount,
    int? boardTasksDeletedCount,
    int? boardStepsCount,
    int? boardStepsDoneCount,
    int? boardStepsDeletedCount,
    int? boardMessageCount,
  }) {
    return BoardStats(
      boardTasksCount: boardTasksCount ?? this.boardTasksCount,
      boardTasksDoneCount: boardTasksDoneCount ?? this.boardTasksDoneCount,
      boardTasksDeletedCount:
          boardTasksDeletedCount ?? this.boardTasksDeletedCount,
      boardStepsCount: boardStepsCount ?? this.boardStepsCount,
      boardStepsDoneCount:
          boardStepsDoneCount ?? this.boardStepsDoneCount,
      boardStepsDeletedCount:
          boardStepsDeletedCount ?? this.boardStepsDeletedCount,
      boardMessageCount: boardMessageCount ?? this.boardMessageCount,
    );
  }
}

