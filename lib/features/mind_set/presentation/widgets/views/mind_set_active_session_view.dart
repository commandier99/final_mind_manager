import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/models/mind_set_session_model.dart';
import '../../../datasources/services/mind_set_session_runtime_service.dart';
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
import '../../../../tasks/presentation/widgets/sections/task_steps_list.dart';
import '../../../../steps/datasources/providers/step_provider.dart';
import '../../utils/session_task_submission_helper.dart';

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
  final MindSetSessionRuntimeService _runtimeService =
      MindSetSessionRuntimeService();
  late AnimationController _sheetController;
  late Animation<double> _sheetAnimation;
  bool _isSheetExpanded = false;
  late ValueNotifier<Duration> _elapsedTimeNotifier;
  int _modeDropdownEpoch = 0;
  bool _followThroughAutoSummaryPrompted = false;
  String? _followThroughAutoSummarySessionId;
  final StepProvider _focusedTaskStepProvider = StepProvider();
  final Map<String, DateTime> _focusedTaskStartedAtById = <String, DateTime>{};

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
    _elapsedTimeNotifier = ValueNotifier<Duration>(_sessionElapsedNow(widget.session));
  }

  @override
  void didUpdateWidget(covariant MindSetActiveSessionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.sessionId != widget.session.sessionId ||
        oldWidget.session.sessionStartedAt != widget.session.sessionStartedAt ||
        oldWidget.session.sessionCreatedAt != widget.session.sessionCreatedAt) {
      _elapsedTimeNotifier.value = _sessionElapsedNow(widget.session);
    }
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _elapsedTimeNotifier.dispose();
    _focusedTaskStepProvider.dispose();
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
                  _maybeAutoPromptFollowThroughSummary(
                    session,
                    sessionTasks,
                    actualTasksDone,
                    actualTasksCount,
                    taskProvider,
                  );
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
              final usesThoughtSubmit = SessionTaskSubmissionHelper
                  .shouldUseThoughtSubmit(context, activeTask);
              final canMarkDone = SessionTaskSubmissionHelper.canMarkTaskDone(
                context,
                activeTask,
              );
              _focusedTaskStartedAtById.putIfAbsent(
                activeTask.taskId,
                DateTime.now,
              );
              _focusedTaskStartedAtById.removeWhere(
                (taskId, _) => taskId != activeTask.taskId,
              );
              return FocusedTaskCard(
                task: activeTask,
                focusedStartedAt: _focusedTaskStartedAtById[activeTask.taskId]!,
                onPause: modePolicy.allowsPauseWhileFocused()
                    ? () => _pauseTask(taskProvider, activeTask)
                    : null,
                isPomodoroMode: modePolicy.isPomodoro,
                onToggleDone:
                    modePolicy.doneAllowedOnTask(isFocused: true) &&
                        !usesThoughtSubmit &&
                        canMarkDone
                    ? (isDone) => _toggleTaskDone(
                        taskProvider,
                        activeTask,
                        isDone ?? false,
                      )
                    : null,
                onSubmitThought:
                    modePolicy.doneAllowedOnTask(isFocused: true) &&
                        usesThoughtSubmit
                    ? () => _toggleThoughtSubmit(activeTask)
                    : null,
                stepsContent: ChangeNotifierProvider<StepProvider>.value(
                  value: _focusedTaskStepProvider,
                  child: TaskStepsList(
                    parentTaskId: activeTask.taskId,
                    boardId: activeTask.taskBoardId,
                    task: activeTask,
                    contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    allowCompletionToggle: true,
                  ),
                ),
              );
            }
            _focusedTaskStartedAtById.clear();
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

    final newModePolicy = MindSetModePolicy.fromMode(newMode);
    widget.onTimerToggle(!newModePolicy.hidesSessionTimer);
  }

  Duration _sessionElapsedNow(MindSetSession session) {
    final base = session.sessionStartedAt ?? session.sessionCreatedAt;
    final elapsed = DateTime.now().difference(base);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  Future<void> _endSession(
    MindSetSession session,
    TaskProvider taskProvider,
    List<Task> sessionTasks,
  ) async {
    final now = DateTime.now();

    // 1️⃣ Pause all focused tasks
    final focusedTasks = taskProvider.tasks
        .where((task) => _isInProgressStatus(task.taskStatus))
        .toList();

    for (final task in focusedTasks) {
      await taskProvider.updateTask(task.copyWith(taskStatus: 'Paused'));
    }
    await _pausePomodoroIfNeeded(session);

    final tasksTotal = sessionTasks.length;
    final tasksDone = sessionTasks.where((task) => task.taskIsDone).length;

    // 3) Persist completed session + completion event in one call
    await _sessionService.completeSession(
      session: session,
      endedAt: now,
      tasksTotal: tasksTotal,
      tasksDone: tasksDone,
    );
  }

  Future<void> _confirmEndSession(MindSetSession session) async {
    final taskProvider = context.read<TaskProvider>();
    final sessionTasks = _sessionTasksForSummary(taskProvider, session);
    await _showSessionSummaryAndEnd(session, taskProvider, sessionTasks);
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
    return _runtimeService.isInProgressStatus(status);
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
        title: Text(
          focusedTask!.taskRequiresSubmission
              ? 'Focus Session Complete'
              : 'Focus Session Complete',
        ),
        content: Text(
          focusedTask.taskRequiresSubmission
              ? 'Ready to submit a thought for "${focusedTask.taskTitle}"?'
              : 'Did you finish "${focusedTask.taskTitle}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              focusedTask.taskRequiresSubmission ? 'Not Yet' : 'Not Yet',
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              focusedTask.taskRequiresSubmission
                  ? 'Yes, Submit Thought'
                  : 'Yes, Finished',
            ),
          ),
        ],
      ),
    );

    if (!mounted) return PomodoroTransition.startBreak;

    if (finishedTask == true) {
      if (SessionTaskSubmissionHelper.shouldUseThoughtSubmit(
        context,
        focusedTask,
      )) {
        await _toggleThoughtSubmit(focusedTask);
        return PomodoroTransition.startBreak;
      }
      try {
        await taskProvider.toggleTaskDone(
          focusedTask.copyWith(
            taskIsDone: true,
            taskStatus: 'Completed',
            taskIsDoneAt: DateTime.now(),
          ),
        );
        await _logSessionAction(type: 'complete', task: focusedTask);
      } on StateError catch (e) {
        if (!mounted) return PomodoroTransition.startBreak;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message.toString()),
          ),
        );
      }
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
    if (type != 'pause' && type != 'complete') return;
    await _runtimeService.logSessionAction(
      session: session,
      type: type,
      taskId: task.taskId,
    );
  }

  Future<void> _pauseTask(TaskProvider taskProvider, Task focusedTask) async {
    final updatedTask = focusedTask.copyWith(taskStatus: 'Paused');
    await taskProvider.updateTask(updatedTask);
    await _maybeCreateSessionCheckpointStep(
      focusedTask,
      reason: 'Worked in session but paused before completion.',
      elapsedDuration: _consumeElapsedForTask(focusedTask.taskId),
    );
    await _logSessionAction(type: 'pause', task: focusedTask);
  }

  Future<void> _toggleTaskDone(
    TaskProvider taskProvider,
    Task focusedTask,
    bool isDone,
  ) async {
    if (!isDone) {
      await taskProvider.updateTask(
        focusedTask.copyWith(
          taskIsDone: false,
          taskIsDoneAt: null,
          taskStatus: focusedTask.taskStatus,
        ),
      );
      return;
    }

    try {
      await taskProvider.toggleTaskDone(
        focusedTask.copyWith(
          taskIsDone: true,
          taskIsDoneAt: DateTime.now(),
          taskStatus: 'Completed',
        ),
      );
      _focusedTaskStartedAtById.remove(focusedTask.taskId);
      await _handlePostCompletion(taskProvider, focusedTask);
      await _logSessionAction(type: 'complete', task: focusedTask);
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message.toString()),
        ),
      );
    }
  }

  Future<void> _toggleThoughtSubmit(Task task) async {
    await SessionTaskSubmissionHelper.openSubmissionFlow(context, task);
  }

  Future<void> _handlePostCompletion(
    TaskProvider taskProvider,
    Task completedTask,
  ) async {
    final session = widget.session;
    final isPomodoro =
        MindSetModes.resolveRuntimeMode(session.sessionMode) ==
        MindSetModes.pomodoro;
    final remainingTasks = _remainingSessionTasks(
      taskProvider,
      session,
      completedTask.taskId,
    );

    if (remainingTasks.isEmpty) {
      if (isPomodoro) {
        await _showPomodoroFocusDecision(session);
      }
      if (!mounted) return;
      if (session.sessionType == 'on_the_spot') {
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
      }

      final sessionTasks = _sessionTasksForSummary(taskProvider, session);
      await _showSessionSummaryAndEnd(session, taskProvider, sessionTasks);
      return;
    }

    if (!mounted) return;
    if (!isPomodoro) {
      return;
    }

    await _showPomodoroFocusDecision(session);
  }

  Future<void> _maybeCreateSessionCheckpointStep(
    Task task, {
    required String reason,
    required Duration elapsedDuration,
  }) async {
    if (task.taskIsDone) return;

    final latestActiveStep = await _focusedTaskStepProvider
        .getLatestActiveStepForTask(task.taskId);
    if (latestActiveStep != null) {
      await _focusedTaskStepProvider.toggleStepDoneStatus(
        latestActiveStep,
      );
      return;
    }

    final elapsedLabel = _formatElapsedDuration(elapsedDuration);
    await _focusedTaskStepProvider.addStep(
      stepTaskId: task.taskId,
      stepBoardId: task.taskBoardId,
      stepTitle: 'Session checkpoint ($elapsedLabel)',
      stepDescription: '$reason Elapsed focus time: $elapsedLabel.',
      initialDone: true,
    );
  }

  Duration _consumeElapsedForTask(String taskId) {
    final startedAt = _focusedTaskStartedAtById.remove(taskId);
    final fallbackStart =
        widget.session.sessionStartedAt ?? widget.session.sessionCreatedAt;
    final base = startedAt ?? fallbackStart;
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

  Future<void> _showPomodoroFocusDecision(MindSetSession session) async {
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
    TaskProvider taskProvider,
    List<Task> sessionTasks,
  ) async {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final now = DateTime.now();
    final startedAt = session.sessionStartedAt ?? session.sessionCreatedAt;
    final duration = now.difference(startedAt);
    final tasksTotal = sessionTasks.length;
    final tasksDone = sessionTasks.where((task) => task.taskIsDone).length;
    final completionRate = tasksTotal == 0
        ? 100
        : ((tasksDone / tasksTotal) * 100).round();

    await _endSession(session, taskProvider, sessionTasks);

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

  void _maybeAutoPromptFollowThroughSummary(
    MindSetSession session,
    List<Task> sessionTasks,
    int tasksDone,
    int tasksTotal,
    TaskProvider taskProvider,
  ) {
    if (session.sessionType != 'follow_through' || session.sessionStatus != 'active') {
      _followThroughAutoSummaryPrompted = false;
      _followThroughAutoSummarySessionId = session.sessionId;
      return;
    }

    if (_followThroughAutoSummarySessionId != session.sessionId) {
      _followThroughAutoSummarySessionId = session.sessionId;
      _followThroughAutoSummaryPrompted = false;
    }

    final isComplete = tasksTotal > 0 && tasksDone >= tasksTotal;
    if (!isComplete) {
      _followThroughAutoSummaryPrompted = false;
      return;
    }

    if (_followThroughAutoSummaryPrompted || !mounted) return;
    _followThroughAutoSummaryPrompted = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _showSessionSummaryAndEnd(session, taskProvider, sessionTasks);
    });
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
    await _runtimeService.pausePomodoroIfNeeded(session);
  }

  Future<void> _startBreakNow(MindSetSession session) async {
    await _runtimeService.startBreakNow(session);
  }
}

