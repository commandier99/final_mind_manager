import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../steps/datasources/providers/step_provider.dart';
import '../../../../steps/datasources/models/step_model.dart';
import '../../../../steps/presentation/widgets/step_card.dart';
import '../../../datasources/models/task_model.dart';
import '../../../../boards/datasources/providers/board_provider.dart';
import '../../../../boards/datasources/models/board_model.dart';
import '../../../../thoughts/datasources/models/thought_model.dart';
import '../../../../thoughts/datasources/services/thought_service.dart';
import '../../../../thoughts/presentation/widgets/dialogs/create_thought_dialog.dart';
import '../cards/suggested_step_card.dart';
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
  final ThoughtService _thoughtService = ThoughtService();
  bool _isAddingStepInline = false;
  bool _isSavingStepInline = false;
  bool _showStepSuggestions = false;

  @override
  void initState() {
    super.initState();
    debugPrint(
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit step'),
        content: TextField(
          controller: stepController,
          autofocus: true,
          maxLines: 1,
          decoration: const InputDecoration(hintText: 'Step'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
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
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) => stepController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[DEBUG] TaskStepsList: build called for parentTaskId = ${widget.parentTaskId}',
    );

    final stepProvider = context.read<StepProvider>();
    final isTaskLocked = widget.task?.taskIsDone == true;
    final canMutateSteps = !isTaskLocked;
    final canAddRealStep = canMutateSteps && _canAddRealStep();
    final canSuggestStep = canMutateSteps && _canSuggestStep();
    final canViewStepSuggestions =
        canMutateSteps && _canViewStepSuggestions();

    return Padding(
      padding: widget.contentPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canViewStepSuggestions) ...[
            Row(
              children: [
                Expanded(
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).dividerColor.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(width: 8),
                _buildSuggestionToggle(context),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (canViewStepSuggestions && _showStepSuggestions) ...[
            _buildStepSuggestionStream(),
            const SizedBox(height: 6),
          ],
          // Stream of steps
          StreamBuilder<List<TaskStep>>(
            stream: stepProvider.streamStepsByTaskId(widget.parentTaskId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                debugPrint(
                  '[DEBUG] TaskStepsList: Error loading steps - ${snapshot.error}',
                );
                return Text('Error: ${snapshot.error}');
              }

              final steps = snapshot.data ?? <TaskStep>[];

              if (steps.isEmpty) {
                debugPrint('[DEBUG] TaskStepsList: No steps found.');
                return const SizedBox.shrink();
              }

              debugPrint(
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
                                    debugPrint(
                                      '[DEBUG] TaskStepsList: Toggling step ${step.stepId}',
                                    );
                                    stepProvider.toggleStepDoneStatus(
                                      step,
                                    );
                                  }
                                : null,
                            onDelete: canMutateSteps
                                ? () {
                                    debugPrint(
                                      '[DEBUG] TaskStepsList: Deleting step ${step.stepId}',
                                    );
                                    stepProvider.softDeleteStep(step);
                                  }
                                : null,
                            onEdit: canMutateSteps && canAddRealStep
                                ? () => _openEditStepDialog(step)
                                : null,
                            onDuplicate: canMutateSteps && canAddRealStep
                                ? () async {
                                    await stepProvider.duplicateStep(step);
                                    if (!context.mounted) return;
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
          if (canAddRealStep)
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
          if (!canAddRealStep && canSuggestStep)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: _buildAddStepGhostCard(
                context,
                onTap: _openSuggestStepSheet,
                label: 'Suggest Step',
                icon: Icons.edit_note_rounded,
              ),
            ),
        ],
      ),
    );
  }

  bool _canAddRealStep() {
    // If no task info, allow (personal task)
    if (widget.task == null) return true;

    if (_isDraftTask) return false;

    final currentUserId = _currentUserId;
    return widget.task!.taskAssignedTo == currentUserId &&
        currentUserId.isNotEmpty &&
        widget.task!.taskAssignedTo != 'None';
  }

  bool _canSuggestStep() {
    final task = widget.task;
    if (task == null || task.taskBoardId.isEmpty) return false;

    final board = _currentBoard;
    final currentUserId = _currentUserId;
    if (board == null || currentUserId.isEmpty) return false;

    return board.isManager(currentUserId) || board.isSupervisor(currentUserId);
  }

  bool _canViewStepSuggestions() {
    final task = widget.task;
    if (task == null) return false;

    final currentUserId = _currentUserId;
    if (currentUserId.isEmpty) return false;

    return task.taskAssignedTo == currentUserId &&
        task.taskAssignedTo != 'None';
  }

  String get _currentUserId => context.read<UserProvider>().userId ?? '';

  Board? get _currentBoard {
    final task = widget.task;
    if (task == null || task.taskBoardId.isEmpty) return null;
    return context.read<BoardProvider>().getBoardById(task.taskBoardId);
  }

  bool get _isDraftTask => widget.task?.taskBoardLane == Task.laneDrafts;

  Future<void> _openSuggestStepSheet() async {
    final task = widget.task;
    if (task == null) return;
    await CreateThoughtDialog.show(
      context,
      initialType: Thought.typeSuggestion,
      initialTaskId: task.taskId,
      initialSuggestionMode: 'step',
      lockType: true,
    );
  }

  Widget _buildSuggestionToggle(BuildContext context) {
    final isActive = _showStepSuggestions;
    return Tooltip(
      message: isActive ? 'Hide step suggestions' : 'Show step suggestions',
      child: InkWell(
        onTap: () {
          setState(() {
            _showStepSuggestions = !_showStepSuggestions;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFF7CC) : null,
            border: Border.all(
              color: isActive
                  ? const Color(0xFFEAB308)
                  : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 16,
                color: isActive
                    ? const Color(0xFF854D0E)
                    : Colors.grey.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                'Suggestions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? const Color(0xFF854D0E)
                      : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepSuggestionStream() {
    final task = widget.task;
    if (task == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<Thought>>(
      stream: _thoughtService.streamThoughtsByTask(task.taskId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 3),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Could not load step suggestions.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade400,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }

        final thoughts = snapshot.data ?? const <Thought>[];
        final stepSuggestions = thoughts.where((thought) {
          if (thought.type != Thought.typeSuggestion) return false;
          if (!thought.isActionable) return false;
          final metadata = thought.metadata ?? const <String, dynamic>{};
          final suggestionTarget = (metadata['suggestionTarget']?.toString() ?? '')
              .trim()
              .toLowerCase();
          return suggestionTarget == 'step';
        }).toList();

        if (stepSuggestions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No step suggestions waiting for review.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text(
                'Step Suggestions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            ...stepSuggestions.map(
              (thought) => SuggestedStepCard(
                key: ValueKey('step_suggestion_${thought.thoughtId}'),
                thought: thought,
                task: task,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAddStepGhostCard(
    BuildContext context, {
    required VoidCallback onTap,
    String label = 'Add Step',
    IconData icon = Icons.add_circle_outline,
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
                      icon,
                      size: 18,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.65,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
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
    debugPrint('[DEBUG] TaskStepsList: Add step card tapped');
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


