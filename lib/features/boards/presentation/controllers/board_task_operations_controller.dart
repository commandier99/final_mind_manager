import '../../datasources/models/board_model.dart';
import '../../../tasks/datasources/models/task_model.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../datasources/providers/board_provider.dart';

class BoardTaskOperationsController {
  List<Task> tasksForBoard({
    required List<Task> tasks,
    required String boardId,
  }) {
    return tasks.where((task) => task.taskBoardId == boardId).toList();
  }

  List<Board> availableMigrationTargets({
    required List<Board> boards,
    required String sourceBoardId,
  }) {
    return boards
        .where((b) => b.boardId != sourceBoardId && !b.boardIsDeleted)
        .toList();
  }

  Future<void> migrateTasksAndDeleteBoard({
    required Board fromBoard,
    required Board toBoard,
    required List<Task> tasksToMigrate,
    required TaskProvider taskProvider,
    required BoardProvider boardProvider,
  }) async {
    for (final task in tasksToMigrate) {
      final migratedTask = task.copyWith(
        taskBoardId: toBoard.boardId,
        taskBoardTitle: toBoard.boardTitle,
      );
      await taskProvider.updateTask(migratedTask);
    }
    await boardProvider.softDeleteBoard(fromBoard);
  }

  Future<void> deleteBoardAndTasks({
    required Board board,
    required List<Task> tasksToDelete,
    required TaskProvider taskProvider,
    required BoardProvider boardProvider,
  }) async {
    for (final task in tasksToDelete) {
      await taskProvider.deleteTask(task.taskId);
    }
    await boardProvider.softDeleteBoard(board);
  }
}
