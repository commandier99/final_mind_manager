import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/models/board_model.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../datasources/providers/board_provider.dart';
import '../../controllers/board_task_operations_controller.dart';

class BoardDeleteFlowDialog {
  static final BoardTaskOperationsController _operationsController =
      BoardTaskOperationsController();

  static Future<void> show(BuildContext context, {required Board board}) async {
    final currentUserId = context.read<UserProvider>().userId;
    if (currentUserId == null || currentUserId != board.boardManagerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the board manager can delete this board.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final taskProvider = context.read<TaskProvider>();
    final boardProvider = context.read<BoardProvider>();
    final boardTasks = _operationsController.tasksForBoard(
      tasks: taskProvider.tasks,
      boardId: board.boardId,
    );

    if (boardTasks.isEmpty) {
      await _confirmDeleteBoardOnly(
        context,
        board: board,
        boardProvider: boardProvider,
      );
      return;
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Board with Tasks'),
        content: Text(
          'This board has ${boardTasks.length} task(s) and ${board.memberIds.length} member(s).\n\n'
          'Choose whether to migrate tasks first or delete the board and all its tasks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showMigrationDialog(
                context,
                fromBoard: board,
                tasksToMigrate: boardTasks,
              );
            },
            child: const Text('Migrate Tasks'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteBoardAndTasks(
                context,
                board: board,
                tasksToDelete: boardTasks,
              );
            },
            child: const Text(
              'Delete All',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _confirmDeleteBoardOnly(
    BuildContext context, {
    required Board board,
    required BoardProvider boardProvider,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Board'),
        content: Text(
          'Delete "${board.boardTitle}"?\n\n'
          'Members will lose access to this board. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await boardProvider.softDeleteBoard(board);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Board "${board.boardTitle}" deleted'),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting board: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  static Future<void> _showMigrationDialog(
    BuildContext context, {
    required Board fromBoard,
    required List<Task> tasksToMigrate,
  }) async {
    final boardProvider = context.read<BoardProvider>();
    final otherBoards = _operationsController.availableMigrationTargets(
      boards: boardProvider.boards,
      sourceBoardId: fromBoard.boardId,
    );

    if (otherBoards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other boards available to migrate tasks to'),
        ),
      );
      return;
    }

    Board? selectedBoard;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Destination Board'),
        content: StatefulBuilder(
          builder: (context, setState) => DropdownButton<Board>(
            isExpanded: true,
            hint: const Text('Choose a board'),
            value: selectedBoard,
            items: otherBoards.map((board) {
              return DropdownMenuItem<Board>(
                value: board,
                child: Text(board.boardTitle),
              );
            }).toList(),
            onChanged: (board) {
              setState(() {
                selectedBoard = board;
              });
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: selectedBoard == null
                ? null
                : () async {
                    Navigator.pop(context);
                    await _performMigration(
                      context,
                      fromBoard: fromBoard,
                      toBoard: selectedBoard!,
                      tasksToMigrate: tasksToMigrate,
                    );
                  },
            child: const Text('Migrate'),
          ),
        ],
      ),
    );
  }

  static Future<void> _performMigration(
    BuildContext context, {
    required Board fromBoard,
    required Board toBoard,
    required List<Task> tasksToMigrate,
  }) async {
    final taskProvider = context.read<TaskProvider>();
    final boardProvider = context.read<BoardProvider>();

    try {
      await _operationsController.migrateTasksAndDeleteBoard(
        fromBoard: fromBoard,
        toBoard: toBoard,
        tasksToMigrate: tasksToMigrate,
        taskProvider: taskProvider,
        boardProvider: boardProvider,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tasksToMigrate.length} task(s) migrated to ${toBoard.boardTitle}',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error migrating tasks: $e')));
    }
  }

  static Future<void> _confirmDeleteBoardAndTasks(
    BuildContext context, {
    required Board board,
    required List<Task> tasksToDelete,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to delete "${board.boardTitle}", '
          '${tasksToDelete.length} task(s), and remove access for '
          '${board.memberIds.length} member(s)?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteTasksAndBoard(
                context,
                board: board,
                tasksToDelete: tasksToDelete,
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  static Future<void> _deleteTasksAndBoard(
    BuildContext context, {
    required Board board,
    required List<Task> tasksToDelete,
  }) async {
    final taskProvider = context.read<TaskProvider>();
    final boardProvider = context.read<BoardProvider>();

    try {
      await _operationsController.deleteBoardAndTasks(
        board: board,
        tasksToDelete: tasksToDelete,
        taskProvider: taskProvider,
        boardProvider: boardProvider,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Board and ${tasksToDelete.length} task(s) deleted'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting board: $e')));
    }
  }
}
