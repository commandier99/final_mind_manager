import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../../../../boards/datasources/models/board_model.dart';
import '../../../../../../boards/datasources/providers/board_provider.dart';
import '../dialogs/add_task_to_session_dialog.dart';
import '../../../../../../tasks/datasources/models/task_model.dart';
import '../../../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../../../tasks/presentation/widgets/cards/task_card.dart';
import '../../datasources/services/mind_set_session_service.dart';
import '../../datasources/models/mind_set_session_model.dart';

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
  bool _isUpdatingFrog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensurePersonalBoard();
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

  Future<void> _ensurePersonalBoard() async {
    final boardProvider = context.read<BoardProvider>();
    final existing = _findPersonalBoard(boardProvider);
    if (existing != null) {
      _setPersonalBoard(existing);
      return;
    }

    setState(() {
      _isLoadingBoard = true;
    });

    await boardProvider.addBoard(
      title: 'Personal',
      goal: 'Personal Tasks',
      description: 'Personal tasks created from Mind:Set.',
    );
    await boardProvider.refreshBoards();

    final created = _findPersonalBoard(boardProvider);
    if (created != null) {
      _setPersonalBoard(created);
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
    if (!widget.isSessionActive || task.taskIsDone) return;
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
    if (!widget.isSessionActive) return;
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
    if (_isLoadingBoard) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_personalBoard == null) {
      return const Center(
        child: Text('Unable to load Personal board.'),
      );
    }

    final isEatTheFrog = _isEatTheFrogMode();
    final frogId = widget.session?.sessionActiveTaskId;
    final canAddTask = widget.isSessionActive && (!isEatTheFrog || frogId == null);

    return Column(
      children: [
        // Tasks Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tasks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: canAddTask ? _showAddTaskDialog : null,
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (!widget.isSessionActive)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Start the session to begin working on tasks.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
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

              Task? frogTask;
              if (isEatTheFrog && frogId != null) {
                frogTask = _findTaskById(tasks, frogId);
                if (frogTask == null || frogTask.taskIsDone) {
                  _scheduleClearFrogTask();
                }
              }

              final visibleTasks = isEatTheFrog
                  ? (frogId == null
                      ? tasks
                      : (frogTask == null ? <Task>[] : <Task>[frogTask]))
                  : tasks;

              if (visibleTasks.isEmpty) {
                final emptyMessage = isEatTheFrog && frogId != null
                    ? 'Frog completed. Pick your next one.'
                    : 'No tasks yet. Tap the + button to create one!';
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
              final isActive = widget.isSessionActive;

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
                        final canComplete =
                            isChecklist && _isInProgressStatus(task.taskStatus);
                        final canPickFrog = isEatTheFrog && frogId == null;
                        final isFrogTask =
                            isEatTheFrog && frogId == task.taskId;

                        return TaskCard(
                          task: task,
                          showFocusAction: ((isChecklist || isPomodoro) && isActive) ||
                              (isEatTheFrog && isActive &&
                                  (canPickFrog || isFrogTask)),
                          showFocusInMainRow: (isChecklist || isPomodoro) ||
                              (isEatTheFrog && (canPickFrog || isFrogTask)),
                          showCheckboxWhenFocusedOnly: isChecklist,
                          showBoardLabel: false,
                          useStatusColor: true,
                          onFocus: (isChecklist || isPomodoro)
                              ? () => _focusTask(task)
                              : (isEatTheFrog && isActive
                                  ? () async {
                                      if (canPickFrog) {
                                        await _setFrogTask(task);
                                      }
                                      await _focusTask(task);
                                    }
                                  : null),
                          onPause: (isChecklist || isPomodoro)
                              ? () => _pauseTask(task)
                              : (isEatTheFrog && isActive && isFrogTask
                                  ? () => _pauseTask(task)
                                  : null),
                          onToggleDone: isActive
                              ? (isEatTheFrog
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
                                          _toggleDoneForTask(task, isDone)))
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

  void _showAddTaskDialog() {
    if (_personalBoard == null) return;
    showDialog(
      context: context,
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
}
