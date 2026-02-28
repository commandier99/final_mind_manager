import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/presentation/widgets/cards/task_card.dart';
import '../../../../../shared/modes/mind_set_modes.dart';
import '../../../../../shared/modes/mind_set_mode_policy.dart';
import '../../../datasources/models/mind_set_session_model.dart';
import '../../../datasources/services/mind_set_session_runtime_service.dart';
import '../../../datasources/services/mind_set_session_service.dart';
import '/features/plans/datasources/models/plans_model.dart';
import '/features/plans/datasources/providers/plan_provider.dart';
import '../../../../../shared/features/query/task_query_controller.dart';

class GoWithFlowTaskStream extends StatefulWidget {
  final String userId;
  final String mode;
  final MindSetSession? session;

  const GoWithFlowTaskStream({
    super.key,
    required this.userId,
    required this.mode,
    this.session,
  });

  @override
  State<GoWithFlowTaskStream> createState() => _GoWithFlowTaskStreamState();
}

class _GoWithFlowTaskStreamState extends State<GoWithFlowTaskStream> {
  final MindSetSessionService _sessionService = MindSetSessionService();
  final MindSetSessionRuntimeService _runtimeService =
      MindSetSessionRuntimeService();
  final TaskQueryController _taskQueryController = TaskQueryController();

  Task? _currentFlowTask;
  Task? _completionPreviewTask;
  final Set<String> _rejectedTaskIds = {};
  late Set<String> _selectedFilters;
  late String _currentFlowStyle;
  static const Duration _shuffleCompletionPreviewDuration = Duration(
    milliseconds: 700,
  );

  @override
  void initState() {
    super.initState();
    _selectedFilters = {TaskQueryController.allFilter};
    _currentFlowStyle = MindSetModes.normalizeFlowStyle(
      widget.session?.sessionFlowStyle,
    );
    _streamTasks();
  }

  void _streamTasks() {
    final taskProvider = context.read<TaskProvider>();
    taskProvider.streamUserActiveTasks(widget.userId);
  }

  bool _isInProgressStatus(String status) =>
      _runtimeService.isInProgressStatus(status);

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

  void _pickRandomFlowTask(List<Task> tasks) {
    final eligible = tasks
        .where((t) => !t.taskIsDone && !_isInProgressStatus(t.taskStatus))
        .toList();

    if (eligible.isEmpty) {
      _currentFlowTask = null;
      return;
    }

    var available = eligible
        .where((t) => !_rejectedTaskIds.contains(t.taskId))
        .toList();

    // If every eligible task was rejected in this round, start a fresh round.
    if (available.isEmpty) {
      _rejectedTaskIds.clear();
      available = List<Task>.from(eligible);
    }

    available.shuffle();
    _currentFlowTask = available.first;
  }

  Future<void> _focusTask(Task task) async {
    if (task.taskIsDone) return;

    final taskProvider = context.read<TaskProvider>();
    Task? previousFocused;

    // Pause any currently focused task
    for (final t in taskProvider.tasks) {
      if (_isInProgressStatus(t.taskStatus)) {
        previousFocused = t;
        await taskProvider.updateTask(t.copyWith(taskStatus: 'Paused'));
      }
    }

    await taskProvider.updateTask(task.copyWith(taskStatus: 'In Progress'));
    await _startPomodoroIfNeeded();

    if (previousFocused != null) {
      await _logSessionAction(
        type: 'switch',
        task: task,
        fromTask: previousFocused,
      );
    } else {
      await _logSessionAction(type: 'focus', task: task);
    }
  }

  Future<void> _startPomodoroIfNeeded() async {
    final session = widget.session;
    if (session == null) return;
    await _runtimeService.startPomodoroIfNeeded(session);
  }

  Future<void> _pauseTask(Task task) async {
    final taskProvider = context.read<TaskProvider>();
    await taskProvider.updateTask(task.copyWith(taskStatus: 'Paused'));
    await _logSessionAction(type: 'pause', task: task);
  }

  Future<void> _toggleDoneForTask(Task task, bool? isDone) async {
    final taskProvider = context.read<TaskProvider>();
    final markDone = isDone ?? false;
    final shouldShowShufflePreview =
        markDone && _currentFlowStyle == MindSetModes.flowStyleShuffle;
    if (shouldShowShufflePreview) {
      setState(() {
        _completionPreviewTask = task.copyWith(
          taskIsDone: true,
          taskStatus: 'COMPLETED',
        );
      });
    }
    final persistToggle = taskProvider.toggleTaskDone(
      task.copyWith(
        taskIsDone: markDone,
        taskStatus: markDone ? 'COMPLETED' : 'To Do',
      ),
    );
    if (markDone) {
      await persistToggle;
      if (shouldShowShufflePreview) {
        await Future.delayed(_shuffleCompletionPreviewDuration);
        if (!mounted) return;
        setState(() {
          _completionPreviewTask = null;
          _currentFlowTask = null;
        });
      }
      await _handlePostCompletion(task);
      await _logSessionAction(type: 'complete', task: task);
      return;
    }
    await persistToggle;
  }

  Future<void> _handlePostCompletion(Task completedTask) async {
    if (!mounted) return;
    final taskProvider = context.read<TaskProvider>();
    final planProvider = context.read<PlanProvider>();
    final session = widget.session;
    final isPomodoro =
        session != null &&
        MindSetModes.resolveRuntimeMode(session.sessionMode) ==
            MindSetModes.pomodoro;
    final plannedTaskIds = <String>{};
    for (final plan in planProvider.userPlans) {
      plannedTaskIds.addAll(plan.taskIds);
    }

    final remainingTasks = taskProvider.tasks
        .where(
          (task) =>
              !plannedTaskIds.contains(task.taskId) &&
              task.taskId != completedTask.taskId &&
              !task.taskIsDone,
        )
        .toList();

    if (remainingTasks.isEmpty) {
      if (isPomodoro) {
        await _showPomodoroFocusDecision();
      }
      final sessionTasks = taskProvider.tasks
          .where((task) => !plannedTaskIds.contains(task.taskId))
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
    final tasksDone = sessionTasks.where((task) => task.taskIsDone).length;
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

  Widget _buildFrogHint({required bool hasFocusedTask}) {
    return Padding(
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
    );
  }

  Widget _buildChecklistHint() {
    return const Padding(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final modePolicy = MindSetModePolicy.fromMode(widget.mode);
    final isSessionActive = widget.session?.sessionStatus == 'active';
    final isPomodoroBreak =
        modePolicy.isPomodoro &&
        (widget.session?.sessionStats.pomodoroIsOnBreak ?? false);

    return Column(
      children: [
        /// HEADER
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text(
                'Tasks',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(child: Container(height: 1, color: Colors.grey[300])),
              const SizedBox(width: 4),

              PopupMenuButton<String>(
                tooltip: 'Filter',
                child: Icon(
                  Icons.filter_list,
                  size: 18,
                  color: Colors.grey[700],
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

              const SizedBox(width: 12),

              /// FLOW STYLE TOGGLE
              InkWell(
                onTap: () async {
                  final newStyle =
                      _currentFlowStyle == MindSetModes.flowStyleShuffle
                      ? MindSetModes.flowStyleList
                      : MindSetModes.flowStyleShuffle;

                  setState(() {
                    _currentFlowStyle = newStyle;
                    _currentFlowTask = null;
                    _rejectedTaskIds.clear();
                  });

                  if (widget.session != null) {
                    await _sessionService.updateSession(
                      widget.session!.copyWith(sessionFlowStyle: newStyle),
                    );
                  }
                },
                child: Icon(
                  _currentFlowStyle == MindSetModes.flowStyleShuffle
                      ? Icons.shuffle
                      : Icons.view_list,
                  size: 18,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),
        if (!_selectedFilters.contains(TaskQueryController.allFilter))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _selectedFilters.map((filter) {
                  return Chip(
                    label: Text(_taskQueryController.getFilterLabel(filter)),
                    onDeleted: () {
                      setState(() {
                        _selectedFilters = _taskQueryController.removeFilter(
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
          ),
        if (!_selectedFilters.contains(TaskQueryController.allFilter))
          const SizedBox(height: 8),

        /// TASK AREA
        Expanded(
          child: Consumer<PlanProvider>(
            builder: (context, planProvider, _) {
              return StreamBuilder<List<Plan>>(
                stream: planProvider.streamUserPlans(widget.userId),
                builder: (context, snapshot) {
                  final plans = snapshot.data ?? [];
                  final plannedTaskIds = <String>{};

                  for (final plan in plans) {
                    plannedTaskIds.addAll(plan.taskIds);
                  }

                  return Consumer<TaskProvider>(
                    builder: (context, taskProvider, _) {
                      final unplannedTasks = taskProvider.tasks
                          .where(
                            (task) => !plannedTaskIds.contains(task.taskId),
                          )
                          .toList();

                      final filteredTasks = _taskQueryController.applyQuery(
                        tasks: unplannedTasks,
                        selectedFilters: _selectedFilters,
                        sortBy: null,
                      );

                      Task? focusedTask;
                      for (final t in filteredTasks) {
                        if (_isInProgressStatus(t.taskStatus)) {
                          focusedTask = t;
                          break;
                        }
                      }
                      final hasFocusedTask = focusedTask != null;
                      final modeVisibleTasks = filteredTasks
                          .where(
                            (task) => modePolicy.taskVisible(
                              hasFocusedTask: hasFocusedTask,
                              isTaskFocused: _isInProgressStatus(
                                task.taskStatus,
                              ),
                            ),
                          )
                          .toList();
                      final frogTask = modePolicy.isEatTheFrog
                          ? _resolveFrogTask(modeVisibleTasks)
                          : null;
                      final displayTasks =
                          modePolicy.isEatTheFrog && hasFocusedTask
                          ? (frogTask == null ? <Task>[] : <Task>[frogTask])
                          : modeVisibleTasks;

                      /// ===== SHUFFLE MODE =====
                      if (_currentFlowStyle == MindSetModes.flowStyleShuffle) {
                        if (_completionPreviewTask != null) {
                          final completedTask = _completionPreviewTask!;
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'Task completed',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: TaskCard(
                                  task: completedTask,
                                  showFocusAction: false,
                                  showFocusInMainRow: false,
                                  showCheckboxWhenFocusedOnly: false,
                                  useStatusColor: true,
                                  isPomodoroMode: modePolicy.isPomodoro,
                                  showFrogBadge:
                                      modePolicy.isEatTheFrog &&
                                      frogTask != null &&
                                      frogTask.taskId == completedTask.taskId,
                                  onToggleDone: null,
                                ),
                              ),
                            ],
                          );
                        }

                        /// If already focused → show only that
                        if (focusedTask != null) {
                          final canToggleDone =
                              isSessionActive &&
                              modePolicy.doneAllowedOnTask(isFocused: true);
                          return Column(
                            children: [
                              if (modePolicy.isEatTheFrog)
                                _buildFrogHint(hasFocusedTask: true),
                              if (modePolicy.isChecklist) _buildChecklistHint(),
                              const Padding(
                                padding: EdgeInsets.only(top: 8, bottom: 4),
                                child: Text(
                                  '🔥 Currently Working On',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ListView(
                                  children: [
                                    TaskCard(
                                      task: focusedTask,
                                      showFocusAction: !isPomodoroBreak,
                                      showFocusInMainRow: true,
                                      showCheckboxWhenFocusedOnly: true,
                                      useStatusColor: true,
                                      isPomodoroMode: modePolicy.isPomodoro,
                                      showFrogBadge:
                                          modePolicy.isEatTheFrog &&
                                          frogTask != null &&
                                          frogTask.taskId == focusedTask.taskId,
                                      onPause:
                                          modePolicy.canPauseTask(
                                            isSessionActive: isSessionActive,
                                            isTaskFocused: true,
                                          )
                                          ? () => _pauseTask(focusedTask!)
                                          : null,
                                      onToggleDone: canToggleDone
                                          ? (isDone) => _toggleDoneForTask(
                                              focusedTask!,
                                              isDone,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        /// Otherwise → show Yes/No
                        if (_currentFlowTask == null ||
                            !displayTasks.any(
                              (t) => t.taskId == _currentFlowTask!.taskId,
                            )) {
                          _pickRandomFlowTask(displayTasks);
                        }

                        if (_currentFlowTask == null) {
                          return const Center(
                            child: Text(
                              'No more tasks available.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        final task = _currentFlowTask!;

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (modePolicy.isEatTheFrog)
                              _buildFrogHint(hasFocusedTask: false),
                            if (modePolicy.isChecklist) _buildChecklistHint(),
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: TaskCard(
                                task: task,
                                showFocusAction: false,
                                showFocusInMainRow: false,
                                showCheckboxWhenFocusedOnly: true,
                                useStatusColor: true,
                                isPomodoroMode: modePolicy.isPomodoro,
                                showFrogBadge:
                                    modePolicy.isEatTheFrog &&
                                    frogTask != null &&
                                    frogTask.taskId == task.taskId,
                                onToggleDone: null,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _rejectedTaskIds.add(task.taskId);
                                      _pickRandomFlowTask(displayTasks);
                                    });
                                  },
                                  child: const Text('No'),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton(
                                  onPressed: () async {
                                    if (modePolicy.canFocusTask(
                                      isSessionActive: isSessionActive,
                                      hasFocusedTask: hasFocusedTask,
                                      isTaskFocused: false,
                                    )) {
                                      await _focusTask(task);
                                    }
                                    setState(() {
                                      _rejectedTaskIds.clear();
                                      _currentFlowTask = null;
                                    });
                                  },
                                  child: const Text('Yes'),
                                ),
                              ],
                            ),
                          ],
                        );
                      }

                      /// ===== LIST MODE =====
                      if (displayTasks.isEmpty) {
                        return const Center(
                          child: Text(
                            'No tasks available.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          if (modePolicy.isEatTheFrog)
                            _buildFrogHint(hasFocusedTask: hasFocusedTask),
                          if (modePolicy.isChecklist) _buildChecklistHint(),
                          Expanded(
                            child: ListView.builder(
                              itemCount: displayTasks.length,
                              itemBuilder: (context, index) {
                                final task = displayTasks[index];
                                final isFocused = _isInProgressStatus(
                                  task.taskStatus,
                                );
                                final canFocus = modePolicy.canFocusTask(
                                  isSessionActive: isSessionActive,
                                  hasFocusedTask: hasFocusedTask,
                                  isTaskFocused: isFocused,
                                );
                                final canPause = modePolicy.canPauseTask(
                                  isSessionActive: isSessionActive,
                                  isTaskFocused: isFocused,
                                );
                                final canToggleDone =
                                    isSessionActive &&
                                    modePolicy.doneAllowedOnTask(
                                      isFocused: isFocused,
                                    );
                                final isFrogTask =
                                    frogTask != null &&
                                    frogTask.taskId == task.taskId;

                                return TaskCard(
                                  task: task,
                                  showFocusAction:
                                      !isPomodoroBreak &&
                                      (canFocus || canPause),
                                  showFocusInMainRow: true,
                                  showCheckboxWhenFocusedOnly: true,
                                  useStatusColor: true,
                                  isPomodoroMode: modePolicy.isPomodoro,
                                  showFrogBadge: isFrogTask,
                                  onFocus: canFocus
                                      ? () => _focusTask(task)
                                      : null,
                                  onPause: canPause
                                      ? () => _pauseTask(task)
                                      : null,
                                  onToggleDone: canToggleDone
                                      ? (isDone) =>
                                            _toggleDoneForTask(task, isDone)
                                      : null,
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
