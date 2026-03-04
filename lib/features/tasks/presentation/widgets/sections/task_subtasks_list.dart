import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../subtasks/datasources/providers/subtask_provider.dart';
import '../../../../subtasks/datasources/models/subtask_model.dart';
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
  void _openEditStepDialog(Subtask subtask) {
    final stepController = TextEditingController(text: subtask.subtaskTitle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit step'),
        content: TextField(
          controller: stepController,
          autofocus: true,
          maxLines: 1,
          decoration: const InputDecoration(hintText: 'Step'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final updated = stepController.text.trim();
              if (updated.isEmpty) return;
              final provider = context.read<SubtaskProvider>();
              await provider.updateSubtask(
                subtask.subtaskId,
                subtask.copyWith(subtaskTitle: updated),
              );
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) => stepController.dispose());
  }

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
    final isTaskLocked = widget.task?.taskIsDone == true;
    final canMutateSubtasks = !isTaskLocked;
    final canAddSubtask = canMutateSubtasks && _canAddSubtask();
    void openAddStepDialog() {
      print('[DEBUG] TaskSubtasksList: Add step card tapped');
      showDialog(
        context: context,
        builder: (dialogContext) => AddSubtaskDialog(
          parentTaskId: widget.parentTaskId,
          subtaskBoardId: widget.boardId,
          subtaskProvider: subtaskProvider,
        ),
      );
    }

    return Padding(
      padding: widget.contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                if (!canAddSubtask) return const SizedBox.shrink();
                return _buildAddStepGhostCard(
                  context,
                  onTap: openAddStepDialog,
                );
              }

              print(
                '[DEBUG] TaskSubtasksList: Building ListView with ${subtasks.length} subtasks.',
              );
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: subtasks.length + (canAddSubtask ? 1 : 0),
                itemBuilder: (context, index) {
                  if (canAddSubtask && index == subtasks.length) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6, top: 2),
                      child: _buildAddStepGhostCard(
                        context,
                        onTap: openAddStepDialog,
                      ),
                    );
                  }
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
                            onToggleDone:
                                canMutateSubtasks &&
                                    widget.allowCompletionToggle
                                ? (value) {
                                    print(
                                      '[DEBUG] TaskSubtasksList: Toggling subtask ${subtask.subtaskId}',
                                    );
                                    subtaskProvider.toggleSubtaskDoneStatus(
                                      subtask,
                                    );
                                  }
                                : null,
                            onDelete: canMutateSubtasks
                                ? () {
                                    print(
                                      '[DEBUG] TaskSubtasksList: Deleting subtask ${subtask.subtaskId}',
                                    );
                                    subtaskProvider.softDeleteSubtask(subtask);
                                  }
                                : null,
                            onEdit: canMutateSubtasks && canAddSubtask
                                ? () => _openEditStepDialog(subtask)
                                : null,
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

  Widget _buildAddStepGhostCard(
    BuildContext context, {
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Text(
                  'Add step',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
