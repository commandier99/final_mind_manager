class BoardStats {
  final int boardTasksCount;
  final int boardTasksDoneCount;
  final int boardTasksDeletedCount;

  final int boardSubtasksCount;
  final int boardSubtasksDoneCount;
  final int boardSubtasksDeletedCount;

  final int boardMessageCount;

  BoardStats({
    this.boardTasksCount = 0,
    this.boardTasksDoneCount = 0,
    this.boardTasksDeletedCount = 0,
    this.boardSubtasksCount = 0,
    this.boardSubtasksDoneCount = 0,
    this.boardSubtasksDeletedCount = 0,
    this.boardMessageCount = 0,
  });

  factory BoardStats.fromMap(Map<String, dynamic> data) {
    return BoardStats(
      boardTasksCount: data['boardTasksCount'] ?? 0,
      boardTasksDoneCount: data['boardTasksDoneCount'] ?? 0,
      boardTasksDeletedCount: data['boardTasksDeletedCount'] ?? 0,
      boardSubtasksCount: data['boardSubtasksCount'] ?? 0,
      boardSubtasksDoneCount: data['boardSubtasksDoneCount'] ?? 0,
      boardSubtasksDeletedCount: data['boardSubtasksDeletedCount'] ?? 0,
      boardMessageCount: data['boardMessageCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'boardTasksCount': boardTasksCount,
      'boardTasksDoneCount': boardTasksDoneCount,
      'boardTasksDeletedCount': boardTasksDeletedCount,
      'boardSubtasksCount': boardSubtasksCount,
      'boardSubtasksDoneCount': boardSubtasksDoneCount,
      'boardSubtasksDeletedCount': boardSubtasksDeletedCount,
      'boardMessageCount': boardMessageCount,
    };
  }

  BoardStats copyWith({
    int? boardTasksCount,
    int? boardTasksDoneCount,
    int? boardTasksDeletedCount,
    int? boardSubtasksCount,
    int? boardSubtasksDoneCount,
    int? boardSubtasksDeletedCount,
    int? boardMessageCount,
  }) {
    return BoardStats(
      boardTasksCount: boardTasksCount ?? this.boardTasksCount,
      boardTasksDoneCount: boardTasksDoneCount ?? this.boardTasksDoneCount,
      boardTasksDeletedCount:
          boardTasksDeletedCount ?? this.boardTasksDeletedCount,
      boardSubtasksCount: boardSubtasksCount ?? this.boardSubtasksCount,
      boardSubtasksDoneCount:
          boardSubtasksDoneCount ?? this.boardSubtasksDoneCount,
      boardSubtasksDeletedCount:
          boardSubtasksDeletedCount ?? this.boardSubtasksDeletedCount,
      boardMessageCount: boardMessageCount ?? this.boardMessageCount,
    );
  }
}
