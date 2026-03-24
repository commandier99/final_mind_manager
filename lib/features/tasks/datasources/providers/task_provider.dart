import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../models/task_model.dart'; // Import Task model
import '../models/task_stats_model.dart';
import '../services/task_services.dart';
import '../helpers/task_dependency_helper.dart';
import '../../../boards/datasources/services/board_stats_services.dart';
import '../../../../shared/features/users/datasources/services/user_daily_activity_services.dart';

class TaskProvider extends ChangeNotifier {
  final TaskService _taskService = TaskService();
  final BoardStatsService _boardStatsService = BoardStatsService();
  final UserDailyActivityService _userDailyActivityService =
      UserDailyActivityService();

  List<Task> _tasks = [];
  List<Task> get tasks => _tasks;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Stream<List<Task>>? _taskStream;
  Stream<List<Task>>? get taskStream => _taskStream;

  StreamSubscription<List<Task>>? _taskSubscription;

  // Track the current streaming context to avoid switching modes unexpectedly
  String? _currentStreamingMode; // 'board', 'user', or 'all'
  String? _currentStreamingId; // boardId or userId depending on mode

  @override
  void dispose() {
    _taskSubscription?.cancel();
    super.dispose();
  }

  void _setLoading(bool value) {
    debugPrint('[DEBUG] TaskProvider: _setLoading called with value = $value');
    _isLoading = value;
    // Defer the notification to avoid "setState() or markNeedsBuild() called during build"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void _updateTasks(List<Task> tasks) {
    _tasks = tasks;
    notifyListeners();
  }

  // ------------------------
  // STREAM TASKS
  // ------------------------

  /// Stream tasks for a specific board
  void streamTasksByBoard(String boardId) {
    debugPrint(
      '[DEBUG] TaskProvider: streamTasksByBoard called for boardId = $boardId',
    );

    // Don't reinitialize if already streaming this board
    if (_currentStreamingMode == 'board' && _currentStreamingId == boardId) {
      debugPrint('[DEBUG] TaskProvider: Already streaming this board, skipping');
      return;
    }

    // Cancel previous subscription
    _taskSubscription?.cancel();

    _currentStreamingMode = 'board';
    _currentStreamingId = boardId;

    _setLoading(true);
    _taskStream = _taskService.streamTasks(boardId: boardId);
    _taskSubscription = _taskStream!.listen(
      (tasks) {
        debugPrint(
          '[DEBUG] TaskProvider: streamTasksByBoard received ${tasks.length} tasks',
        );
        _updateTasks(tasks);
        _setLoading(false);
      },
      onError: (error) {
        debugPrint('[DEBUG] TaskProvider: streamTasksByBoard error: $error');
        _updateTasks([]);
        _setLoading(false);
      },
    );
  }

  /// Stream active tasks assigned to a user
  void streamUserActiveTasks(String userId) {
    debugPrint(
      '[DEBUG] TaskProvider: streamUserActiveTasks called for userId = $userId',
    );
    // Cancel previous subscription
    _taskSubscription?.cancel();

    _currentStreamingMode = 'user';
    _currentStreamingId = userId;

    _setLoading(true);
    _taskStream = _taskService.streamTasksAssignedTo(userId);
    _taskSubscription = _taskStream!.listen(
      (tasks) {
        debugPrint(
          '[DEBUG] TaskProvider: streamUserActiveTasks received ${tasks.length} tasks, filtering active ones',
        );
        final filteredTasks = tasks
            .where((t) => !t.taskIsDone && !t.taskIsDeleted)
            .toList();
        debugPrint(
          '[DEBUG] TaskProvider: after filtering, ${filteredTasks.length} active tasks remain',
        );
        _updateTasks(filteredTasks);
        _setLoading(false);
      },
      onError: (error) {
        debugPrint('[DEBUG] TaskProvider: streamUserActiveTasks error: $error');
        _updateTasks([]);
        _setLoading(false);
      },
    );
  }

  /// Stream ALL tasks for a user (including completed) - for statistics
  void streamAllUserTasks(String userId) {
    debugPrint(
      '[DEBUG] TaskProvider: streamAllUserTasks called for userId = $userId',
    );

    // Don't reinitialize if already streaming all tasks for this user
    if (_currentStreamingMode == 'all' && _currentStreamingId == userId) {
      debugPrint(
        '[DEBUG] TaskProvider: Already streaming all tasks for this user, skipping',
      );
      return;
    }

    // Cancel previous subscription
    _taskSubscription?.cancel();

    _currentStreamingMode = 'all';
    _currentStreamingId = userId;

    _setLoading(true);
    _taskStream = _taskService.streamTasksAssignedTo(userId);
    _taskSubscription = _taskStream!.listen(
      (tasks) {
        debugPrint(
          '[DEBUG] TaskProvider: streamAllUserTasks received ${tasks.length} tasks',
        );
        final filteredTasks = tasks.where((t) => !t.taskIsDeleted).toList();
        debugPrint(
          '[DEBUG] TaskProvider: after filtering deleted, ${filteredTasks.length} tasks remain',
        );
        _updateTasks(filteredTasks);
        _setLoading(false);
      },
      onError: (error) {
        debugPrint('[DEBUG] TaskProvider: streamAllUserTasks error: $error');
        _updateTasks([]);
        _setLoading(false);
      },
    );
  }

  /// Stream tasks by a list of task IDs (for plans)
  void streamTasksByIds(List<String> taskIds) {
    debugPrint(
      '[DEBUG] TaskProvider: streamTasksByIds called for ${taskIds.length} tasks',
    );

    if (taskIds.isEmpty) {
      debugPrint('[DEBUG] TaskProvider: No task IDs provided, clearing tasks');
      _updateTasks([]);
      return;
    }

    // Cancel previous subscription
    _taskSubscription?.cancel();

    _currentStreamingMode = 'ids';
    _currentStreamingId = taskIds.join(',');

    _setLoading(true);
    _taskStream = _taskService.streamTasksByIds(taskIds);
    _taskSubscription = _taskStream!.listen(
      (tasks) {
        debugPrint(
          '[DEBUG] TaskProvider: streamTasksByIds received ${tasks.length} tasks',
        );
        _updateTasks(tasks);
        _setLoading(false);
      },
      onError: (error) {
        debugPrint('[DEBUG] TaskProvider: streamTasksByIds error: $error');
        _updateTasks([]);
        _setLoading(false);
      },
    );
  }

  // ------------------------
  // CRUD ACTIONS
  // ------------------------

  Future<void> addTask(
    Task task, {
    String? selectedAssigneeId,
    String? selectedAssigneeName,
  }) async {
    try {
      debugPrint('[DEBUG] TaskProvider: addTask called for taskId = ${task.taskId}');
      debugPrint(
        '[DEBUG] TaskProvider: selectedAssigneeId = $selectedAssigneeId, selectedAssigneeName = $selectedAssigneeName',
      );
      // Ensure taskStats is initialized (fallback to empty TaskStats)
      final newTask = task.copyWith(taskStats: task.taskStats);

      // Add task immediately to local list for instant UI update
      _tasks.add(newTask);
      notifyListeners();
      debugPrint('[DEBUG] TaskProvider: Task added to local list immediately');

      // Add task to Firestore using TaskService
      await _taskService.addTask(newTask);

      // Track activity
      final activeUserId = _activeUserId;
      if (activeUserId != null && activeUserId.isNotEmpty) {
        await _userDailyActivityService.incrementToday(activeUserId, {
          'tasksCreatedCount': 1,
        });
      }

      // Update board stats
      if (newTask.taskBoardId.isNotEmpty) {
        await _boardStatsService.incrementStats(
          newTask.taskBoardId,
          tasksAdded: 1,
        );
      }

      // NOTE: We don't need to refresh the stream here because Firestore streams
      // are live subscriptions - they automatically receive updates when data changes.
      // The task will appear automatically in the active stream without reinitializing.

      debugPrint('✅ Task ${newTask.taskId} added successfully');
    } catch (e) {
      debugPrint('⚠️ Error adding task: $e');
      rethrow;
    }
  }

  Future<Task> duplicateTask(Task sourceTask) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final ownerId = firebaseUser?.uid ?? sourceTask.taskOwnerId;
    final displayName = firebaseUser?.displayName;
    final ownerName = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : sourceTask.taskOwnerName;

    final duplicatedTask = sourceTask.copyWith(
      taskId: const Uuid().v4(),
      taskTitle: _duplicateTitle(sourceTask.taskTitle),
      taskCreatedAt: DateTime.now(),
      taskOwnerId: ownerId,
      taskOwnerName: ownerName,
      taskAssignedBy: ownerId,
      taskDeletedAt: null,
      taskIsDeleted: false,
      taskIsDone: false,
      taskIsDoneAt: null,
      taskFailed: false,
      taskOutcome: Task.outcomeNone,
      taskStats: TaskStats(),
      taskStatus: Task.statusToDo,
      taskApprovalStatus: 'none',
      taskSubmissionId: null,
      taskLatestSubmissionThoughtId: null,
      taskAssignmentStatus: _duplicatedAssignmentStatus(sourceTask),
      taskDeadlineMissed: false,
      taskExtensionCount: 0,
      taskRepeatTime: sourceTask.taskRepeatTime,
      taskRevisionOfTaskId: null,
      taskRevisionOfSubmissionId: null,
    );

    await addTask(duplicatedTask);
    return duplicatedTask;
  }

  String _duplicateTitle(String title) {
    const copySuffix = ' (Copy)';
    return title.endsWith(copySuffix) ? title : '$title$copySuffix';
  }

  String? _duplicatedAssignmentStatus(Task sourceTask) {
    return null;
  }

  Future<void> updateTask(Task task) async {
    var existingIndex = -1;
    Task? previousTask;

    try {
      debugPrint(
        '[DEBUG] TaskProvider: updateTask called for taskId = ${task.taskId}',
      );
      // Ensure taskStats is initialized (fallback to empty TaskStats)
      final updatedTask = task.copyWith(taskStats: task.taskStats);

      // Optimistic local update for immediate UI feedback.
      existingIndex = _tasks.indexWhere((t) => t.taskId == updatedTask.taskId);
      if (existingIndex != -1) {
        previousTask = _tasks[existingIndex];
        _tasks[existingIndex] = updatedTask;
        notifyListeners();
      } else {
        previousTask = await _taskService.getTaskById(updatedTask.taskId);
      }

      // Update task in tasks collection using TaskService
      await _taskService.updateTask(updatedTask);

      debugPrint(
        '[DEBUG] TaskProvider: Task ${updatedTask.taskId} updated successfully',
      );
    } catch (e) {
      // Roll back optimistic local update if write fails.
      if (existingIndex != -1 &&
          previousTask != null &&
          existingIndex < _tasks.length) {
        _tasks[existingIndex] = previousTask;
        notifyListeners();
      }
      debugPrint('[DEBUG] TaskProvider: Error updating task: $e');
      rethrow;
    }
  }

  Future<void> respondToTaskAssignment({
    required String taskId,
    required bool accepted,
    required String assigneeId,
    required String assigneeName,
  }) async {
    var existingIndex = -1;
    Task? previousTask;

    try {
      existingIndex = _tasks.indexWhere((t) => t.taskId == taskId);
      if (existingIndex != -1) {
        previousTask = _tasks[existingIndex];
        _tasks[existingIndex] = _tasks[existingIndex].copyWith(
          taskAssignedTo: accepted ? assigneeId : 'None',
          taskAssignedToName: accepted
              ? (assigneeName.trim().isEmpty ? 'Unknown' : assigneeName.trim())
              : 'Unassigned',
          taskAssignmentStatus: accepted ? 'accepted' : 'declined',
          taskProposedAssigneeId: null,
          taskProposedAssigneeName: null,
        );
        notifyListeners();
      }

      await _taskService.respondToTaskAssignment(
        taskId: taskId,
        accepted: accepted,
        assigneeId: assigneeId,
        assigneeName: assigneeName,
      );
    } catch (e) {
      if (existingIndex != -1 &&
          previousTask != null &&
          existingIndex < _tasks.length) {
        _tasks[existingIndex] = previousTask;
        notifyListeners();
      }
      debugPrint('[DEBUG] TaskProvider: Error responding to assignment: $e');
      rethrow;
    }
  }

  Future<void> softDeleteTask(Task task) async {
    try {
      debugPrint(
        '[DEBUG] TaskProvider: softDeleteTask called for taskId = ${task.taskId}',
      );
      await _taskService.softDeleteTask(task);

      // Update board stats
      if (task.taskBoardId.isNotEmpty) {
        await _boardStatsService.incrementStats(
          task.taskBoardId,
          tasksDeleted: 1,
          tasksAdded: -1, // Decrement total tasks
          tasksDone: task.taskIsDone
              ? -1
              : 0, // Decrement done if task was done
        );
      }

      debugPrint('✅ Task ${task.taskId} soft-deleted');
    } catch (e) {
      debugPrint('⚠️ Error soft deleting task: $e');
    }
  }

  Future<void> deleteTask(String taskId, {String? ownerId, Task? task}) async {
    try {
      debugPrint(
        '[DEBUG] TaskProvider: deleteTask called for taskId = $taskId, ownerId = $ownerId',
      );

      // Use provided task or find it in the list
      Task? taskToDelete = task;
      if (taskToDelete == null) {
        try {
          taskToDelete = _tasks.firstWhere((t) => t.taskId == taskId);
        } catch (e) {
          // Task not found in current list
        }
      }

      // Pass task object to hardDeleteTask so it can log the activity event
      await _taskService.hardDeleteTask(taskId, task: taskToDelete);

      // Update board stats (same as softDeleteTask)
      if (taskToDelete != null && taskToDelete.taskBoardId.isNotEmpty) {
        await _boardStatsService.incrementStats(
          taskToDelete.taskBoardId,
          tasksDeleted: 1,
          tasksAdded: -1, // Decrement total tasks
          tasksDone: taskToDelete.taskIsDone
              ? -1
              : 0, // Decrement done if task was done
        );
      }

      // Track activity for task deletion using the task owner
      if (taskToDelete != null) {
        debugPrint(
          '[DEBUG] TaskProvider: Tracking deletion for user ${taskToDelete.taskOwnerId}',
        );
        final activeUserId = _activeUserId;
        if (activeUserId != null && activeUserId.isNotEmpty) {
          await _userDailyActivityService.incrementToday(activeUserId, {
            'tasksDeletedCount': 1,
          });
        }
      } else {
        debugPrint(
          '[WARNING] TaskProvider: Could not find task to track deletion activity',
        );
      }

      debugPrint('✅ Task $taskId permanently deleted');
    } catch (e) {
      debugPrint('⚠️ Error hard deleting task: $e');
    }
  }

  Future<void> toggleTaskDone(Task task) async {
    try {
      debugPrint(
        '[DEBUG] TaskProvider: toggleTaskDone called for taskId = ${task.taskId}, new isDone = ${task.taskIsDone}',
      );
      if (task.isWorkDisabled) {
        throw StateError(task.workDisabledReason ?? 'This task is disabled.');
      }

      // Since the task object passed in already has the NEW isDone value,
      // we determine what the old value was by inverting the current value
      final isNowDone = task.taskIsDone;
      final wasAlreadyDone = !isNowDone; // The opposite of the new value
      final effectiveNowDone = isNowDone;

      if (isNowDone) {
        final blocker = await getFirstIncompleteDependency(task);
        if (blocker != null) {
          final blockerOwner = blocker.taskAssignedToName.trim();
          final ownerSuffix =
              blockerOwner.isEmpty || blockerOwner == 'Unassigned'
              ? ''
              : ' ($blockerOwner)';
          throw StateError(
            'Blocked by "${blocker.taskTitle}"$ownerSuffix. Complete it first.',
          );
        }
      }

      await _taskService.toggleTaskDone(task);

      // If task is repeating and was marked as done, schedule the next repeat
      if (task.taskIsRepeating && effectiveNowDone) {
        // Task was just marked as done, schedule next repeat
        final nextRepeatTask = task.resetForNextRepeat();
        // Update the task with the next repeat date
        await _taskService.updateTask(nextRepeatTask);
      }

      // Track activity - if task was not done and is now done, increment completed count
      if (!wasAlreadyDone && effectiveNowDone) {
        // Task just became done
        final activeUserId = _activeUserId;
        if (activeUserId != null && activeUserId.isNotEmpty) {
          await _userDailyActivityService.incrementToday(activeUserId, {
            'tasksCompletedCount': 1,
          });
        }
      } else if (wasAlreadyDone && !effectiveNowDone) {
        // Task was undone
        final activeUserId = _activeUserId;
        if (activeUserId != null && activeUserId.isNotEmpty) {
          await _userDailyActivityService.incrementToday(activeUserId, {
            'tasksCompletedCount': -1,
          });
        }
      }

      // Update board stats
      if (task.taskBoardId.isNotEmpty) {
        if (!wasAlreadyDone && effectiveNowDone) {
          // Task was just marked as done
          await _boardStatsService.incrementStats(
            task.taskBoardId,
            tasksDone: 1,
          );
        } else if (wasAlreadyDone && !effectiveNowDone) {
          // Task was just unmarked as done
          await _boardStatsService.incrementStats(
            task.taskBoardId,
            tasksDone: -1,
          );
        }
      }

      // Update local task list and notify listeners for immediate UI update
      final taskIndex = _tasks.indexWhere((t) => t.taskId == task.taskId);
      if (taskIndex != -1) {
        // Update the task with the exact state passed in (already has correct isDone value)
        _tasks[taskIndex] = task;
        notifyListeners();
      }

      debugPrint('✅ Task ${task.taskId} done status toggled');
    } catch (e) {
      debugPrint('⚠️ Error toggling task done status: $e');
      rethrow;
    }
  }

  Future<List<Task>> getIncompleteDependencies(Task task) async {
    final dependencyIds = TaskDependencyHelper.sanitizeDependencyIds(
      task.taskDependencyIds,
      selfTaskId: task.taskId,
    );
    if (dependencyIds.isEmpty) return const <Task>[];

    final byId = <String, Task>{for (final t in _tasks) t.taskId: t};
    final unresolved = <Task>[];

    for (final dependencyId in dependencyIds) {
      Task? dependencyTask = byId[dependencyId];
      dependencyTask ??= await _taskService.getTaskById(dependencyId);
      if (dependencyTask != null && !dependencyTask.taskIsDone) {
        unresolved.add(dependencyTask);
      }
    }
    return unresolved;
  }

  Future<Task?> getFirstIncompleteDependency(Task task) async {
    final blockers = await getIncompleteDependencies(task);
    return blockers.isEmpty ? null : blockers.first;
  }



  // ----------------------
  // DEADLINE MANAGEMENT
  // ----------------------

  /// Mark a task deadline as missed and create next repeat if applicable
  Future<void> markDeadlineMissed(Task task) async {
    try {
      final updatedTask = task.copyWith(taskDeadlineMissed: true);
      await updateTask(updatedTask);

      // If this is a repeating task, create next instance
      if (task.taskIsRepeating) {
        // Calculate next repeat date
        DateTime? nextRepeatDate = task.taskNextRepeatDate;
        if (nextRepeatDate != null && task.taskRepeatInterval != null) {
          // Logic to calculate next repeat based on interval
          // (You can expand this based on your repeat logic)
          nextRepeatDate = _calculateNextRepeatDate(
            nextRepeatDate,
            task.taskRepeatInterval!,
          );

          // Create new instance for next repeat
          final nextTask = task.copyWith(
            taskId: const Uuid().v4(),
            taskIsDone: false,
            taskDeadlineMissed: false,
            taskNextRepeatDate: nextRepeatDate,
          );
          await addTask(nextTask);
        }
      }

      debugPrint('✅ Task ${task.taskId} deadline marked as missed');
    } catch (e) {
      debugPrint('⚠️ Error marking deadline as missed: $e');
      rethrow;
    }
  }

  /// Extend a deadline for a missed task
  Future<void> extendDeadline(Task task, DateTime newDeadline) async {
    try {
      final updatedTask = task.copyWith(
        taskDeadline: newDeadline,
        taskDeadlineMissed: false,
        taskExtensionCount: task.taskExtensionCount + 1,
      );
      await updateTask(updatedTask);

      debugPrint('✅ Task ${task.taskId} deadline extended to $newDeadline');
    } catch (e) {
      debugPrint('⚠️ Error extending deadline: $e');
      rethrow;
    }
  }

  /// Mark a task as failed (permanent failure)
  Future<void> markTaskFailed(Task task) async {
    try {
      final updatedTask = task.copyWith(
        taskFailed: true,
        taskOutcome: Task.outcomeFailed,
      );
      await updateTask(updatedTask);

      debugPrint('✅ Task ${task.taskId} marked as failed');
    } catch (e) {
      debugPrint('⚠️ Error marking task as failed: $e');
      rethrow;
    }
  }

  /// Calculate next repeat date based on interval
  DateTime _calculateNextRepeatDate(DateTime current, String interval) {
    // Parse interval and calculate next date
    // Example: "Monday,Wednesday,Friday" or daily/weekly/monthly
    if (interval.contains(',')) {
      // Multiple days - calculate next occurrence
      final days = interval.split(',');
      return _getNextOccurrenceOfDays(current, days);
    } else {
      // Single interval like "daily", "weekly", "monthly"
      return _getNextOccurrenceByInterval(current, interval);
    }
  }

  DateTime _getNextOccurrenceOfDays(DateTime current, List<String> days) {
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    DateTime next = current.add(const Duration(days: 1));

    while (!days.contains(dayNames[next.weekday - 1])) {
      next = next.add(const Duration(days: 1));
    }

    return next;
  }

  DateTime _getNextOccurrenceByInterval(DateTime current, String interval) {
    switch (interval.toLowerCase()) {
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(current.year, current.month + 1, current.day);
      default:
        return current.add(const Duration(days: 1));
    }
  }
}



  String? get _activeUserId => FirebaseAuth.instance.currentUser?.uid;
