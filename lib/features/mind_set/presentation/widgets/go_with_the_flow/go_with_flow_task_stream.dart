import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/presentation/widgets/cards/task_card.dart';
import '../../../../../shared/modes/mind_set_modes.dart';
import '../../../../../shared/modes/mind_set_mode_policy.dart';
import '../../../datasources/models/mind_set_session_model.dart';
import '../../../datasources/services/mind_set_session_service.dart';
import '/features/plans/datasources/models/plans_model.dart';
import '/features/plans/datasources/providers/plan_provider.dart';

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

  Task? _currentFlowTask;
  final Set<String> _rejectedTaskIds = {};
  late String _currentFlowStyle;

  @override
  void initState() {
    super.initState();
    _currentFlowStyle = widget.session?.sessionFlowStyle ?? 'list';
    _streamTasks();
  }

  void _streamTasks() {
    final taskProvider = context.read<TaskProvider>();
    taskProvider.streamUserActiveTasks(widget.userId);
  }

  String _normalizeStatus(String status) =>
      status.toUpperCase().replaceAll(' ', '_');

  bool _isInProgressStatus(String status) =>
      _normalizeStatus(status) == 'IN_PROGRESS';

  Future<void> _logSessionAction({
    required String type,
    required Task task,
    Task? fromTask,
  }) async {
    final session = widget.session;
    if (session == null) return;

    final runtimeMode = MindSetModes.resolveRuntimeMode(session.sessionMode);
    final stats = session.sessionStats;
    final workedTaskIds = session.sessionWorkedTaskIds;
    final actions = session.sessionActions;

    var nextStats = stats;
    var nextWorkedTaskIds = workedTaskIds;

    if (type == 'focus' || type == 'switch') {
      final wasWorked = workedTaskIds.contains(task.taskId);
      if (!wasWorked) {
        nextWorkedTaskIds = [...workedTaskIds, task.taskId];
        nextStats = nextStats.copyWith(
          tasksWorkedCount: (stats.tasksWorkedCount ?? 0) + 1,
        );
      }
      nextStats = nextStats.copyWith(
        focusCount: (nextStats.focusCount ?? 0) + 1,
      );
    }

    if (type == 'pause') {
      nextStats = nextStats.copyWith(
        pauseCount: (nextStats.pauseCount ?? 0) + 1,
      );
    }

    if (type == 'switch') {
      nextStats = nextStats.copyWith(
        switchCount: (nextStats.switchCount ?? 0) + 1,
      );
    }

    if (type == 'complete') {
      if (runtimeMode == MindSetModes.checklist) {
        nextStats = nextStats.copyWith(
          checklistCompletedCount: (nextStats.checklistCompletedCount ?? 0) + 1,
        );
      } else if (runtimeMode == MindSetModes.pomodoro) {
        nextStats = nextStats.copyWith(
          pomodoroCompletedCount: (nextStats.pomodoroCompletedCount ?? 0) + 1,
        );
      } else if (runtimeMode == MindSetModes.eatTheFrog) {
        nextStats = nextStats.copyWith(
          eatTheFrogCompletedCount:
              (nextStats.eatTheFrogCompletedCount ?? 0) + 1,
        );
      }
    }

    await _sessionService.updateSession(
      session.copyWith(
        sessionWorkedTaskIds: nextWorkedTaskIds,
        sessionActions: [
          ...actions,
          MindSetSessionAction(
            type: type,
            taskId: task.taskId,
            mode: runtimeMode,
            at: DateTime.now(),
            fromTaskId: fromTask?.taskId,
          ),
        ],
        sessionStats: nextStats,
      ),
    );
  }

  void _pickRandomFlowTask(List<Task> tasks) {
    final available = tasks
        .where(
          (t) =>
              !_rejectedTaskIds.contains(t.taskId) &&
              !t.taskIsDone &&
              !_isInProgressStatus(t.taskStatus),
        )
        .toList();

    if (available.isEmpty) {
      _currentFlowTask = null;
      return;
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
    final runtimeMode = MindSetModes.resolveRuntimeMode(session.sessionMode);
    if (runtimeMode != MindSetModes.pomodoro) return;

    final stats = session.sessionStats;
    final alreadyRunningFocus =
        (stats.pomodoroIsRunning ?? false) &&
        !(stats.pomodoroIsOnBreak ?? false);
    if (alreadyRunningFocus) return;

    final focusMinutes = (stats.pomodoroFocusMinutes ?? 25) > 0
        ? (stats.pomodoroFocusMinutes ?? 25)
        : 25;
    final resumeRemaining =
        (!(stats.pomodoroIsOnBreak ?? false) &&
            (stats.pomodoroRemainingSeconds ?? 0) > 0)
        ? stats.pomodoroRemainingSeconds!
        : focusMinutes * 60;

    await _sessionService.updateSession(
      session.copyWith(
        sessionStats: stats.copyWith(
          pomodoroIsRunning: true,
          pomodoroIsOnBreak: false,
          pomodoroIsLongBreak: false,
          pomodoroRemainingSeconds: resumeRemaining,
          pomodoroLastUpdatedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _pauseTask(Task task) async {
    final taskProvider = context.read<TaskProvider>();
    await taskProvider.updateTask(task.copyWith(taskStatus: 'Paused'));
    await _logSessionAction(type: 'pause', task: task);
  }

  Future<void> _toggleDoneForTask(Task task, bool? isDone) async {
    final taskProvider = context.read<TaskProvider>();
    final markDone = isDone ?? false;
    await taskProvider.toggleTaskDone(
      task.copyWith(
        taskIsDone: markDone,
        taskStatus: markDone ? 'COMPLETED' : 'To Do',
      ),
    );
    if (markDone) {
      await _logSessionAction(type: 'complete', task: task);
      await _handlePostCompletion(task);
    }
  }

  Future<void> _handlePostCompletion(Task completedTask) async {
    if (!mounted) return;
    final taskProvider = context.read<TaskProvider>();
    final planProvider = context.read<PlanProvider>();
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

    final sessionId = widget.session?.sessionId;
    if (remainingTasks.isEmpty) {
      final sessionTasks = taskProvider.tasks
          .where((task) => !plannedTaskIds.contains(task.taskId))
          .toList();
      await _showSessionSummaryAndEnd(sessionTasks, sessionId);
      return;
    }

    final session = widget.session;
    final isPomodoro =
        session != null &&
        MindSetModes.resolveRuntimeMode(session.sessionMode) ==
            MindSetModes.pomodoro;

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

  Future<void> _showSessionSummaryAndEnd(
    List<Task> sessionTasks,
    String? sessionId,
  ) async {
    final session = widget.session;
    if (session == null || !mounted) return;

    final now = DateTime.now();
    final startedAt = session.sessionStartedAt ?? session.sessionCreatedAt;
    final duration = now.difference(startedAt);
    final tasksTotal = sessionTasks.length;
    final tasksDone = sessionTasks.where((task) => task.taskIsDone).length;
    final completionRate = tasksTotal == 0
        ? 100
        : ((tasksDone / tasksTotal) * 100).round();

    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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

    if (shouldFinish != true) return;

    await _sessionService.updateSession(
      session.copyWith(
        sessionStatus: 'completed',
        sessionEndedAt: now,
        sessionStats: session.sessionStats.copyWith(
          tasksTotalCount: tasksTotal,
          tasksDoneCount: tasksDone,
          sessionFocusDurationMinutes: duration.inMinutes,
          sessionFocusDurationSeconds: duration.inSeconds,
          pomodoroIsRunning: false,
        ),
      ),
    );
    if (sessionId != null) {
      await _sessionService.endSession(sessionId, now);
    }
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
    final stats = session.sessionStats;
    final runtimeMode = MindSetModes.resolveRuntimeMode(session.sessionMode);
    if (runtimeMode != MindSetModes.pomodoro) return;

    final breakMinutes = stats.pomodoroBreakMinutes ?? 5;
    final longBreakMinutes = stats.pomodoroLongBreakMinutes ?? 60;
    final targetCount = stats.pomodoroTargetCount ?? 4;
    final completedCount = stats.pomodoroCount ?? 0;

    final nextCompleted = completedCount + 1;
    final isLongBreak = targetCount > 0 && nextCompleted % targetCount == 0;
    final nextBreakMinutes = isLongBreak ? longBreakMinutes : breakMinutes;

    await _sessionService.updateSession(
      session.copyWith(
        sessionStats: stats.copyWith(
          pomodoroCount: nextCompleted,
          pomodoroIsRunning: true,
          pomodoroIsOnBreak: true,
          pomodoroIsLongBreak: isLongBreak,
          pomodoroRemainingSeconds: nextBreakMinutes * 60,
          pomodoroLastUpdatedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _pausePomodoroIfNeeded() async {
    final session = widget.session;
    if (session == null) return;
    final runtimeMode = MindSetModes.resolveRuntimeMode(session.sessionMode);
    if (runtimeMode != MindSetModes.pomodoro) return;

    final stats = session.sessionStats;
    if (!(stats.pomodoroIsRunning ?? false)) return;

    final focusMinutes = (stats.pomodoroFocusMinutes ?? 25) > 0
        ? (stats.pomodoroFocusMinutes ?? 25)
        : 25;
    final breakMinutes = stats.pomodoroBreakMinutes ?? 5;
    final longBreakMinutes = stats.pomodoroLongBreakMinutes ?? 60;

    final fallbackRemaining =
        ((stats.pomodoroIsOnBreak ?? false)
            ? ((stats.pomodoroIsLongBreak ?? false)
                  ? longBreakMinutes
                  : breakMinutes)
            : focusMinutes) *
        60;
    final baseRemaining = (stats.pomodoroRemainingSeconds ?? 0) > 0
        ? stats.pomodoroRemainingSeconds!
        : fallbackRemaining;
    final lastUpdated = stats.pomodoroLastUpdatedAt;
    final elapsed = lastUpdated == null
        ? 0
        : DateTime.now().difference(lastUpdated).inSeconds;
    final nextRemaining = (baseRemaining - elapsed)
        .clamp(0, baseRemaining)
        .toInt();

    await _sessionService.updateSession(
      session.copyWith(
        sessionStats: stats.copyWith(
          pomodoroIsRunning: false,
          pomodoroRemainingSeconds: nextRemaining,
          pomodoroLastUpdatedAt: DateTime.now(),
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

              /// FILTER BUTTON (placeholder)
              Icon(Icons.filter_list, size: 18, color: Colors.grey[700]),

              const SizedBox(width: 12),

              /// FLOW STYLE TOGGLE
              InkWell(
                onTap: () async {
                  final newStyle = _currentFlowStyle == 'shuffle'
                      ? 'list'
                      : 'shuffle';

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
                  _currentFlowStyle == 'shuffle'
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

                      final visibleTasks = unplannedTasks;

                      /// APPLY FILTERS HERE LATER
                      final filteredTasks = visibleTasks;

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
                      final displayTasks = modePolicy.isEatTheFrog &&
                              hasFocusedTask
                          ? (frogTask == null ? <Task>[] : <Task>[frogTask])
                          : modeVisibleTasks;

                      /// ===== SHUFFLE MODE =====
                      if (_currentFlowStyle == 'shuffle') {
                        /// If already focused → show only that
                        if (focusedTask != null) {
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
                                          frogTask.taskId ==
                                              focusedTask.taskId,
                                      onPause:
                                          modePolicy.canPauseTask(
                                            isSessionActive: isSessionActive,
                                            isTaskFocused: true,
                                          )
                                          ? () => _pauseTask(focusedTask!)
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
                            _buildFrogHint(
                              hasFocusedTask: hasFocusedTask,
                            ),
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
                                      !isPomodoroBreak && (canFocus || canPause),
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
