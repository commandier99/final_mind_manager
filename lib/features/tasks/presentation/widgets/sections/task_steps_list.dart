import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../steps/datasources/providers/step_provider.dart';
import '../../../../steps/datasources/models/step_model.dart';
import '../../../../steps/presentation/widgets/step_card.dart';
import '../../../datasources/models/task_model.dart';
import '../../../../boards/datasources/providers/board_provider.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';

class TaskStepsList extends StatefulWidget {
  final String parentTaskId;
  final String? boardId;
  final Task? task;
  final EdgeInsetsGeometry contentPadding;
  final bool allowCompletionToggle;

  const TaskStepsList({
    super.key,
    required this.parentTaskId,
    this.boardId,
    this.task,
    this.contentPadding = const EdgeInsets.all(16.0),
    this.allowCompletionToggle = false,
  });

  @override
  State<TaskStepsList> createState() => _TaskStepsListState();
}

class _TaskStepsListState extends State<TaskStepsList> {
  final TextEditingController _newStepController = TextEditingController();
  bool _isAddingStepInline = false;
  bool _isSavingStepInline = false;

  @override
  void initState() {
    super.initState();
    print(
      '[DEBUG] TaskStepsList: initState called for parentTaskId = ${widget.parentTaskId}',
    );
  }

  @override
  void dispose() {
    _newStepController.dispose();
    super.dispose();
  }

  void _openEditStepDialog(TaskStep step) {
    final stepController = TextEditingController(text: step.stepTitle);
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
              final provider = context.read<StepProvider>();
              await provider.updateStep(
                step.stepId,
                step.copyWith(stepTitle: updated),
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
  Widget build(BuildContext context) {
    print(
      '[DEBUG] TaskStepsList: build called for parentTaskId = ${widget.parentTaskId}',
    );

    final stepProvider = context.read<StepProvider>();
    final isTaskLocked = widget.task?.taskIsDone == true;
    final canMutateSteps = !isTaskLocked;
    final canAddStep = canMutateSteps && _canAddStep();

    return Padding(
      padding: widget.contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stream of steps
          StreamBuilder<List<TaskStep>>(
            stream: stepProvider.streamStepsByTaskId(widget.parentTaskId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                print(
                  '[DEBUG] TaskStepsList: Error loading steps - ${snapshot.error}',
                );
                return Text('Error: ${snapshot.error}');
              }

              final steps = snapshot.data ?? <TaskStep>[];

              if (steps.isEmpty) {
                print('[DEBUG] TaskStepsList: No steps found.');
                if (!canAddStep) return const SizedBox.shrink();
                if (_isAddingStepInline) {
                  return _buildInlineStepComposer(
                    context,
                    stepProvider: stepProvider,
                    stepNumber: 1,
                  );
                }
                return _buildAddStepGhostCard(context, onTap: _startInlineAdd);
              }

              print(
                '[DEBUG] TaskStepsList: Building ListView with ${steps.length} steps.',
              );
              return ReorderableListView.builder(
                buildDefaultDragHandles: false,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: steps.length,
                onReorder: canMutateSteps
                    ? (oldIndex, newIndex) async {
                        final maxSortableIndex = steps.length;
                        var normalizedNewIndex = newIndex;
                        if (normalizedNewIndex > maxSortableIndex) {
                          normalizedNewIndex = maxSortableIndex;
                        }

                        // ReorderableListView uses insertion index after removal.
                        if (normalizedNewIndex > oldIndex) {
                          normalizedNewIndex -= 1;
                        }

                        if (normalizedNewIndex < 0 ||
                            normalizedNewIndex >= steps.length ||
                            normalizedNewIndex == oldIndex) {
                          return;
                        }

                        final reordered = List<TaskStep>.from(steps);
                        final moved = reordered.removeAt(oldIndex);
                        reordered.insert(normalizedNewIndex, moved);

                        await stepProvider.reorderSteps(
                          widget.parentTaskId,
                          reordered,
                        );
                      }
                    : (_, _) {},
                itemBuilder: (context, index) {
                  final step = steps[index];
                  return Padding(
                    key: ValueKey('step_row_${step.stepId}'),
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 36,
                          child: Column(
                            children: [
                              Text(
                                '${index + 1}.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (canMutateSteps) ...[
                                const SizedBox(height: 2),
                                ReorderableDelayedDragStartListener(
                                  index: index,
                                  child: Icon(
                                    Icons.pan_tool_rounded,
                                    size: 18,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Expanded(
                          child: StepCard(
                            step: step,
                            onToggleDone:
                                canMutateSteps &&
                                    widget.allowCompletionToggle
                                ? (value) {
                                    print(
                                      '[DEBUG] TaskStepsList: Toggling step ${step.stepId}',
                                    );
                                    stepProvider.toggleStepDoneStatus(
                                      step,
                                    );
                                  }
                                : null,
                            onDelete: canMutateSteps
                                ? () {
                                    print(
                                      '[DEBUG] TaskStepsList: Deleting step ${step.stepId}',
                                    );
                                    stepProvider.softDeleteStep(step);
                                  }
                                : null,
                            onEdit: canMutateSteps && canAddStep
                                ? () => _openEditStepDialog(step)
                                : null,
                            onDuplicate: canMutateSteps && canAddStep
                                ? () async {
                                    await stepProvider.duplicateStep(step);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Step duplicated'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  }
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
          if (canAddStep)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: _isAddingStepInline
                  ? StreamBuilder<List<TaskStep>>(
                      stream: stepProvider.streamStepsByTaskId(
                        widget.parentTaskId,
                      ),
                      builder: (context, snapshot) {
                        final stepNumber = (snapshot.data?.length ?? 0) + 1;
                        return _buildInlineStepComposer(
                          context,
                          stepProvider: stepProvider,
                          stepNumber: stepNumber,
                        );
                      },
                    )
                  : _buildAddStepGhostCard(context, onTap: _startInlineAdd),
            ),
        ],
      ),
    );
  }

  bool _canAddStep() {
    // If no task info, allow (personal task)
    if (widget.task == null) return true;

    final userProvider = context.read<UserProvider>();
    final currentUserId = userProvider.userId ?? '';

    // Task assignee can add steps.
    if (widget.task!.taskAssignedTo == currentUserId) return true;

    // If it's a board task, check if user is board manager
    if (widget.task!.taskBoardId.isNotEmpty) {
      final boardProvider = context.read<BoardProvider>();
      final board = boardProvider.boards.firstWhere(
        (b) => b.boardId == widget.task!.taskBoardId,
        orElse: () => boardProvider.boards.first,
      );
      if (board.boardManagerId == currentUserId) return true;

      // Board members cannot add steps
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
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: 160,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 18,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.65,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add Step',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startInlineAdd() {
    if (_isAddingStepInline) return;
    print('[DEBUG] TaskStepsList: Add step card tapped');
    setState(() {
      _isAddingStepInline = true;
      _newStepController.clear();
    });
  }

  void _cancelInlineAdd() {
    if (!_isAddingStepInline) return;
    setState(() {
      _isAddingStepInline = false;
      _isSavingStepInline = false;
      _newStepController.clear();
    });
  }

  Future<void> _saveInlineStep(StepProvider stepProvider) async {
    final title = _newStepController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSavingStepInline = true);
    await stepProvider.addStep(
      stepTaskId: widget.parentTaskId,
      stepBoardId: widget.boardId ?? '',
      stepTitle: title,
      stepDescription: null,
    );

    if (!mounted) return;
    setState(() {
      _isSavingStepInline = false;
      _isAddingStepInline = false;
      _newStepController.clear();
    });
  }

  Widget _buildInlineStepComposer(
    BuildContext context, {
    required StepProvider stepProvider,
    required int stepNumber,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Text(
            '$stepNumber.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Card(
            elevation: 2,
            color: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.outlineVariant, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Checkbox(
                    value: false,
                    onChanged: null,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _newStepController,
                      autofocus: true,
                      maxLines: 1,
                      textInputAction: TextInputAction.done,
                      enabled: !_isSavingStepInline,
                      onSubmitted: (_) => _saveInlineStep(stepProvider),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Write step...',
                        isDense: true,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_isSavingStepInline)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    IconButton(
                      tooltip: 'Cancel',
                      visualDensity: VisualDensity.compact,
                      onPressed: _cancelInlineAdd,
                      icon: const Icon(Icons.close, size: 18),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _newStepController,
                      builder: (context, value, _) {
                        final canSave =
                            !_isSavingStepInline &&
                            value.text.trim().isNotEmpty;
                        return IconButton(
                          tooltip: 'Save',
                          visualDensity: VisualDensity.compact,
                          onPressed: canSave
                              ? () => _saveInlineStep(stepProvider)
                              : null,
                          icon: const Icon(Icons.check, size: 18),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}


