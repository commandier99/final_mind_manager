import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/models/mind_set_session_model.dart';
import '../../../datasources/services/mind_set_session_service.dart';
import '../sections/mind_set_details_section.dart';
import '../mind_set_pomodoro_section.dart';
import '../on_the_spot/on_the_spot_task_stream.dart';
import '../follow_through/follow_through_task_stream.dart';
import '../go_with_the_flow/go_with_flow_task_stream.dart';
import '../../../../../shared/modes/mind_set_modes.dart';
import '../../../../../shared/modes/mind_set_mode_policy.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/presentation/widgets/cards/focused_task_card.dart';

class MindSetActiveSessionView extends StatefulWidget {
  final MindSetSession session;
  final bool showTimer;
  final Function(bool) onTimerToggle;
  final String taskCountMode;

  const MindSetActiveSessionView({
    super.key,
    required this.session,
    required this.showTimer,
    required this.onTimerToggle,
    required this.taskCountMode,
  });

  @override
  State<MindSetActiveSessionView> createState() =>
      _MindSetActiveSessionViewState();
}

class _MindSetActiveSessionViewState extends State<MindSetActiveSessionView>
    with SingleTickerProviderStateMixin {
  final MindSetSessionService _sessionService = MindSetSessionService();
  late AnimationController _sheetController;
  late Animation<double> _sheetAnimation;
  bool _isSheetExpanded = false;
  late ValueNotifier<Duration> _elapsedTimeNotifier;
  int _modeDropdownEpoch = 0;

  @override
  void initState() {
    super.initState();
    _sheetController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _sheetAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _sheetController, curve: Curves.easeInOut),
    );
    _elapsedTimeNotifier = ValueNotifier<Duration>(Duration.zero);
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _elapsedTimeNotifier.dispose();
    super.dispose();
  }

  void _toggleSheet() {
    if (_isSheetExpanded) {
      _sheetController.reverse();
    } else {
      _sheetController.forward();
    }
    setState(() {
      _isSheetExpanded = !_isSheetExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final modePolicy = MindSetModePolicy.fromMode(session.sessionMode);
    return Column(
      children: [
        Consumer<TaskProvider>(
          builder: (context, taskProvider, _) {
            return ValueListenableBuilder<Duration>(
              valueListenable: _elapsedTimeNotifier,
              builder: (context, elapsedTime, _) {
                // Calculate actual task counts based on session type
                int actualTasksDone = 0;
                int actualTasksCount = 0;

                if (session.sessionType == 'on_the_spot') {
                  final sessionTasks = taskProvider.tasks
                      .where(
                        (task) => session.sessionTaskIds.contains(task.taskId),
                      )
                      .toList();
                  actualTasksCount = sessionTasks.length;
                  actualTasksDone = sessionTasks
                      .where((t) => t.taskIsDone)
                      .length;
                } else if (session.sessionType == 'follow_through') {
                  final sessionTasks = taskProvider.tasks
                      .where(
                        (task) => session.sessionTaskIds.contains(task.taskId),
                      )
                      .toList();
                  actualTasksCount = sessionTasks.length;
                  actualTasksDone = sessionTasks
                      .where((t) => t.taskIsDone)
                      .length;
                } else if (session.sessionType == 'go_with_flow') {
                  actualTasksCount = taskProvider.tasks.length;
                  actualTasksDone = taskProvider.tasks
                      .where((t) => t.taskIsDone)
                      .length;
                }

                return MindSetDetails(
                  title: session.sessionTitle,
                  description: session.sessionPurpose,
                  labelText: _getSessionLabel(session.sessionType),
                  sessionStartedAt: session.sessionStartedAt,
                  selectedMode: session.sessionMode,
                  onModeChanged: (value) => _updateSessionMode(session, value),
                  timerElapsed: elapsedTime,
                  onTimerPersist: (elapsed) {
                    _elapsedTimeNotifier.value = elapsed;
                  },
                  isTimerEnabled: session.sessionStatus == 'active',
                  showTimerControls: false,
                  showTimer: widget.showTimer,
                  primaryActionLabel: null,
                  primaryActionIcon: null,
                  onPrimaryAction: null,
                  tasksDoneCount: actualTasksDone,
                  tasksCount: actualTasksCount,
                  taskCountMode: widget.taskCountMode,
                  modeDropdownKey: ValueKey(
                    'mode_dropdown_${session.sessionId}_${session.sessionMode}_$_modeDropdownEpoch',
                  ),
                );
              },
            );
          },
        ),
        if (modePolicy.isPomodoro)
          MindSetPomodoroSection(
            session: session,
            onPomodoroComplete: () => _handlePomodoroComplete(session),
            onBreakComplete: () => _handleBreakComplete(session),
          ),
        Expanded(child: _buildSessionBody(session)),
        Consumer<TaskProvider>(
          builder: (context, taskProvider, _) {
            Task? focusedTask;
            for (final task in taskProvider.tasks) {
              if (_isInProgressStatus(task.taskStatus)) {
                focusedTask = task;
                break;
              }
            }

            if (focusedTask != null) {
              final activeTask = focusedTask;
              return FocusedTaskCard(
                task: activeTask,
                onPause: modePolicy.allowsPauseWhileFocused()
                    ? () => _pauseTask(taskProvider, activeTask)
                    : null,
                isPomodoroMode: modePolicy.isPomodoro,
                onToggleDone: modePolicy.doneAllowedOnTask(isFocused: true)
                    ? (isDone) => _toggleTaskDone(
                        taskProvider,
                        activeTask,
                        isDone ?? false,
                      )
                    : null,
              );
            }
            return const SizedBox.shrink();
          },
        ),
        if (session.sessionStatus == 'active')
          AnimatedBuilder(
            animation: _sheetAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag Handle
                      GestureDetector(
                        onTap: _toggleSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            children: [
                              AnimatedRotation(
                                turns: _isSheetExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  Icons.expand_less,
                                  color: Colors.grey[600],
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // End Session Button - Shows when expanded
                      if (_isSheetExpanded)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 8.0,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _confirmEndSession(session),
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: const Text('End Session'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[400],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSessionBody(MindSetSession session) {
    switch (session.sessionType) {
      case 'on_the_spot':
        return Padding(
          padding: const EdgeInsets.all(8),
          child: OnTheSpotTaskStream(
            sessionId: session.sessionId,
            sessionTaskIds: session.sessionTaskIds,
            mode: session.sessionMode,
            isSessionActive: session.sessionStatus == 'active',
            session: session,
          ),
        );
      case 'go_with_flow':
        return GoWithFlowTaskStream(
          userId: session.sessionUserId,
          mode: session.sessionMode,
          session: session,
        );
      case 'follow_through':
        return FollowThroughTaskStream(
          taskIds: session.sessionTaskIds,
          mode: session.sessionMode,
          session: session,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _updateSessionMode(
    MindSetSession session,
    String newMode,
  ) async {
    if (newMode == session.sessionMode) return;

    final currentModePolicy = MindSetModePolicy.fromMode(session.sessionMode);
    final stats = session.sessionStats;
    final pomodoroBusy =
        (stats.pomodoroIsRunning ?? false) ||
        (stats.pomodoroIsOnBreak ?? false);
    if (currentModePolicy.isPomodoro && pomodoroBusy) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pomodoro In Progress'),
          content: const Text(
            'You can only change mode between Pomodoro focus sessions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Okay'),
            ),
          ],
        ),
      );
      if (mounted) {
        setState(() {
          _modeDropdownEpoch++;
        });
      }
      return;
    }

    final taskProvider = context.read<TaskProvider>();

    // 🔒 Check if any task is currently focused
    final hasFocusedTask = taskProvider.tasks.any(
      (task) => _isModeLockedTaskStatus(task.taskStatus),
    );

    if (hasFocusedTask) {
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Finish or Pause Task First'),
          content: const Text(
            'You cannot change the session mode while a task is being focused.\n\n'
            'Pause or complete the current task first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Okay'),
            ),
          ],
        ),
      );

      if (mounted) {
        setState(() {
          _modeDropdownEpoch++;
        });
      }
      return; // 🚫 Stop mode change
    }

    // ✅ Safe to change mode
    final updatedHistory = [
      ...session.sessionModeHistory,
      MindSetModeChange(mode: newMode, changedAt: DateTime.now()),
    ];

    await _sessionService.updateSession(
      session.copyWith(
        sessionMode: newMode,
        sessionModeHistory: updatedHistory,
      ),
    );
  }

  Future<void> _endSession(String sessionId) async {
    final taskProvider = context.read<TaskProvider>();

    // Get session from Firestore
    final session = await _sessionService
        .streamUserSessions(widget.session.sessionUserId)
        .first
        .then(
          (sessions) => sessions.firstWhere(
            (s) => s.sessionId == sessionId,
            orElse: () => widget.session,
          ),
        );

    final now = DateTime.now();

    // 1️⃣ Pause all focused tasks
    final focusedTasks = taskProvider.tasks
        .where((task) => _isInProgressStatus(task.taskStatus))
        .toList();

    for (final task in focusedTasks) {
      await taskProvider.updateTask(task.copyWith(taskStatus: 'Paused'));
    }

    // 2️⃣ Calculate session duration
    final startedAt = session.sessionStartedAt ?? session.sessionCreatedAt;
    final duration = now.difference(startedAt);

    // 3️⃣ Calculate session task stats
    final sessionTasks = _sessionTasksForSummary(taskProvider, session);

    final tasksTotal = sessionTasks.length;
    final tasksDone = sessionTasks.where((task) => task.taskIsDone).length;

    // 4️⃣ Update session with computed stats
    await _sessionService.updateSession(
      session.copyWith(
        sessionStatus: 'completed',
        sessionEndedAt: now,
        sessionStats: session.sessionStats.copyWith(
          tasksTotalCount: tasksTotal,
          tasksDoneCount: tasksDone,
          sessionFocusDurationMinutes: duration.inMinutes,
          sessionFocusDurationSeconds: duration.inSeconds,
        ),
      ),
    );

    // 5️⃣ Log completion event properly
    await _sessionService.endSession(sessionId, now);
  }

  Future<void> _confirmEndSession(MindSetSession session) async {
    final taskProvider = context.read<TaskProvider>();
    final sessionTasks = _sessionTasksForSummary(taskProvider, session);
    await _showSessionSummaryAndEnd(session, sessionTasks);
  }

  String _getSessionLabel(String sessionType) {
    switch (sessionType) {
      case 'on_the_spot':
        return 'On the Spot';
      case 'go_with_flow':
        return 'Go with the Flow';
      case 'follow_through':
        return 'Follow Through';
      default:
        return 'Mind:Set';
    }
  }

  bool _isModeLockedTaskStatus(String status) {
    final normalized = status.toUpperCase().replaceAll(' ', '_');
    return normalized == 'IN_PROGRESS' || normalized == 'FOCUSED';
  }

  bool _isInProgressStatus(String status) {
    return status.toUpperCase().replaceAll(' ', '_') == 'IN_PROGRESS';
  }

  Future<PomodoroTransition> _handlePomodoroComplete(
    MindSetSession session,
  ) async {
    final taskProvider = context.read<TaskProvider>();
    Task? focusedTask;
    for (final task in taskProvider.tasks) {
      if (_isInProgressStatus(task.taskStatus)) {
        focusedTask = task;
        break;
      }
    }

    if (focusedTask == null) {
      return PomodoroTransition.startBreak;
    }

    if (!mounted) return PomodoroTransition.startBreak;

    final finishedTask = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Focus Session Complete'),
        content: Text('Did you finish "${focusedTask!.taskTitle}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Finished'),
          ),
        ],
      ),
    );

    if (finishedTask == true) {
      await taskProvider.updateTask(
        focusedTask.copyWith(
          taskIsDone: true,
          taskStatus: 'COMPLETED',
          taskIsDoneAt: DateTime.now(),
        ),
      );
      await _logSessionAction(type: 'complete', task: focusedTask);
    } else {
      await taskProvider.updateTask(focusedTask.copyWith(taskStatus: 'Paused'));
      await _logSessionAction(type: 'pause', task: focusedTask);
    }

    return PomodoroTransition.startBreak;
  }

  Future<void> _handleBreakComplete(MindSetSession session) async {
    if (session.sessionActiveTaskId == null) return;
    await _sessionService.updateSession(
      session.copyWith(sessionActiveTaskId: null),
    );
  }

  Future<void> _logSessionAction({
    required String type,
    required Task task,
  }) async {
    final session = widget.session;
    final runtimeMode = MindSetModes.resolveRuntimeMode(session.sessionMode);
    final stats = session.sessionStats;

    var nextStats = stats;
    if (type == 'pause') {
      nextStats = nextStats.copyWith(
        pauseCount: (nextStats.pauseCount ?? 0) + 1,
      );
    } else if (type == 'complete') {
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
    } else {
      return;
    }

    await _sessionService.updateSession(
      session.copyWith(
        sessionActions: [
          ...session.sessionActions,
          MindSetSessionAction(
            type: type,
            taskId: task.taskId,
            mode: runtimeMode,
            at: DateTime.now(),
          ),
        ],
        sessionStats: nextStats,
      ),
    );
  }

  Future<void> _pauseTask(TaskProvider taskProvider, Task focusedTask) async {
    final updatedTask = focusedTask.copyWith(taskStatus: 'Paused');
    await taskProvider.updateTask(updatedTask);
    await _logSessionAction(type: 'pause', task: focusedTask);
  }

  Future<void> _toggleTaskDone(
    TaskProvider taskProvider,
    Task focusedTask,
    bool isDone,
  ) async {
    final updatedTask = focusedTask.copyWith(
      taskIsDone: isDone,
      taskIsDoneAt: isDone ? DateTime.now() : null,
      taskStatus: isDone ? 'COMPLETED' : focusedTask.taskStatus,
    );
    await taskProvider.updateTask(updatedTask);
    if (isDone) {
      await _logSessionAction(type: 'complete', task: focusedTask);
      await _handlePostCompletion(taskProvider, focusedTask);
    }
  }

  Future<void> _handlePostCompletion(
    TaskProvider taskProvider,
    Task completedTask,
  ) async {
    final session = widget.session;
    final remainingTasks = _remainingSessionTasks(
      taskProvider,
      session,
      completedTask.taskId,
    );

    if (remainingTasks.isEmpty) {
      if (session.sessionType == 'on_the_spot') {
        final addMoreTasks = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('All Tasks Completed'),
            content: const Text(
              'Great work. Do you want to add more tasks to this session?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Finish Session'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add More Tasks'),
              ),
            ],
          ),
        );

        if (addMoreTasks == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Use the + button in tasks to add more before ending.',
              ),
            ),
          );
          return;
        }
      }

      final sessionTasks = _sessionTasksForSummary(taskProvider, session);
      await _showSessionSummaryAndEnd(session, sessionTasks);
      return;
    }

    if (!mounted) return;
    final isPomodoro =
        MindSetModes.resolveRuntimeMode(session.sessionMode) ==
        MindSetModes.pomodoro;
    if (!isPomodoro) {
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
      await _startBreakNow(session);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Break started.')));
      return;
    }

    await _pausePomodoroIfNeeded(session);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Timer paused. Focus another task to resume.'),
        ),
      );
    }
  }

  List<Task> _remainingSessionTasks(
    TaskProvider taskProvider,
    MindSetSession session,
    String completedTaskId,
  ) {
    final tasks = taskProvider.tasks;
    if (session.sessionType == 'go_with_flow') {
      return tasks
          .where((task) => !task.taskIsDone && task.taskId != completedTaskId)
          .toList();
    }

    return tasks
        .where(
          (task) =>
              session.sessionTaskIds.contains(task.taskId) &&
              !task.taskIsDone &&
              task.taskId != completedTaskId,
        )
        .toList();
  }

  List<Task> _sessionTasksForSummary(
    TaskProvider taskProvider,
    MindSetSession session,
  ) {
    final tasks = taskProvider.tasks;
    if (session.sessionType == 'go_with_flow') {
      return List<Task>.from(tasks);
    }
    return tasks
        .where((task) => session.sessionTaskIds.contains(task.taskId))
        .toList();
  }

  Future<void> _showSessionSummaryAndEnd(
    MindSetSession session,
    List<Task> sessionTasks,
  ) async {
    if (!mounted) return;
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
    await _endSession(session.sessionId);
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

  Future<void> _pausePomodoroIfNeeded(MindSetSession session) async {
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

  Future<void> _startBreakNow(MindSetSession session) async {
    final runtimeMode = MindSetModes.resolveRuntimeMode(session.sessionMode);
    if (runtimeMode != MindSetModes.pomodoro) return;

    final stats = session.sessionStats;
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
}
