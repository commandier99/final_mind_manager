import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/presentation/widgets/cards/task_card.dart';
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
  bool _isUpdatingFrog = false;
  
  @override
  void initState() {
    super.initState();
    _streamTasks();
  }

  @override
  void didUpdateWidget(covariant GoWithFlowTaskStream oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _streamTasks();
    }
  }

  void _streamTasks() {
    final taskProvider = context.read<TaskProvider>();
    taskProvider.streamUserActiveTasks(widget.userId);
  }

  String _normalizeStatus(String status) {
    return status.toUpperCase().replaceAll(' ', '_');
  }

  bool _isInProgressStatus(String status) {
    return _normalizeStatus(status) == 'IN_PROGRESS';
  }

  bool _isPomodoroMode() {
    return widget.mode == 'Pomodoro' && widget.session != null;
  }

  bool _isEatTheFrogMode() {
    return widget.mode == 'Eat the Frog' && widget.session != null;
  }

  Task? _findTaskById(List<Task> tasks, String taskId) {
    for (final task in tasks) {
      if (task.taskId == taskId) return task;
    }
    return null;
  }

  Future<void> _setFrogTask(Task task) async {
    if (!_isEatTheFrogMode()) return;
    final session = widget.session!;
    if (session.sessionActiveTaskId == task.taskId) return;
    await _sessionService.updateSession(
      session.copyWith(sessionActiveTaskId: task.taskId),
    );
  }

  Future<void> _clearFrogTask() async {
    if (!_isEatTheFrogMode()) return;
    final session = widget.session!;
    if (session.sessionActiveTaskId == null) return;
    await _sessionService.updateSession(
      session.copyWith(sessionActiveTaskId: null),
    );
  }

  void _scheduleClearFrogTask() {
    if (_isUpdatingFrog) return;
    _isUpdatingFrog = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _clearFrogTask();
      } finally {
        if (mounted) {
          _isUpdatingFrog = false;
        }
      }
    });
  }

  int _calculateRemainingSeconds(MindSetSession session) {
    final stats = session.sessionStats;
    final focusMinutes = stats.pomodoroFocusMinutes;
    final breakMinutes = stats.pomodoroBreakMinutes ?? 5;
    final longBreakMinutes = stats.pomodoroLongBreakMinutes ?? 60;
    if (focusMinutes == null || focusMinutes <= 0) return 0;
    final isOnBreak = stats.pomodoroIsOnBreak ?? false;
    final isLongBreak = stats.pomodoroIsLongBreak ?? false;
    final baseRemaining = stats.pomodoroRemainingSeconds ??
        ((isOnBreak
                    ? (isLongBreak ? longBreakMinutes : breakMinutes)
                    : focusMinutes) *
                60);
    if (stats.pomodoroIsRunning != true) return baseRemaining;
    final lastUpdated = stats.pomodoroLastUpdatedAt;
    if (lastUpdated == null) return baseRemaining;
    final elapsed = DateTime.now().difference(lastUpdated).inSeconds;
    final remaining = baseRemaining - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  Future<void> _pausePomodoro() async {
    if (!_isPomodoroMode()) return;
    final session = widget.session!;
    final stats = session.sessionStats;
    final remaining = _calculateRemainingSeconds(session);
    await _sessionService.updateSession(
      session.copyWith(
        sessionStats: stats.copyWith(
          pomodoroIsRunning: false,
          pomodoroRemainingSeconds: remaining,
          pomodoroLastUpdatedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _resumePomodoro() async {
    if (!_isPomodoroMode()) return;
    final session = widget.session!;
    final stats = session.sessionStats;
    if (stats.pomodoroFocusMinutes == null ||
        (stats.pomodoroFocusMinutes ?? 0) <= 0) {
      return;
    }
    final remaining = _calculateRemainingSeconds(session);
    await _sessionService.updateSession(
      session.copyWith(
        sessionStats: stats.copyWith(
          pomodoroIsRunning: true,
          pomodoroRemainingSeconds: remaining,
          pomodoroLastUpdatedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _focusTask(Task task) async {
    if (task.taskIsDone) return;
    if (_isInProgressStatus(task.taskStatus)) return;

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
      await taskProvider.updateTask(
        activeTask.copyWith(taskStatus: 'Paused'),
      );
      await _pausePomodoro();
    }

    await taskProvider.updateTask(
      task.copyWith(taskStatus: 'In Progress'),
    );
    await _resumePomodoro();
  }

  Future<void> _pauseTask(Task task) async {
    if (!_isInProgressStatus(task.taskStatus)) return;
    final taskProvider = context.read<TaskProvider>();
    await taskProvider.updateTask(
      task.copyWith(taskStatus: 'Paused'),
    );
    await _pausePomodoro();
  }

  Future<void> _toggleDoneForTask(Task task, bool? isDone) async {
    final taskProvider = context.read<TaskProvider>();
    await taskProvider.toggleTaskDone(
      task.copyWith(
        taskIsDone: isDone ?? false,
        taskStatus: (isDone ?? false) ? 'COMPLETED' : 'To Do',
      ),
    );

    if (_isEatTheFrogMode() && (isDone ?? false)) {
      final frogId = widget.session?.sessionActiveTaskId;
      if (frogId == task.taskId) {
        await _clearFrogTask();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.grey[300],
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    tooltip: 'Filter',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.filter_list, size: 16, color: Colors.grey[700]),
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
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
        Expanded(
          child: Consumer<PlanProvider>(
            builder: (context, planProvider, _) {
              return StreamBuilder<List<Plan>>(
                stream: planProvider.streamUserPlans(widget.userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Text('Error loading plans: ${snapshot.error}');
                  }

                  final plans = snapshot.data ?? [];
                  final plannedTaskIds = <String>{};
                  for (final plan in plans) {
                    plannedTaskIds.addAll(plan.taskIds);
                  }

                  return Consumer<TaskProvider>(
                    builder: (context, taskProvider, _) {
                      if (taskProvider.isLoading &&
                          taskProvider.tasks.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final unplannedTasks = taskProvider.tasks
                          .where((task) => !plannedTaskIds.contains(task.taskId))
                          .toList();

                      final isEatTheFrog = _isEatTheFrogMode();
                      final frogId = widget.session?.sessionActiveTaskId;
                      Task? frogTask;
                      if (isEatTheFrog && frogId != null) {
                        frogTask = _findTaskById(unplannedTasks, frogId);
                        if (frogTask == null || frogTask.taskIsDone) {
                          _scheduleClearFrogTask();
                        }
                      }

                      final visibleTasks = isEatTheFrog
                          ? (frogId == null
                              ? unplannedTasks
                              : (frogTask == null
                                  ? <Task>[]
                                  : <Task>[frogTask]))
                          : unplannedTasks;

                      if (visibleTasks.isEmpty) {
                        final emptyMessage = isEatTheFrog && frogId != null
                            ? 'Frog completed. Pick your next one.'
                            : 'No unplanned tasks yet.';
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Text(
                              emptyMessage,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final isChecklist = widget.mode == 'Checklist';
                      final isPomodoro = widget.mode == 'Pomodoro';

                      return Column(
                        children: [
                          if (isEatTheFrog)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                frogId == null
                                    ? 'Pick your Frog: choose the hardest task and focus on only that one.'
                                    : 'Frog locked: finish it before moving to the next.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: visibleTasks.length,
                              itemBuilder: (context, index) {
                                final task = visibleTasks[index];
                                final canComplete = isChecklist &&
                                    _isInProgressStatus(task.taskStatus);
                                final canPickFrog = isEatTheFrog && frogId == null;
                                final isFrogTask =
                                    isEatTheFrog && frogId == task.taskId;

                                return TaskCard(
                                  task: task,
                                  showFocusAction: (isChecklist || isPomodoro) ||
                                      (isEatTheFrog &&
                                          (canPickFrog || isFrogTask)),
                                  showFocusInMainRow: (isChecklist || isPomodoro) ||
                                      (isEatTheFrog &&
                                          (canPickFrog || isFrogTask)),
                                  showCheckboxWhenFocusedOnly: isChecklist,
                                  useStatusColor: true,
                                  onFocus: (isChecklist || isPomodoro)
                                      ? () => _focusTask(task)
                                      : (isEatTheFrog
                                          ? () async {
                                              if (canPickFrog) {
                                                await _setFrogTask(task);
                                              }
                                              await _focusTask(task);
                                            }
                                          : null),
                                  onPause: (isChecklist || isPomodoro)
                                      ? () => _pauseTask(task)
                                      : (isEatTheFrog && isFrogTask
                                          ? () => _pauseTask(task)
                                          : null),
                                  onToggleDone: isEatTheFrog
                                      ? (isFrogTask
                                          ? (isDone) =>
                                              _toggleDoneForTask(task, isDone)
                                          : null)
                                      : (isChecklist
                                          ? (canComplete
                                              ? (isDone) =>
                                                  _toggleDoneForTask(task, isDone)
                                              : null)
                                          : (isDone) =>
                                              _toggleDoneForTask(task, isDone)),
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
