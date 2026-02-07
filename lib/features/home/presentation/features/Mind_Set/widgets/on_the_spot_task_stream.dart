import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../../../boards/datasources/models/board_model.dart';
import '../../../../../boards/datasources/providers/board_provider.dart';
import '../../../../../boards/presentation/widgets/cards/board_task_card.dart';
import '../../../../../boards/presentation/widgets/dialogs/add_task_to_board_dialog.dart';
import '../../../../../tasks/datasources/providers/task_provider.dart';

class OnTheSpotTaskStream extends StatefulWidget {
  final String mode;
  final bool isSessionActive;

  const OnTheSpotTaskStream({
    super.key,
    required this.mode,
    required this.isSessionActive,
  });

  @override
  State<OnTheSpotTaskStream> createState() => _OnTheSpotTaskStreamState();
}

class _OnTheSpotTaskStreamState extends State<OnTheSpotTaskStream> {
  Board? _personalBoard;
  bool _isLoadingBoard = true;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePersonalBoard();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_personalBoard == null) {
      final boardProvider = context.read<BoardProvider>();
      final existing = _findPersonalBoard(boardProvider);
      if (existing != null) {
        _setPersonalBoard(existing);
      }
    }
  }

  Board? _findPersonalBoard(BoardProvider boardProvider) {
    try {
      return boardProvider.boards.firstWhere(
        (board) => board.boardTitle.toLowerCase() == 'personal',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensurePersonalBoard() async {
    final boardProvider = context.read<BoardProvider>();
    final existing = _findPersonalBoard(boardProvider);
    if (existing != null) {
      _setPersonalBoard(existing);
      return;
    }

    setState(() {
      _isLoadingBoard = true;
    });

    await boardProvider.addBoard(
      title: 'Personal',
      goal: 'Personal Tasks',
      description: 'Personal tasks created from Mind:Set.',
    );
    await boardProvider.refreshBoards();

    final created = _findPersonalBoard(boardProvider);
    if (created != null) {
      _setPersonalBoard(created);
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingBoard = false;
      });
    }
  }

  void _setPersonalBoard(Board board) {
    if (!mounted) return;
    setState(() {
      _personalBoard = board;
      _isLoadingBoard = false;
    });
    context.read<TaskProvider>().streamTasksByBoard(board.boardId);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingBoard) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_personalBoard == null) {
      return const Center(
        child: Text('Unable to load Personal board.'),
      );
    }

    return Column(
      children: [
        // Tasks Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tasks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: widget.isSessionActive ? _showAddTaskDialog : null,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (!widget.isSessionActive)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Start the session to begin working on tasks.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
        
        // Tasks List
        Expanded(
          child: Consumer<TaskProvider>(
            builder: (context, taskProvider, _) {
              if (taskProvider.isLoading && taskProvider.tasks.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final tasks = taskProvider.tasks;
              if (tasks.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Text(
                      'No tasks yet. Tap the + button to create one!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return BoardTaskCard(
                    task: task,
                    board: _personalBoard,
                    currentUserId: _currentUserId,
                    showCheckbox: true,
                    isDisabled: !widget.isSessionActive,
                    onToggleDone: widget.isSessionActive
                        ? (isDone) {
                            final provider = context.read<TaskProvider>();
                            provider.toggleTaskDone(
                              task.copyWith(
                                taskIsDone: isDone ?? false,
                                taskStatus:
                                    (isDone ?? false) ? 'COMPLETED' : 'To Do',
                              ),
                            );
                          }
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddTaskDialog() {
    if (_personalBoard == null) return;
    showDialog(
      context: context,
      builder: (context) => AddTaskToBoardDialog(
        userId: _currentUserId,
        board: _personalBoard!,
      ),
    );
  }
}
