import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/presentation/widgets/cards/task_card.dart';
import '../../../../../shared/modes/mind_set_modes.dart';
import '../../../../../shared/modes/mind_set_mode_policy.dart';
import '../../../datasources/models/mind_set_session_model.dart';
import '../../../datasources/services/mind_set_session_service.dart';

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
  final MindSetSessionService _sessionService = MindSetSessionService();
  String _sortBy = 'created_desc'; // format: 'field_direction'

  @override
  void initState() {
    super.initState();
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

  String _normalizeStatus(String status) {
    return status.toUpperCase().replaceAll(' ', '_');
  }

  bool _isInProgressStatus(String status) {
    return _normalizeStatus(status) == 'IN_PROGRESS';
  }

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

  Future<void> _focusTask(Task task) async {
    if (task.taskIsDone) return;
    if (_isInProgressStatus(task.taskStatus)) return;
    final isPomodoro = MindSetModePolicy.fromMode(widget.mode).isPomodoro;

    final taskProvider = context.read<TaskProvider>();
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

        if (shouldPause != true) return;
      }

      await taskProvider.updateTask(activeTask.copyWith(taskStatus: 'Paused'));
      await _logSessionAction(type: 'switch', task: task, fromTask: activeTask);
    }

    await taskProvider.updateTask(task.copyWith(taskStatus: 'In Progress'));
    await _startPomodoroIfNeeded();
    if (focusedTask == null) {
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
    if (!_isInProgressStatus(task.taskStatus)) return;
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
    final remainingTasks = taskProvider.tasks
        .where(
          (task) =>
              widget.taskIds.contains(task.taskId) &&
              task.taskId != completedTask.taskId &&
              !task.taskIsDone,
        )
        .toList();

    final sessionId = widget.session?.sessionId;
    if (remainingTasks.isEmpty) {
      final sessionTasks = taskProvider.tasks
          .where((task) => widget.taskIds.contains(task.taskId))
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
                    onSelected: (value) {
                      // TODO: Implement filter
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'status',
                        child: Text('Status'),
                      ),
                    ],
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

              final tasks = _sortTasksByPlan(
                taskProvider.tasks,
                widget.taskIds,
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
                            modePolicy.doneAllowedOnTask(isFocused: isFocused);
                        final isFrogTask =
                            frogTask != null && frogTask.taskId == task.taskId;

                        return TaskCard(
                          task: task,
                          showFocusAction:
                              !isPomodoroBreak && (canFocus || canPause),
                          showFocusInMainRow: true,
                          showCheckboxWhenFocusedOnly: true,
                          useStatusColor: true,
                          isPomodoroMode: modePolicy.isPomodoro,
                          showFrogBadge: isFrogTask,
                          onFocus: canFocus ? () => _focusTask(task) : null,
                          onPause: canPause ? () => _pauseTask(task) : null,
                          onToggleDone: canToggleDone
                              ? (isDone) => _toggleDoneForTask(task, isDone)
                              : null,
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

  List<Task> _sortTasksByPlan(List<Task> tasks, List<String> order) {
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

    // Apply secondary sorting based on _sortBy
    return _applySorting(sorted);
  }

  List<Task> _applySorting(List<Task> tasks) {
    final sorted = [...tasks];

    try {
      switch (_sortBy) {
        case 'priority_asc':
          sorted.sort(
            (a, b) => _priorityToInt(
              a.taskPriorityLevel,
            ).compareTo(_priorityToInt(b.taskPriorityLevel)),
          );
          break;
        case 'priority_desc':
          sorted.sort(
            (a, b) => _priorityToInt(
              b.taskPriorityLevel,
            ).compareTo(_priorityToInt(a.taskPriorityLevel)),
          );
          break;
        case 'alphabetical_asc':
          sorted.sort(
            (a, b) =>
                a.taskTitle.toLowerCase().compareTo(b.taskTitle.toLowerCase()),
          );
          break;
        case 'alphabetical_desc':
          sorted.sort(
            (a, b) =>
                b.taskTitle.toLowerCase().compareTo(a.taskTitle.toLowerCase()),
          );
          break;
        case 'created_asc':
          sorted.sort((a, b) => a.taskCreatedAt.compareTo(b.taskCreatedAt));
          break;
        case 'created_desc':
          sorted.sort((a, b) => b.taskCreatedAt.compareTo(a.taskCreatedAt));
          break;
        case 'deadline_asc':
          sorted.sort((a, b) {
            final aDeadline = a.taskDeadline ?? DateTime(2099);
            final bDeadline = b.taskDeadline ?? DateTime(2099);
            return aDeadline.compareTo(bDeadline);
          });
          break;
        case 'deadline_desc':
          sorted.sort((a, b) {
            final aDeadline = a.taskDeadline ?? DateTime(1970);
            final bDeadline = b.taskDeadline ?? DateTime(1970);
            return bDeadline.compareTo(aDeadline);
          });
          break;
        default:
          break;
      }
    } catch (e) {
      // If sorting fails, return unsorted list
      return tasks;
    }

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
