import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../../boards/datasources/models/board_model.dart';
import '../../../../boards/datasources/providers/board_provider.dart';
import '../dialogs/add_task_to_session_dialog.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/presentation/widgets/cards/task_card.dart';
import '../../../../steps/datasources/providers/step_provider.dart';
import '../../../../../shared/modes/mind_set_modes.dart';
import '../../../../../shared/modes/mind_set_mode_policy.dart';
import '../../../datasources/services/mind_set_session_runtime_service.dart';
import '../../../datasources/services/mind_set_session_service.dart';
import '../../../datasources/models/mind_set_session_model.dart';
import '../../../../../shared/features/query/task_query_controller.dart';
import '../../../../../shared/services/app_sound_service.dart';
import '../../utils/session_task_submission_helper.dart';

class OnTheSpotTaskStream extends StatefulWidget {
  final String sessionId;
  final List<String> sessionTaskIds;
  final String mode;
  final bool isSessionActive;
  final MindSetSession? session;

  const OnTheSpotTaskStream({
    super.key,
    required this.sessionId,
    required this.sessionTaskIds,
    required this.mode,
    required this.isSessionActive,
    this.session,
  });

  @override
  State<OnTheSpotTaskStream> createState() => _OnTheSpotTaskStreamState();
}

class _OnTheSpotTaskStreamState extends State<OnTheSpotTaskStream> {
  Board? _personalBoard;
  bool _isLoadingBoard = true;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final MindSetSessionService _sessionService = MindSetSessionService();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPersonalBoard();
      _streamTasks();
    });
  }

  @override
  void didUpdateWidget(covariant OnTheSpotTaskStream oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.sessionTaskIds, widget.sessionTaskIds)) {
      _streamTasks();
    }
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

  Future<void> _loadPersonalBoard() async {
    final boardProvider = context.read<BoardProvider>();
    final existing = _findPersonalBoard(boardProvider);
    if (existing != null) {
      _setPersonalBoard(existing);
      return;
    }

    setState(() {
      _isLoadingBoard = true;
    });

    await boardProvider.refreshBoards();

    final refreshed = _findPersonalBoard(boardProvider);
    if (refreshed != null) {
      _setPersonalBoard(refreshed);
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
  }

  void _streamTasks() {
    final taskProvider = context.read<TaskProvider>();
    taskProvider.streamTasksByIds(widget.sessionTaskIds);
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
    if (!widget.isSessionActive || task.taskIsDone) return;
    if (_isInProgressStatus(task.taskStatus)) return;
    final isPomodoro = MindSetModePolicy.fromMode(widget.mode).isPomodoro;

    final taskProvider = context.read<TaskProvider>();
    final dependencyBlocker = await taskProvider.getFirstIncompleteDependency(
      task,
    );
    if (dependencyBlocker != null) {
      if (!mounted) return;
      final assigned = dependencyBlocker.taskAssignedToName.trim();
      final suffix = assigned.isEmpty || assigned == 'Unassigned'
          ? ''
          : ' by $assigned';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Blocked by "${dependencyBlocker.taskTitle}"$suffix. Complete it first.',
          ),
        ),
      );
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
    await AppSoundService.instance.playTap();
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
    if (!widget.isSessionActive) return;
    if (!_isInProgressStatus(task.taskStatus)) return;

    final taskProvider = context.read<TaskProvider>();
    await taskProvider.updateTask(task.copyWith(taskStatus: 'Paused'));
    await _maybeCreateSessionCheckpointStep(
      task,
      reason: 'Worked in session but paused before completion.',
      elapsedDuration: _consumeElapsedForTask(task.taskId),
    );
    await AppSoundService.instance.playTap();
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
        await AppSoundService.instance.playSuccess();
      }
      await persistToggle;
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message.toString())),
      );
    }
  }

  Future<void> _toggleThoughtSubmit(Task task) async {
    final submitted = await SessionTaskSubmissionHelper.openSubmissionFlow(
      context,
      task,
    );
    if (submitted) {
      await AppSoundService.instance.playSuccess();
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
              widget.sessionTaskIds.contains(task.taskId) &&
              task.taskId != completedTask.taskId &&
              !SessionTaskSubmissionHelper.isSessionTaskComplete(task),
        )
        .toList();

    if (remainingTasks.isEmpty) {
      if (isPomodoro) {
        await _showPomodoroFocusDecision();
      }
      if (!mounted) return;
      final shouldEndSession = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('All Tasks Completed'),
          content: const Text(
            'Great work. Do you want to keep this session open or end it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Session Open'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('End Session'),
            ),
          ],
        ),
      );

      if (shouldEndSession != true) {
        return;
      }

      final sessionTasks = taskProvider.tasks
          .where((task) => widget.sessionTaskIds.contains(task.taskId))
          .toList();
      await _showSessionSummaryAndEnd(sessionTasks);
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
      await AppSoundService.instance.playAlert();
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

  Future<void> _showSessionSummaryAndEnd(List<Task> sessionTasks) async {
    final session = widget.session;
    if (session == null || !mounted) return;
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    final now = DateTime.now();
    final startedAt = session.sessionStartedAt ?? session.sessionCreatedAt;
    final duration = now.difference(startedAt);
    final tasksTotal = sessionTasks.length;
    final tasksDone = sessionTasks
        .where(SessionTaskSubmissionHelper.isSessionTaskComplete)
        .length;
    final completionRate = tasksTotal == 0
        ? 100
        : ((tasksDone / tasksTotal) * 100).round();

    await _pausePomodoroIfNeeded();
    await _sessionService.completeSession(
      session: session,
      endedAt: now,
      tasksTotal: tasksTotal,
      tasksDone: tasksDone,
    );
    await AppSoundService.instance.playSuccess();

    await showDialog<void>(
      // ignore: use_build_context_synchronously
      context: rootNavigator.context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Session Successful'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time spent: ${_formatDuration(duration)}'),
            Text('Tasks completed: $tasksDone/$tasksTotal'),
            Text('Completion rate: $completionRate%'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingBoard) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_personalBoard == null) {
      return const Center(child: Text('Unable to load Personal board.'));
    }

    final canAddTask = widget.isSessionActive;
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
                    tooltip: 'Add filters',
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
                    itemBuilder: (context) {
                      return TaskQueryController.allFilters
                          .where((f) => !_selectedFilters.contains(f))
                          .map((filter) {
                            final label = _taskQueryController.getFilterLabel(
                              filter,
                            );
                            return PopupMenuItem<String>(
                              value: filter,
                              child: Text(label),
                            );
                          })
                          .toList();
                    },
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
                        onTap: canAddTask ? _showAddTaskDialog : null,
                        borderRadius: BorderRadius.circular(4),
                        child: Icon(
                          Icons.add,
                          size: 16,
                          color: canAddTask
                              ? Colors.grey[700]
                              : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (!widget.isSessionActive)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Start the session to begin working on tasks.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              // Active filters display
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

        // Tasks List
        Expanded(
          child: Consumer<TaskProvider>(
            builder: (context, taskProvider, _) {
              if (taskProvider.isLoading && taskProvider.tasks.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final tasks = taskProvider.tasks;

              final sortedTasks = _taskQueryController.applyQuery(
                tasks: tasks,
                selectedFilters: _selectedFilters,
                sortBy: _sortBy,
              );
              Task? focusedTask;
              for (final task in sortedTasks) {
                if (_isInProgressStatus(task.taskStatus)) {
                  focusedTask = task;
                  break;
                }
              }
              final hasFocusedTask = focusedTask != null;
              final visibleTasks = sortedTasks
                  .where(
                    (task) => modePolicy.taskVisible(
                      hasFocusedTask: hasFocusedTask,
                      isTaskFocused: _isInProgressStatus(task.taskStatus),
                    ),
                  )
                  .toList();
              final frogTask = modePolicy.isEatTheFrog
                  ? _resolveFrogTask(visibleTasks)
                  : null;
              final displayTasks = modePolicy.isEatTheFrog && hasFocusedTask
                  ? (frogTask == null ? <Task>[] : <Task>[frogTask])
                  : visibleTasks;

              if (displayTasks.isEmpty) {
                const emptyMessage =
                    'No tasks yet. Tap the + button to create one!';
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

              final isActive = widget.isSessionActive;

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
                        final canFocus = modePolicy.canFocusTask(
                          isSessionActive: isActive,
                          hasFocusedTask: hasFocusedTask,
                          isTaskFocused: isFocused,
                        );
                        final canPause = modePolicy.canPauseTask(
                          isSessionActive: isActive,
                          isTaskFocused: isFocused,
                        );
                        final canToggleDone =
                            isActive &&
                            modePolicy.doneAllowedOnTask(isFocused: isFocused);
                        final isFrogTask =
                            frogTask != null && frogTask.taskId == task.taskId;

                        return Column(
                          children: [
                            TaskCard(
                              task: task,
                              showFocusAction:
                                  isActive &&
                                  !isPomodoroBreak &&
                                  (canFocus || canPause),
                              showFocusInMainRow: true,
                              showCheckboxWhenFocusedOnly: true,
                              showBoardLabel: false,
                              useStatusColor: true,
                              isPomodoroMode: modePolicy.isPomodoro,
                              showFrogBadge: isFrogTask,
                              useThoughtSubmissionToggleForDone: true,
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
                              onDelete: () => _deleteTask(task),
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

  void _showAddTaskDialog() {
    if (_personalBoard == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTaskToSessionDialog(
        userId: _currentUserId,
        board: _personalBoard!,
        onTaskCreated: _handleTaskCreated,
      ),
    );
  }

  Future<void> _handleTaskCreated(String taskId) async {
    if (widget.sessionId.isEmpty) return;

    await _sessionService.addTaskToSession(widget.sessionId, taskId);
    if (!mounted) return;

    final updatedIds = {...widget.sessionTaskIds, taskId}.toList();
    context.read<TaskProvider>().streamTasksByIds(updatedIds);
  }

  Future<void> _deleteTask(Task task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "${task.taskTitle}" from this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    if (!mounted) return;

    final taskProvider = context.read<TaskProvider>();
    await taskProvider.softDeleteTask(task);
    await _sessionService.removeTaskFromSession(widget.sessionId, task.taskId);

    if (!mounted) return;

    final updatedIds = widget.sessionTaskIds
        .where((id) => id != task.taskId)
        .toList();
    taskProvider.streamTasksByIds(updatedIds);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Task deleted from session')));
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

