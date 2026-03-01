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
  final EdgeInsetsGeometry contentPadding;
  final bool allowCompletionToggle;

  const TaskSubtasksList({
    super.key,
    required this.parentTaskId,
    this.boardId,
    this.task,
    this.contentPadding = const EdgeInsets.all(16.0),
    this.allowCompletionToggle = false,
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
      padding: widget.contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and add icon
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              const SizedBox(width: 8),
              if (canAddSubtask)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    print(
                      '[DEBUG] TaskSubtasksList: Add subtask button pressed',
                    );
                    showDialog(
                      context: context,
                      builder: (dialogContext) => AddSubtaskDialog(
                        parentTaskId: widget.parentTaskId,
                        subtaskBoardId: widget.boardId,
                        subtaskProvider: subtaskProvider,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Icons.add, size: 16, color: Colors.grey[700]),
                  ),
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
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${index + 1}.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                          child: SubtaskCard(
                            subtask: subtask,
                            onToggleDone: widget.allowCompletionToggle
                                ? (value) {
                                    print(
                                      '[DEBUG] TaskSubtasksList: Toggling subtask ${subtask.subtaskId}',
                                    );
                                    subtaskProvider.toggleSubtaskDoneStatus(
                                      subtask,
                                    );
                                  }
                                : null,
                            onDelete: () {
                              print(
                                '[DEBUG] TaskSubtasksList: Deleting subtask ${subtask.subtaskId}',
                              );
                              subtaskProvider.softDeleteSubtask(subtask);
                            },
                          ),
                        ),
                      ],
                    ),
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

    // Task assignee can add subtasks.
    if (widget.task!.taskAssignedTo == currentUserId) return true;

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

    // For personal tasks, fall back to assignee.
    return widget.task!.taskAssignedTo == currentUserId;
  }
}
