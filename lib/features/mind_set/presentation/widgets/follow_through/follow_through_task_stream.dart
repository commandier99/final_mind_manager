import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/presentation/widgets/cards/task_card.dart';
import '../../../../steps/datasources/providers/step_provider.dart';
import '../../../../../shared/modes/mind_set_modes.dart';
import '../../../../../shared/modes/mind_set_mode_policy.dart';
import '../../../datasources/models/mind_set_session_model.dart';
import '../../../datasources/services/mind_set_session_runtime_service.dart';
import '../../../../../shared/features/query/task_query_controller.dart';
import '../../utils/session_task_submission_helper.dart';

class FollowThroughTaskStream extends StatefulWidget {
  final List<String> taskIds;
  final String mode;
  final MindSetSession? session;

  const FollowThroughTaskStream({
    super.key,
    required this.taskIds,
    required this.mode,
    this.session,
  });

  @override
  State<FollowThroughTaskStream> createState() =>
      _FollowThroughTaskStreamState();
}

class _FollowThroughTaskStreamState extends State<FollowThroughTaskStream> {
  final MindSetSessionRuntimeService _runtimeService =
      MindSetSessionRuntimeService();
  final TaskQueryController _taskQueryController = TaskQueryController();
  final StepProvider _stepProvider = StepProvider();
  final Map<String, DateTime> _focusStartedAtByTaskId = <String, DateTime>{};
  String _sortBy = 'created_desc'; // format: 'field_direction'
  late Set<String> _selectedFilters;

  @override
  void initState() {
    super.initState();
    _selectedFilters = {TaskQueryController.allFilter};
    _streamTasks();
  }

  @override
  void didUpdateWidget(covariant FollowThroughTaskStream oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.taskIds, widget.taskIds)) {
      _streamTasks();
    }
  }

  void _streamTasks() {
    final taskProvider = context.read<TaskProvider>();
    taskProvider.streamTasksByIds(widget.taskIds);
  }

  bool _isInProgressStatus(String status) {
    return _runtimeService.isInProgressStatus(status);
  }

  Future<void> _logSessionAction({
    required String type,
    required Task task,
    Task? fromTask,
  }) async {
    final session = widget.session;
    if (session == null) return;
    await _runtimeService.logSessionAction(
      session: session,
      type: type,
      taskId: task.taskId,
      fromTaskId: fromTask?.taskId,
    );
  }

  Future<void> _focusTask(Task task) async {
    if (task.taskIsDone) return;
    if (_isInProgressStatus(task.taskStatus)) return;
    final isPomodoro = MindSetModePolicy.fromMode(widget.mode).isPomodoro;

    final taskProvider = context.read<TaskProvider>();
    final dependencyBlocker = await taskProvider.getFirstIncompleteDependency(
      task,
    );
    if (dependencyBlocker != null) {
      _showBlockedByDependencyMessage(dependencyBlocker);
      return;
    }
    if (!mounted) return;

    Task? focusedTask;
    for (final candidate in taskProvider.tasks) {
      if (candidate.taskId == task.taskId) continue;
      if (candidate.taskIsDone) continue;
      if (_isInProgressStatus(candidate.taskStatus)) {
        focusedTask = candidate;
        break;
      }
    }

    if (focusedTask != null) {
      final activeTask = focusedTask;
      if (!isPomodoro) {
        final shouldPause = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Pause current task?'),
            content: Text(
              'You can focus on only one task at a time. Pause "${activeTask.taskTitle}" first.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Pause Task'),
              ),
            ],
          ),
        );
        if (!mounted) return;

        if (shouldPause != true) return;
      }

      await taskProvider.updateTask(activeTask.copyWith(taskStatus: 'Paused'));
      await _maybeCreateSessionCheckpointStep(
        activeTask,
        reason: 'Worked in session and switched tasks.',
        elapsedDuration: _consumeElapsedForTask(activeTask.taskId),
      );
      await _logSessionAction(type: 'switch', task: task, fromTask: activeTask);
    }

    await taskProvider.updateTask(task.copyWith(taskStatus: 'In Progress'));
    _focusStartedAtByTaskId[task.taskId] = DateTime.now();
    await _startPomodoroIfNeeded();
    if (focusedTask == null) {
      await _logSessionAction(type: 'focus', task: task);
    }
  }

  Future<void> _startPomodoroIfNeeded() async {
    final session = widget.session;
    if (session == null) return;
    await _runtimeService.startPomodoroIfNeeded(session);
  }

  Future<void> _pauseTask(Task task) async {
    if (!_isInProgressStatus(task.taskStatus)) return;
    final taskProvider = context.read<TaskProvider>();
    await taskProvider.updateTask(task.copyWith(taskStatus: 'Paused'));
    await _maybeCreateSessionCheckpointStep(
      task,
      reason: 'Worked in session but paused before completion.',
      elapsedDuration: _consumeElapsedForTask(task.taskId),
    );
    await _logSessionAction(type: 'pause', task: task);
  }

  Future<void> _maybeCreateSessionCheckpointStep(
    Task task, {
    required String reason,
    required Duration elapsedDuration,
  }) async {
    if (task.taskIsDone) return;

    final latestActiveStep = await _stepProvider
        .getLatestActiveStepForTask(task.taskId);
    if (latestActiveStep != null) {
      await _stepProvider.toggleStepDoneStatus(latestActiveStep);
      return;
    }

    final elapsedLabel = _formatElapsedDuration(elapsedDuration);
    await _stepProvider.addStep(
      stepTaskId: task.taskId,
      stepBoardId: task.taskBoardId,
      stepTitle: 'Session checkpoint ($elapsedLabel)',
      stepDescription: '$reason Elapsed focus time: $elapsedLabel.',
      initialDone: true,
    );
  }

  Future<void> _toggleDoneForTask(Task task, bool? isDone) async {
    final taskProvider = context.read<TaskProvider>();
    final markDone = isDone ?? false;
    final persistToggle = taskProvider.toggleTaskDone(
      task.copyWith(
        taskIsDone: markDone,
        taskStatus: markDone ? 'Completed' : 'To Do',
      ),
    );

    try {
      if (markDone) {
        _focusStartedAtByTaskId.remove(task.taskId);
        await _handlePostCompletion(task);
        await _logSessionAction(type: 'complete', task: task);
      }
      await persistToggle;
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message.toString())),
      );
    }
  }

  Duration _consumeElapsedForTask(String taskId) {
    final startedAt = _focusStartedAtByTaskId.remove(taskId);
    final fallbackStart =
        widget.session?.sessionStartedAt ?? widget.session?.sessionCreatedAt;
    final base = startedAt ?? fallbackStart;
    if (base == null) return Duration.zero;
    final elapsed = DateTime.now().difference(base);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  String _formatElapsedDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  Future<void> _handlePostCompletion(Task completedTask) async {
    if (!mounted) return;
    final taskProvider = context.read<TaskProvider>();
    final session = widget.session;
    final isPomodoro =
        session != null &&
        MindSetModes.resolveRuntimeMode(session.sessionMode) ==
            MindSetModes.pomodoro;
    final remainingTasks = taskProvider.tasks
        .where(
          (task) =>
              widget.taskIds.contains(task.taskId) &&
              task.taskId != completedTask.taskId &&
              !SessionTaskSubmissionHelper.isSessionTaskComplete(task),
        )
        .toList();

    if (remainingTasks.isEmpty) {
      if (isPomodoro) {
        await _showPomodoroFocusDecision();
      }
      // Let the parent active-session view own end-session summary prompts
      // to avoid duplicate dialogs in Follow Through.
      return;
    }

    if (!isPomodoro) {
      if (!mounted) return;
      if (MindSetModePolicy.fromMode(widget.mode).isEatTheFrog) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Frog done. Pick your next hardest task.'),
          ),
        );
      }
      return;
    }

    await _showPomodoroFocusDecision();
  }

  Future<void> _toggleThoughtSubmit(Task task) async {
    await SessionTaskSubmissionHelper.openSubmissionFlow(context, task);
  }

  Future<void> _showPomodoroFocusDecision() async {
    if (!mounted) return;
    final endFocusNow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Focus Session Complete'),
        content: const Text(
          'Do you want to end this Pomodoro focus session now?\n\n'
          'End now: starts break.\n'
          'Continue working: timer pauses until you select a new task.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Working'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Focus Now'),
          ),
        ],
      ),
    );

    if (endFocusNow == true) {
      await _startBreakNow();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Break started.')));
      return;
    }

    await _pausePomodoroIfNeeded();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Timer paused. Focus another task to resume.'),
        ),
      );
    }
  }

  Future<void> _startBreakNow() async {
    final session = widget.session;
    if (session == null) return;
    await _runtimeService.startBreakNow(session);
  }

  Future<void> _pausePomodoroIfNeeded() async {
    final session = widget.session;
    if (session == null) return;
    await _runtimeService.pausePomodoroIfNeeded(session);
  }

  void _showBlockedByDependencyMessage(Task blocker) {
    if (!mounted) return;
    final assigned = blocker.taskAssignedToName.trim();
    final suffix = assigned.isEmpty || assigned == 'Unassigned'
        ? ''
        : ' by $assigned';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Blocked by "${blocker.taskTitle}"$suffix. Complete it first.',
        ),
      ),
    );
  }

  int _priorityToInt(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return 1;
      case 'medium':
        return 2;
      case 'high':
        return 3;
      default:
        return 0;
    }
  }

  Task? _resolveFrogTask(List<Task> tasks) {
    for (final task in tasks) {
      if (_isInProgressStatus(task.taskStatus)) {
        return task;
      }
    }

    final candidates = tasks.where((task) => !task.taskIsDone).toList();
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final priority = _priorityToInt(
        b.taskPriorityLevel,
      ).compareTo(_priorityToInt(a.taskPriorityLevel));
      if (priority != 0) return priority;

      final aDeadline = a.taskDeadline ?? DateTime(2099);
      final bDeadline = b.taskDeadline ?? DateTime(2099);
      final deadline = aDeadline.compareTo(bDeadline);
      if (deadline != 0) return deadline;

      return a.taskCreatedAt.compareTo(b.taskCreatedAt);
    });

    return candidates.first;
  }

  @override
  Widget build(BuildContext context) {
    final modePolicy = MindSetModePolicy.fromMode(widget.mode);
    final isPomodoroBreak =
        modePolicy.isPomodoro &&
        (widget.session?.sessionStats.pomodoroIsOnBreak ?? false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              // Tasks Header with Divider
              Row(
                children: [
                  const Text(
                    'Tasks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(height: 1, color: Colors.grey[300]),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    tooltip: 'Filter',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.filter_list,
                        size: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                    onSelected: (filter) {
                      setState(() {
                        _selectedFilters = _taskQueryController.addFilter(
                          selectedFilters: _selectedFilters,
                          filter: filter,
                        );
                      });
                    },
                    itemBuilder: (context) => TaskQueryController.allFilters
                        .where((f) => !_selectedFilters.contains(f))
                        .map((filter) {
                          return PopupMenuItem(
                            value: filter,
                            child: Text(
                              _taskQueryController.getFilterLabel(filter),
                            ),
                          );
                        })
                        .toList(),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showSortMenu(),
                        borderRadius: BorderRadius.circular(4),
                        child: Icon(
                          Icons.swap_vert,
                          size: 16,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (!_selectedFilters.contains(TaskQueryController.allFilter))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _selectedFilters.map((filter) {
                      return Chip(
                        label: Text(
                          _taskQueryController.getFilterLabel(filter),
                        ),
                        onDeleted: () {
                          setState(() {
                            _selectedFilters = _taskQueryController
                                .removeFilter(
                                  selectedFilters: _selectedFilters,
                                  filter: filter,
                                );
                          });
                        },
                        backgroundColor: Colors.grey[400],
                        deleteIconColor: Colors.white,
                        side: BorderSide.none,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Consumer<TaskProvider>(
            builder: (context, taskProvider, _) {
              if (taskProvider.isLoading && taskProvider.tasks.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (widget.taskIds.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Text(
                      'This plan has no tasks yet.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final orderedPlanTasks = _sortTasksByPlanOrder(
                taskProvider.tasks,
                widget.taskIds,
              );
              final tasks = _taskQueryController.applyQuery(
                tasks: orderedPlanTasks,
                selectedFilters: _selectedFilters,
                sortBy: _sortBy,
              );
              final isSessionActive = widget.session?.sessionStatus == 'active';
              final visibleTasks = tasks;
              Task? focusedTask;
              for (final task in visibleTasks) {
                if (_isInProgressStatus(task.taskStatus)) {
                  focusedTask = task;
                  break;
                }
              }
              final hasFocusedTask = focusedTask != null;
              final modeVisibleTasks = visibleTasks
                  .where(
                    (task) => modePolicy.taskVisible(
                      hasFocusedTask: hasFocusedTask,
                      isTaskFocused: _isInProgressStatus(task.taskStatus),
                    ),
                  )
                  .toList();
              final frogTask = modePolicy.isEatTheFrog
                  ? _resolveFrogTask(modeVisibleTasks)
                  : null;
              final displayTasks = modePolicy.isEatTheFrog && hasFocusedTask
                  ? (frogTask == null ? <Task>[] : <Task>[frogTask])
                  : modeVisibleTasks;

              if (displayTasks.isEmpty) {
                const emptyMessage = 'No tasks found for this plan.';
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      emptyMessage,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  if (modePolicy.isEatTheFrog)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                      child: Text(
                        hasFocusedTask
                            ? 'Work on this until you are done.\nOther tasks are hidden to keep focus.'
                            : 'Pick your next frog task.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (modePolicy.isChecklist)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 2, 16, 8),
                      child: Text(
                        'Focus on one task at a time. You can pause and switch tasks, then mark each one done while focused.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: displayTasks.length,
                      itemBuilder: (context, index) {
                        final task = displayTasks[index];
                        final isFocused = _isInProgressStatus(task.taskStatus);
                        final usesThoughtSubmit = SessionTaskSubmissionHelper
                            .shouldUseThoughtSubmit(context, task);
                        final canMarkDone = SessionTaskSubmissionHelper
                            .canMarkTaskDone(context, task);
                        final canFocusByMode = modePolicy.canFocusTask(
                          isSessionActive: isSessionActive,
                          hasFocusedTask: hasFocusedTask,
                          isTaskFocused: isFocused,
                        );
                        final canFocus = canFocusByMode;
                        final canPause = modePolicy.canPauseTask(
                          isSessionActive: isSessionActive,
                          isTaskFocused: isFocused,
                        );
                        final canToggleDone =
                            isSessionActive &&
                            modePolicy.doneAllowedOnTask(isFocused: isFocused);
                        final isFrogTask =
                            frogTask != null && frogTask.taskId == task.taskId;

                        return Column(
                          children: [
                            TaskCard(
                              task: task,
                              showFocusAction:
                                  !isPomodoroBreak &&
                                  (canFocusByMode || canPause),
                              showFocusInMainRow: true,
                              showCheckboxWhenFocusedOnly: true,
                              useStatusColor: true,
                              isPomodoroMode: modePolicy.isPomodoro,
                              showFrogBadge: isFrogTask,
                              useThoughtSubmissionToggleForDone: true,
                              isDimmed: false,
                              onFocus: canFocus ? () => _focusTask(task) : null,
                              onPause: canPause ? () => _pauseTask(task) : null,
                              onToggleDone:
                                  canToggleDone &&
                                      !usesThoughtSubmit &&
                                      canMarkDone
                                  ? (isDone) => _toggleDoneForTask(task, isDone)
                                  : null,
                              onSubmitThought:
                                  canToggleDone && usesThoughtSubmit
                                  ? () => _toggleThoughtSubmit(task)
                                  : null,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  List<Task> _sortTasksByPlanOrder(List<Task> tasks, List<String> order) {
    final orderMap = <String, int>{};
    for (var i = 0; i < order.length; i++) {
      orderMap[order[i]] = i;
    }

    final sorted = [...tasks];
    sorted.sort((a, b) {
      final aIndex = orderMap[a.taskId] ?? order.length;
      final bIndex = orderMap[b.taskId] ?? order.length;
      return aIndex.compareTo(bIndex);
    });
    return sorted;
  }

  void _showSortMenu() {
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 100,
        kToolbarHeight + 50,
        0,
        0,
      ),
      items: [
        const PopupMenuDivider(height: 8),
        const PopupMenuItem(
          value: 'priority_asc',
          child: Text('Priority (Low→High)'),
        ),
        const PopupMenuItem(
          value: 'priority_desc',
          child: Text('Priority (High→Low)'),
        ),
        const PopupMenuDivider(height: 8),
        const PopupMenuItem(
          value: 'alphabetical_asc',
          child: Text('Title (A→Z)'),
        ),
        const PopupMenuItem(
          value: 'alphabetical_desc',
          child: Text('Title (Z→A)'),
        ),
        const PopupMenuDivider(height: 8),
        const PopupMenuItem(
          value: 'created_asc',
          child: Text('Created (Oldest)'),
        ),
        const PopupMenuItem(
          value: 'created_desc',
          child: Text('Created (Newest)'),
        ),
        const PopupMenuDivider(height: 8),
        const PopupMenuItem(
          value: 'deadline_asc',
          child: Text('Deadline (Soonest)'),
        ),
        const PopupMenuItem(
          value: 'deadline_desc',
          child: Text('Deadline (Latest)'),
        ),
      ],
    ).then((value) {
      if (value != null) {
        setState(() {
          _sortBy = value;
        });
      }
    });
  }
}

