import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../../boards/datasources/models/board_model.dart';
import '../../../../boards/datasources/providers/board_provider.dart';
import '../dialogs/add_task_to_session_dialog.dart';
import '../dialogs/pomodoro_check_in_dialogs.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/presentation/widgets/cards/task_card.dart';
import '../../../datasources/services/mind_set_session_service.dart';
import '../../../datasources/models/mind_set_session_model.dart';

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
  String _sortBy = 'created_desc'; // format: 'field_direction'
  late Set<String> _selectedFilters;
  
  // Filter options
  static const String allFilter = 'All';
  static const List<String> taskStatuses = ['To Do', 'In Progress', 'Paused', 'COMPLETED'];
  static const List<String> deadlineFilters = ['Overdue', 'Today', 'Upcoming', 'None'];
  static final List<String> allFilters = [allFilter, ...taskStatuses, ...deadlineFilters];

  @override
  void initState() {
    super.initState();
    _selectedFilters = {allFilter};
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
      boardType: 'personal', // Mark as personal board
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

  bool _matchesDeadlineFilter(Task task, String filter) {
    switch (filter) {
      case 'Overdue':
        return task.taskDeadline != null &&
            task.taskDeadline!.isBefore(DateTime.now()) &&
            !task.taskIsDone;
      case 'Today':
        final today = DateTime.now();
        return task.taskDeadline != null &&
            task.taskDeadline!.year == today.year &&
            task.taskDeadline!.month == today.month &&
            task.taskDeadline!.day == today.day;
      case 'Upcoming':
        return task.taskDeadline != null &&
            task.taskDeadline!.isAfter(DateTime.now());
      case 'None':
        return task.taskDeadline == null;
      default:
        return false;
    }
  }

  String _getFilterLabel(String filter) {
    if (taskStatuses.contains(filter)) {
      return 'Status: $filter';
    } else if (deadlineFilters.contains(filter)) {
      return 'Deadline: $filter';
    }
    return filter;
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

    // In Pomodoro mode, check if timer is configured
    if (_isPomodoroMode()) {
      final session = widget.session!;
      final stats = session.sessionStats;
      if (stats.pomodoroFocusMinutes == null || stats.pomodoroFocusMinutes! <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please set a Pomodoro timer duration first'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    }

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
      
      // In Pomodoro mode, confirm switch mid-timer
      if (_isPomodoroMode()) {
        final session = widget.session!;
        final stats = session.sessionStats;
        final isTimerRunning = stats.pomodoroIsRunning ?? false;
        
        if (isTimerRunning) {
          final shouldSwitch = await showSwitchFocusConfirmationDialog(
            context,
            currentTask: activeTask,
            newTask: task,
          );
          if (!shouldSwitch) return;
          
          // Switch without pausing timer
          await taskProvider.updateTask(
            activeTask.copyWith(taskStatus: 'Paused'),
          );
        } else {
          // Timer not running, normal switch
          await taskProvider.updateTask(
            activeTask.copyWith(taskStatus: 'Paused'),
          );
        }
      } else {
        // Non-pomodoro mode: normal pause dialog
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
    }

    await taskProvider.updateTask(
      task.copyWith(taskStatus: 'In Progress'),
    );
    
    // In Pomodoro mode, start timer when focusing
    if (_isPomodoroMode()) {
      await _resumePomodoro();
    }
  }

  Future<void> _pauseTask(Task task) async {
    if (!widget.isSessionActive) return;
    if (!_isInProgressStatus(task.taskStatus)) return;
    
    // In Pomodoro mode, disallow manual pause (only system pauses when timer ends)
    if (_isPomodoroMode()) {
      return;
    }
    
    final taskProvider = context.read<TaskProvider>();
    await taskProvider.updateTask(
      task.copyWith(taskStatus: 'Paused'),
    );
    await _pausePomodoro();
  }

  Future<void> _toggleDoneForTask(Task task, bool? isDone) async {
    final taskProvider = context.read<TaskProvider>();
    
    // Handle Pomodoro check-in when task is marked done
    if (_isPomodoroMode() && isDone == true && _isInProgressStatus(task.taskStatus)) {
      final session = widget.session!;
      final stats = session.sessionStats;
      final isTimerRunning = stats.pomodoroIsRunning ?? false;
      
      if (isTimerRunning) {
        // Pause timer before showing dialog
        await _pausePomodoro();
        
        // Show task-done-early check-in
        final availableTasks = taskProvider.tasks
            .where((t) => t.taskId != task.taskId && !t.taskIsDone)
            .toList();
            
        final result = await showTaskDoneEarlyDialog(
          context,
          availableTasks: availableTasks,
        );
        
        if (result == null) {
          // User dismissed dialog, resume timer
          await _resumePomodoro();
          return;
        }
        
        // Mark task done
        await taskProvider.toggleTaskDone(
          task.copyWith(
            taskIsDone: true,
            taskStatus: 'COMPLETED',
          ),
        );
        
        if (result.continueWithAnother && result.nextTaskId != null) {
          // Continue with another task
          final nextTask = taskProvider.tasks.firstWhere(
            (t) => t.taskId == result.nextTaskId,
          );
          await taskProvider.updateTask(
            nextTask.copyWith(taskStatus: 'In Progress'),
          );
          await _resumePomodoro();
        } else {
          // End pomodoro and start break
          await _handlePomodoroComplete(task);
        }
        return;
      }
    }
    
    // Normal toggle
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
  
  Future<void> _handlePomodoroComplete(Task completedTask) async {
    // This will be called by timer completion handler in pomodoro section
    // For now, pause the task
    final taskProvider = context.read<TaskProvider>();
    if (_isInProgressStatus(completedTask.taskStatus)) {
      await taskProvider.updateTask(
        completedTask.copyWith(taskStatus: 'Paused'),
      );
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
                    tooltip: 'Add filters',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.filter_list, size: 16, color: Colors.grey[700]),
                    ),
                    onSelected: (filter) {
                      setState(() {
                        if (filter == allFilter) {
                          _selectedFilters = {allFilter};
                        } else {
                          _selectedFilters.remove(allFilter);
                          _selectedFilters.add(filter);
                          if (_selectedFilters.isEmpty) {
                            _selectedFilters.add(filter);
                          }
                        }
                      });
                    },
                    itemBuilder: (context) {
                      return allFilters
                          .where((f) => !_selectedFilters.contains(f))
                          .map((filter) {
                        final label = _getFilterLabel(filter);
                        return PopupMenuItem<String>(
                          value: filter,
                          child: Text(label),
                        );
                      }).toList();
                    },
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showSortMenu(),
                        borderRadius: BorderRadius.circular(4),
                        child: Icon(Icons.swap_vert, size: 16, color: Colors.grey[700]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: canAddTask ? _showAddTaskDialog : null,
                        borderRadius: BorderRadius.circular(4),
                        child: Icon(Icons.add, size: 16, color: canAddTask ? Colors.grey[700] : Colors.grey[400]),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              // Active filters display
              if (!_selectedFilters.contains(allFilter))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _selectedFilters.map((filter) {
                      return Chip(
                        label: Text(_getFilterLabel(filter)),
                        onDeleted: () {
                          setState(() {
                            _selectedFilters.remove(filter);
                            if (_selectedFilters.isEmpty) {
                              _selectedFilters.add(allFilter);
                            }
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
              
              // Apply filtering
              final List<Task> filteredTasks;
              if (_selectedFilters.contains(allFilter)) {
                filteredTasks = visibleTasks;
              } else {
                final selectedStatuses = _selectedFilters
                    .where((f) => taskStatuses.contains(f))
                    .toSet();
                final selectedDeadlineFilters = _selectedFilters
                    .where((f) => deadlineFilters.contains(f))
                    .toSet();
                filteredTasks = visibleTasks
                    .where((task) {
                  if (selectedStatuses.isEmpty) return false;
                  final statusMatch = selectedStatuses.contains(task.taskStatus);
                  if (selectedDeadlineFilters.isEmpty) return statusMatch;
                  final deadlineMatch = selectedDeadlineFilters.any((filter) =>
                      _matchesDeadlineFilter(task, filter));
                  return statusMatch && deadlineMatch;
                }).toList();
              }
              
              final sortedTasks = _applySorting(filteredTasks);

              if (sortedTasks.isEmpty) {
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
                      itemCount: sortedTasks.length,
                      itemBuilder: (context, index) {
                        final task = sortedTasks[index];
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
                          showCheckboxWhenFocusedOnly: true,
                          showBoardLabel: false,
                          useStatusColor: true,
                          isPomodoroMode: isPomodoro,
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

  List<Task> _applySorting(List<Task> tasks) {
    final sorted = [...tasks];
    
    try {
      switch (_sortBy) {
        case 'priority_asc':
          sorted.sort((a, b) => _priorityToInt(a.taskPriorityLevel)
              .compareTo(_priorityToInt(b.taskPriorityLevel)));
          break;
        case 'priority_desc':
          sorted.sort((a, b) => _priorityToInt(b.taskPriorityLevel)
              .compareTo(_priorityToInt(a.taskPriorityLevel)));
          break;
        case 'alphabetical_asc':
          sorted.sort((a, b) => a.taskTitle
              .toLowerCase()
              .compareTo(b.taskTitle.toLowerCase()));
          break;
        case 'alphabetical_desc':
          sorted.sort((a, b) => b.taskTitle
              .toLowerCase()
              .compareTo(a.taskTitle.toLowerCase()));
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
