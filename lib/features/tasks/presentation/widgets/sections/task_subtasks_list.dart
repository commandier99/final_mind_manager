import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../subtasks/datasources/providers/subtask_provider.dart';
import '../../../../subtasks/presentation/widgets/subtask_card.dart';
import '../../../../subtasks/presentation/widgets/dialogs/add_subtask_dialog.dart';
import '../../../datasources/models/task_model.dart';
import '../../../../boards/datasources/providers/board_provider.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';

class TaskSubtasksList extends StatefulWidget {
  final String parentTaskId;
  final String? boardId;
  final Task? task;

  const TaskSubtasksList({
    super.key,
    required this.parentTaskId,
    this.boardId,
    this.task,
  });

  @override
  State<TaskSubtasksList> createState() => _TaskSubtasksListState();
}

class _TaskSubtasksListState extends State<TaskSubtasksList> {
  @override
  void initState() {
    super.initState();
    print(
      '[DEBUG] TaskSubtasksList: initState called for parentTaskId = ${widget.parentTaskId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    print(
      '[DEBUG] TaskSubtasksList: build called for parentTaskId = ${widget.parentTaskId}',
    );

    final subtaskProvider = context.read<SubtaskProvider>();
    final canAddSubtask = _canAddSubtask();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and add icon
          Row(
            children: [
              Text(
                'Subtasks',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Divider(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              const SizedBox(width: 8),
              if (canAddSubtask)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    print(
                      '[DEBUG] TaskSubtasksList: Add subtask button pressed',
                    );
                    showDialog(
                      context: context,
                      builder:
                          (dialogContext) => AddSubtaskDialog(
                            parentTaskId: widget.parentTaskId,
                            subtaskBoardId: widget.boardId,
                            subtaskProvider: subtaskProvider,
                          ),
                    );
                  },
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Stream of subtasks
          StreamBuilder<List<dynamic>>(
            stream: subtaskProvider.streamSubtasksByTaskId(widget.parentTaskId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                print(
                  '[DEBUG] TaskSubtasksList: Error loading subtasks - ${snapshot.error}',
                );
                return Text('Error: ${snapshot.error}');
              }

              final subtasks = snapshot.data ?? [];

              if (subtasks.isEmpty) {
                print('[DEBUG] TaskSubtasksList: No subtasks found.');
                return const SizedBox.shrink();
              }

              print(
                '[DEBUG] TaskSubtasksList: Building ListView with ${subtasks.length} subtasks.',
              );
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subtasks.length,
                itemBuilder: (context, index) {
                  final subtask = subtasks[index];
                  return SubtaskCard(
                    subtask: subtask,
                    onToggleDone: (value) {
                      print(
                        '[DEBUG] TaskSubtasksList: Toggling subtask ${subtask.subtaskId}',
                      );
                      subtaskProvider.toggleSubtaskDoneStatus(subtask);
                    },
                    onDelete: () {
                      print(
                        '[DEBUG] TaskSubtasksList: Deleting subtask ${subtask.subtaskId}',
                      );
                      subtaskProvider.softDeleteSubtask(subtask);
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  bool _canAddSubtask() {
    // If no task info, allow (personal task)
    if (widget.task == null) return true;

    final userProvider = context.read<UserProvider>();
    final currentUserId = userProvider.userId ?? '';

    // Task owner can add subtasks
    if (widget.task!.taskOwnerId == currentUserId) return true;

    // If it's a board task, check if user is board manager
    if (widget.task!.taskBoardId.isNotEmpty) {
      final boardProvider = context.read<BoardProvider>();
      final board = boardProvider.boards.firstWhere(
        (b) => b.boardId == widget.task!.taskBoardId,
        orElse: () => boardProvider.boards.first,
      );
      if (board.boardManagerId == currentUserId) return true;

      // Board members cannot add subtasks
      return false;
    }

    // For personal tasks, owner can add
    return widget.task!.taskOwnerId == currentUserId;
  }
}
