import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../models/task_model.dart'; // Import Task model
import '../services/task_services.dart';
import '../../../boards/datasources/services/board_stats_services.dart';
import '../../../../shared/features/users/datasources/services/user_daily_activity_services.dart';
import '../../../notifications/datasources/helpers/notification_helper.dart';

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
    print('[DEBUG] TaskProvider: _setLoading called with value = $value');
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
    print(
      '[DEBUG] TaskProvider: streamTasksByBoard called for boardId = $boardId',
    );

    // Don't reinitialize if already streaming this board
    if (_currentStreamingMode == 'board' && _currentStreamingId == boardId) {
      print('[DEBUG] TaskProvider: Already streaming this board, skipping');
      return;
    }

    // Cancel previous subscription
    _taskSubscription?.cancel();

    _currentStreamingMode = 'board';
    _currentStreamingId = boardId;

    _setLoading(true);
    _taskStream = _taskService.streamTasks(boardId: boardId);
    _taskSubscription = _taskStream!.listen((tasks) {
      print(
        '[DEBUG] TaskProvider: streamTasksByBoard received ${tasks.length} tasks',
      );
      _updateTasks(tasks);
      _setLoading(false);
    });
  }

  /// Stream active tasks assigned to a user
  void streamUserActiveTasks(String userId) {
    print(
      '[DEBUG] TaskProvider: streamUserActiveTasks called for userId = $userId',
    );
    // Cancel previous subscription
    _taskSubscription?.cancel();

    _currentStreamingMode = 'user';
    _currentStreamingId = userId;

    _setLoading(true);
    _taskStream = _taskService.streamTasksAssignedTo(userId);
    _taskSubscription = _taskStream!.listen((tasks) {
      print(
        '[DEBUG] TaskProvider: streamUserActiveTasks received ${tasks.length} tasks, filtering active ones',
      );
      final filteredTasks = tasks.where((t) => !t.taskIsDone && !t.taskIsDeleted).toList();
      print(
        '[DEBUG] TaskProvider: after filtering, ${filteredTasks.length} active tasks remain',
      );
      _updateTasks(filteredTasks);
      _setLoading(false);
    });
  }

  /// Stream ALL tasks for a user (including completed) - for statistics
  void streamAllUserTasks(String userId) {
    print(
      '[DEBUG] TaskProvider: streamAllUserTasks called for userId = $userId',
    );

    // Don't reinitialize if already streaming all tasks for this user
    if (_currentStreamingMode == 'all' && _currentStreamingId == userId) {
      print(
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
    _taskSubscription = _taskStream!.listen((tasks) {
      print(
        '[DEBUG] TaskProvider: streamAllUserTasks received ${tasks.length} tasks',
      );
      final filteredTasks = tasks.where((t) => !t.taskIsDeleted).toList();
      print(
        '[DEBUG] TaskProvider: after filtering deleted, ${filteredTasks.length} tasks remain',
      );
      _updateTasks(filteredTasks);
      _setLoading(false);
    });
  }

  /// Stream tasks by a list of task IDs (for plans)
  void streamTasksByIds(List<String> taskIds) {
    print(
      '[DEBUG] TaskProvider: streamTasksByIds called for ${taskIds.length} tasks',
    );

    if (taskIds.isEmpty) {
      print('[DEBUG] TaskProvider: No task IDs provided, clearing tasks');
      _updateTasks([]);
      return;
    }

    // Cancel previous subscription
    _taskSubscription?.cancel();

    _currentStreamingMode = 'ids';
    _currentStreamingId = taskIds.join(',');

    _setLoading(true);
    _taskStream = _taskService.streamTasksByIds(taskIds);
    _taskSubscription = _taskStream!.listen((tasks) {
      print(
        '[DEBUG] TaskProvider: streamTasksByIds received ${tasks.length} tasks',
      );
      _updateTasks(tasks);
      _setLoading(false);
    });
  }

  // ------------------------
  // CRUD ACTIONS
  // ------------------------

  Future<void> addTask(Task task, {String? selectedAssigneeId, String? selectedAssigneeName}) async {
    try {
      print('[DEBUG] TaskProvider: addTask called for taskId = ${task.taskId}');
      print('[DEBUG] TaskProvider: selectedAssigneeId = $selectedAssigneeId, selectedAssigneeName = $selectedAssigneeName');
      // Ensure taskStats is initialized (fallback to empty TaskStats)
      final newTask = task.copyWith(taskStats: task.taskStats);

      // Add task immediately to local list for instant UI update
      _tasks.add(newTask);
      notifyListeners();
      print('[DEBUG] TaskProvider: Task added to local list immediately');

      // Add task to Firestore using TaskService
      await _taskService.addTask(newTask);

      // Send task assignment notification if a specific member was selected
      print('[TaskNotification] selectedAssigneeId = "$selectedAssigneeId", isEmpty = ${selectedAssigneeId?.isEmpty ?? true}');
      
      // Create task assignment notification for the selected assignee
      if (selectedAssigneeId != null && 
          selectedAssigneeId.isNotEmpty && 
          selectedAssigneeId != 'None' && 
          selectedAssigneeId != task.taskOwnerId) {
        print('[TaskNotification] ✅ Conditions met - creating notification for userId: $selectedAssigneeId');
        try {
          final deadlineInfo = task.taskDeadline != null 
              ? ' with a deadline on ${task.taskDeadline!.toString().split(' ')[0]}' 
              : '';
          
          print('[TaskNotification] Calling NotificationHelper.createInAppOnly...');
          await NotificationHelper.createInAppOnly(
            userId: selectedAssigneeId,
            title: 'Task Assignment Request',
            message: '${task.taskAssignedBy} wants to assign you the task "${task.taskTitle}"$deadlineInfo',
            category: NotificationHelper.categoryTaskAssigned,
            relatedId: task.taskId,
            metadata: {
              'boardTitle': task.taskBoardTitle,
              'taskTitle': task.taskTitle,
              'assigneeName': selectedAssigneeName ?? 'Unknown',
              if (task.taskDeadline != null)
                'deadline': task.taskDeadline.toString(),
              'assignedBy': task.taskAssignedBy,
              'taskId': task.taskId,
            },
          );
          print('[TaskNotification] ✅ Task assignment notification created for: ${task.taskId}');
        } catch (e) {
          // Log error but don't fail task creation - notification is optional
          print('[TaskNotification] ⚠️ Failed to create notification (non-critical): $e');
        }
      } else {
        print('[TaskNotification] ⚠️ Notification not created - no assignee selected');
      }

      // Track activity
      await _userDailyActivityService.incrementToday(newTask.taskOwnerId, {
        'tasksCreatedCount': 1,
      });

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

      print('✅ Task ${newTask.taskId} added successfully');
    } catch (e) {
      print('⚠️ Error adding task: $e');
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      print(
        '[DEBUG] TaskProvider: updateTask called for taskId = ${task.taskId}',
      );
      // Ensure taskStats is initialized (fallback to empty TaskStats)
      final updatedTask = task.copyWith(
        taskStats: task.taskStats,
      );

      // Update task in tasks collection using TaskService
      await _taskService.updateTask(updatedTask);

      print('✅ Task ${updatedTask.taskId} updated successfully');
    } catch (e) {
      print('⚠️ Error updating task: $e');
    }
  }

  Future<void> softDeleteTask(Task task) async {
    try {
      print(
        '[DEBUG] TaskProvider: softDeleteTask called for taskId = ${task.taskId}',
      );
      await _taskService.softDeleteTask(task);

      // Update board stats
      if (task.taskBoardId.isNotEmpty) {
        await _boardStatsService.incrementStats(
          task.taskBoardId,
          tasksDeleted: 1,
          tasksAdded: -1, // Decrement total tasks
          tasksDone:
              task.taskIsDone ? -1 : 0, // Decrement done if task was done
        );
      }

      print('✅ Task ${task.taskId} soft-deleted');
    } catch (e) {
      print('⚠️ Error soft deleting task: $e');
    }
  }

  Future<void> deleteTask(String taskId, {String? ownerId, Task? task}) async {
    try {
      print(
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
          tasksDone:
              taskToDelete.taskIsDone ? -1 : 0, // Decrement done if task was done
        );
      }

      // Track activity for task deletion using the task owner
      if (taskToDelete != null) {
        print(
          '[DEBUG] TaskProvider: Tracking deletion for user ${taskToDelete.taskOwnerId}',
        );
        await _userDailyActivityService.incrementToday(
          taskToDelete.taskOwnerId,
          {'tasksDeletedCount': 1},
        );
      } else {
        print(
          '[WARNING] TaskProvider: Could not find task to track deletion activity',
        );
      }

      print('✅ Task $taskId permanently deleted');
    } catch (e) {
      print('⚠️ Error hard deleting task: $e');
    }
  }

  Future<void> toggleTaskDone(Task task) async {
    try {
      print(
        '[DEBUG] TaskProvider: toggleTaskDone called for taskId = ${task.taskId}, new isDone = ${task.taskIsDone}',
      );

      // Since the task object passed in already has the NEW isDone value,
      // we determine what the old value was by inverting the current value
      final isNowDone = task.taskIsDone;
      final wasAlreadyDone = !isNowDone; // The opposite of the new value

      await _taskService.toggleTaskDone(task);

      // If task is repeating and was marked as done, schedule the next repeat
      if (task.taskIsRepeating && isNowDone) {
        // Task was just marked as done, schedule next repeat
        final nextRepeatTask = task.resetForNextRepeat();
        // Update the task with the next repeat date
        await _taskService.updateTask(nextRepeatTask);
      }

      // Track activity - if task was not done and is now done, increment completed count
      if (!wasAlreadyDone && isNowDone) {
        // Task just became done
        await _userDailyActivityService.incrementToday(task.taskOwnerId, {
          'tasksCompletedCount': 1,
        });
      } else if (wasAlreadyDone && !isNowDone) {
        // Task was undone
        await _userDailyActivityService.incrementToday(task.taskOwnerId, {
          'tasksCompletedCount': -1,
        });
      }

      // Update board stats
      if (task.taskBoardId.isNotEmpty) {
        if (!wasAlreadyDone && isNowDone) {
          // Task was just marked as done
          await _boardStatsService.incrementStats(
            task.taskBoardId,
            tasksDone: 1,
          );
        } else if (wasAlreadyDone && !isNowDone) {
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

      print('✅ Task ${task.taskId} done status toggled');
    } catch (e) {
      print('⚠️ Error toggling task done status: $e');
      rethrow;
    }
  }

  Future<void> acceptTask(String taskId) async {
    try {
      print('[DEBUG] TaskProvider: acceptTask called for taskId = $taskId');
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      await _taskService.acceptTask(
        taskId,
        currentUser.uid,
        currentUser.displayName ?? 'Unknown User',
      );

      // Notification will be created by the UI layer when needed

      print('✅ Task $taskId accepted');
    } catch (e) {
      print('⚠️ Error accepting task: $e');
      rethrow;
    }
  }

  Future<void> declineTask(String taskId) async {
    try {
      print('[DEBUG] TaskProvider: declineTask called for taskId = $taskId');
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      await _taskService.declineTask(
        taskId,
        currentUser.uid,
        currentUser.displayName ?? 'Unknown User',
      );

      print('✅ Task $taskId declined');
    } catch (e) {
      print('⚠️ Error declining task: $e');
      rethrow;
    }
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
          nextRepeatDate = _calculateNextRepeatDate(nextRepeatDate, task.taskRepeatInterval!);
          
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

      print('✅ Task ${task.taskId} deadline marked as missed');
    } catch (e) {
      print('⚠️ Error marking deadline as missed: $e');
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

      print('✅ Task ${task.taskId} deadline extended to $newDeadline');
    } catch (e) {
      print('⚠️ Error extending deadline: $e');
      rethrow;
    }
  }

  /// Mark a task as failed (permanent failure)
  Future<void> markTaskFailed(Task task) async {
    try {
      final updatedTask = task.copyWith(taskFailed: true);
      await updateTask(updatedTask);

      print('✅ Task ${task.taskId} marked as failed');
    } catch (e) {
      print('⚠️ Error marking task as failed: $e');
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
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
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
