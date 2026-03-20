import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task_model.dart'; // Ensure TaskModel is imported
import '../models/task_stats_model.dart'; // Ensure TaskStats is imported
import 'task_stats_services.dart';
import '../../../../shared/features/users/datasources/services/activity_event_services.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TaskStatsService _taskStatsService =
      TaskStatsService(); // Instance of TaskStatsService
  final ActivityEventService _activityEventService = ActivityEventService();
  CollectionReference get _tasks => _firestore.collection('tasks');

  bool _isPersonalBoardData(Map<String, dynamic> boardData) {
    final type = (boardData['boardType'] as String? ?? '').trim().toLowerCase();
    if (type == 'personal') return true;
    final title = (boardData['boardTitle'] as String? ?? '')
        .trim()
        .toLowerCase();
    return title == 'personal' || title == 'personal hq';
  }

  Future<Task> _normalizeTaskForBoardRules(Task task) async {
    final boardId = task.taskBoardId.trim();
    if (boardId.isEmpty) return task;

    final boardDoc = await _firestore.collection('boards').doc(boardId).get();
    if (!boardDoc.exists) return task;
    final boardData = boardDoc.data() as Map<String, dynamic>;
    if (!_isPersonalBoardData(boardData)) return task;

    final managerId = (boardData['boardManagerId'] as String? ?? '').trim();
    if (managerId.isEmpty) return task;
    final managerName = (boardData['boardManagerName'] as String? ?? 'Manager')
        .trim();

    return task.copyWith(
      taskAssignedTo: managerId,
      taskAssignedToName: managerName,
      taskBoardLane: Task.lanePublished,
      taskAssignmentStatus: null,
    );
  }

  Future<void> _assertAssigneeWithinBoardTaskLimit(
    Task task, {
    String? excludingTaskId,
  }) async {
    final boardId = task.taskBoardId.trim();
    final assigneeId = task.taskAssignedTo.trim();
    final isUnassigned = assigneeId.isEmpty || assigneeId == 'None';
    if (boardId.isEmpty || isUnassigned || task.taskIsDone) return;

    final boardDoc = await _firestore.collection('boards').doc(boardId).get();
    if (!boardDoc.exists) return;
    final boardData = boardDoc.data() as Map<String, dynamic>;
    if (_isPersonalBoardData(boardData)) return;
    final managerId = boardData['boardManagerId'] as String? ?? '';
    if (assigneeId == managerId) return; // manager is unlimited

    final configuredLimit = (boardData['boardTaskCapacity'] as num?)?.toInt();
    final limit = configuredLimit != null && configuredLimit >= 0
        ? configuredLimit
        : 5;
    if (limit <= 0) return;

    final activeAssignedSnapshot = await _tasks
        .where('taskBoardId', isEqualTo: boardId)
        .where('taskAssignedTo', isEqualTo: assigneeId)
        .where('taskIsDeleted', isEqualTo: false)
        .where('taskIsDone', isEqualTo: false)
        .get();

    int activeCount = activeAssignedSnapshot.docs.length;
    if (excludingTaskId != null &&
        excludingTaskId.isNotEmpty &&
        activeAssignedSnapshot.docs.any((doc) => doc.id == excludingTaskId)) {
      activeCount -= 1;
    }

    if (activeCount >= limit) {
      throw StateError(
        'Assignee is already at capacity ($activeCount/$limit active tasks).',
      );
    }
  }

  /// Add a new task
  Future<void> addTask(Task task) async {
    try {
      final normalizedTask = await _normalizeTaskForBoardRules(task);
      await _assertAssigneeWithinBoardTaskLimit(normalizedTask);
      // Add task to the 'tasks' collection
      await _tasks.doc(normalizedTask.taskId).set(normalizedTask.toMap());

      // Add task stats to the 'task_stats' collection using TaskStatsService
      await _taskStatsService.addTaskStats(
        normalizedTask.taskId,
        normalizedTask.taskStats,
      );

      // Log activity event
      final user = _auth.currentUser;
      if (user != null) {
        await _activityEventService.logEvent(
          userId: user.uid,
          userName: user.displayName ?? 'Unknown User',
          activityType: 'task_created',
          userProfilePicture: user.photoURL,
          // Keep this in user activity feed but avoid polluting board timeline.
          boardId: null,
          taskId: normalizedTask.taskId,
          description: 'created a task',
          metadata: {
            'taskTitle': normalizedTask.taskTitle,
            if ((normalizedTask.taskBoardTitle ?? '').trim().isNotEmpty)
              'boardTitle': (normalizedTask.taskBoardTitle ?? '').trim(),
          },
        );
      }

      debugPrint('âœ… Task ${normalizedTask.taskId} added successfully');
    } catch (e) {
      debugPrint('âš ï¸ Error adding task: $e');
      rethrow;
    }
  }

  /// Update existing task
  Future<void> updateTask(Task task) async {
    try {
      final previousTask = await getTaskById(task.taskId);
      await _assertTaskNotCompleted(task.taskId);
      final normalizedTask = await _normalizeTaskForBoardRules(task);
      await _assertAssigneeWithinBoardTaskLimit(
        normalizedTask,
        excludingTaskId: normalizedTask.taskId,
      );
      // Update task in the 'tasks' collection
      await _tasks.doc(normalizedTask.taskId).update(normalizedTask.toMap());

      // Update task stats in the 'task_stats' collection using TaskStatsService
      await _taskStatsService.updateTaskStats(
        normalizedTask.taskId,
        normalizedTask.taskStats,
      );
      await _logTaskWorkflowEvents(
        previousTask: previousTask,
        updatedTask: normalizedTask,
      );

      debugPrint('âœ… Task ${normalizedTask.taskId} updated successfully');
    } catch (e) {
      debugPrint('âš ï¸ Error updating task: $e');
      rethrow;
    }
  }

  Future<void> _logTaskWorkflowEvents({
    required Task? previousTask,
    required Task updatedTask,
  }) async {
    final user = _auth.currentUser;
    if (user == null || previousTask == null) return;

    final boardId = updatedTask.taskBoardId.trim().isNotEmpty
        ? updatedTask.taskBoardId.trim()
        : null;
    final boardTitle = (updatedTask.taskBoardTitle ?? '').trim();
    final taskTitle = updatedTask.taskTitle.trim();

    final prevStatus = previousTask.taskStatus.trim();
    final nextStatus = updatedTask.taskStatus.trim();

    if (prevStatus != nextStatus) {
      await _activityEventService.logEvent(
        userId: user.uid,
        userName: user.displayName ?? 'Unknown User',
        activityType: 'task_status_changed',
        userProfilePicture: user.photoURL,
        boardId: boardId,
        taskId: updatedTask.taskId,
        description: 'changed task status',
        metadata: {
          'taskTitle': taskTitle,
          'fromStatus': prevStatus,
          'toStatus': nextStatus,
          if (boardTitle.isNotEmpty) 'boardTitle': boardTitle,
        },
      );

      if (nextStatus.toLowerCase() == Task.statusInProgress.toLowerCase()) {
        await _activityEventService.logEvent(
          userId: user.uid,
          userName: user.displayName ?? 'Unknown User',
          activityType: 'task_in_progress',
          userProfilePicture: user.photoURL,
          boardId: boardId,
          taskId: updatedTask.taskId,
          description: 'started focusing on a task',
          metadata: {
            'taskTitle': taskTitle,
            if (boardTitle.isNotEmpty) 'boardTitle': boardTitle,
          },
        );
      }
    }
  }

  Future<void> _assertTaskNotCompleted(String taskId) async {
    final taskDoc = await _tasks.doc(taskId).get();
    if (!taskDoc.exists) return;
    final data = taskDoc.data() as Map<String, dynamic>?;
    final isDone = data?['taskIsDone'] as bool? ?? false;
    if (isDone) {
      throw StateError('This task is locked because it is already completed.');
    }
  }

  /// Soft-delete a task
  Future<void> softDeleteTask(Task task) async {
    try {
      await _assertTaskNotCompleted(task.taskId);
      await _tasks.doc(task.taskId).update({
        'taskIsDeleted': true,
        'taskDeletedAt': Timestamp.now(),
      });

      // Log activity event
      final user = _auth.currentUser;
      if (user != null) {
        await _activityEventService.logEvent(
          userId: user.uid,
          userName: user.displayName ?? 'Unknown User',
          activityType: 'task_deleted',
          userProfilePicture: user.photoURL,
          boardId: task.taskBoardId.isNotEmpty ? task.taskBoardId : null,
          taskId: task.taskId,
          description: 'deleted a task',
          metadata: {
            'taskTitle': task.taskTitle,
            if ((task.taskBoardTitle ?? '').trim().isNotEmpty)
              'boardTitle': (task.taskBoardTitle ?? '').trim(),
          },
        );
      }

      debugPrint('âœ… Task ${task.taskId} soft-deleted');
    } catch (e) {
      debugPrint('âš ï¸ Error soft deleting task: $e');
    }
  }

  /// Hard-delete a task (delete task from Firestore completely)
  Future<void> hardDeleteTask(String taskId, {Task? task}) async {
    try {
      await _assertTaskNotCompleted(taskId);
      // Get task data if not provided (for activity logging)
      Task? taskData = task;
      taskData ??= await getTaskById(taskId);

      // First, delete the task from the 'tasks' collection
      await _tasks.doc(taskId).delete();

      // Then, delete the associated task stats from 'task_stats' using TaskStatsService
      await _taskStatsService.deleteTaskStats(taskId);

      // Log activity event for task deletion
      if (taskData != null) {
        final user = _auth.currentUser;
        if (user != null) {
          debugPrint('[DEBUG] TaskService: Logging task_deleted activity event');
          await _activityEventService.logEvent(
            userId: user.uid,
            userName: user.displayName ?? 'Unknown User',
            activityType: 'task_deleted',
            userProfilePicture: user.photoURL,
            boardId: taskData.taskBoardId.isNotEmpty
                ? taskData.taskBoardId
                : null,
            taskId: taskData.taskId,
            description: 'deleted a task',
            metadata: {
              'taskTitle': taskData.taskTitle,
              if ((taskData.taskBoardTitle ?? '').trim().isNotEmpty)
                'boardTitle': (taskData.taskBoardTitle ?? '').trim(),
            },
          );
        }
      }

      debugPrint('âœ… Task $taskId permanently deleted');
    } catch (e) {
      debugPrint('âš ï¸ Error hard deleting task: $e');
      rethrow;
    }
  }

  /// Toggle task done status
  Future<void> toggleTaskDone(Task task) async {
    try {
      await _assertTaskNotCompleted(task.taskId);
      final newIsDone = task.taskIsDone;
      final effectiveIsDone = newIsDone;
      final effectiveStatus = task.taskStatus;
      final taskOutcome = newIsDone
          ? Task.outcomeSuccessful
          : (task.effectiveTaskOutcome == Task.outcomeSuccessful
                ? Task.outcomeNone
                : task.effectiveTaskOutcome);
      var completedStepsCount = 0;
      if (effectiveIsDone) {
        completedStepsCount = await _completeRemainingStepsForTask(
          task.taskId,
        );
      }
      await _tasks.doc(task.taskId).update({
        'taskIsDone': effectiveIsDone,
        'taskIsDoneAt': effectiveIsDone ? Timestamp.now() : null,
        'taskStatus': effectiveStatus,
        'taskOutcome': taskOutcome,
        if (effectiveIsDone && completedStepsCount > 0)
          'taskStats.taskStepsDoneCount': FieldValue.increment(
            completedStepsCount,
          ),
      });

      // Update task stats if needed (e.g., task edits count, etc.)
      await _taskStatsService.incrementEditsCount(task.taskId);

      // Log activity event
      final user = _auth.currentUser;
      if (user != null && effectiveIsDone) {
        await _activityEventService.logEvent(
          userId: user.uid,
          userName: user.displayName ?? 'Unknown User',
          activityType: 'task_completed',
          userProfilePicture: user.photoURL,
          boardId: task.taskBoardId.isNotEmpty ? task.taskBoardId : null,
          taskId: task.taskId,
          description: 'completed a task',
          metadata: {
            'taskTitle': task.taskTitle,
            if ((task.taskBoardTitle ?? '').trim().isNotEmpty)
              'boardTitle': (task.taskBoardTitle ?? '').trim(),
          },
        );
      }

      debugPrint('âœ… Task ${task.taskId} done status toggled to $effectiveIsDone');
    } catch (e) {
      debugPrint('âš ï¸ Error toggling task done status: $e');
    }
  }

  Future<int> _completeRemainingStepsForTask(String taskId) async {
    final snapshot = await _firestore
        .collection('steps')
        .where('parentTaskId', isEqualTo: taskId)
        .where('stepIsDeleted', isEqualTo: false)
        .where('stepIsDone', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return 0;

    const chunkSize = 400;
    final docs = snapshot.docs;
    var updatedCount = 0;

    for (var start = 0; start < docs.length; start += chunkSize) {
      final end = (start + chunkSize < docs.length)
          ? start + chunkSize
          : docs.length;
      final batch = _firestore.batch();
      for (var i = start; i < end; i++) {
        batch.update(docs[i].reference, {
          'stepIsDone': true,
          'stepIsDoneAt': Timestamp.now(),
        });
      }
      await batch.commit();
      updatedCount += (end - start);
    }

    return updatedCount;
  }

  /// Stream tasks safely for a specific board or user
  Stream<List<Task>> streamTasks({String? boardId, String? ownerId}) {
    Query query = _tasks.where('taskIsDeleted', isEqualTo: false);

    if (boardId != null) {
      debugPrint('[DEBUG] TaskService: Streaming tasks for boardId = $boardId');
      query = query.where('taskBoardId', isEqualTo: boardId);
    }
    if (ownerId != null) {
      debugPrint('[DEBUG] TaskService: Streaming tasks for ownerId = $ownerId');
      query = query.where('taskOwnerId', isEqualTo: ownerId);
    }

    query = query.orderBy('taskCreatedAt', descending: true);

    return query.snapshots().map((snapshot) {
      final tasks = snapshot.docs
          .map((doc) {
            try {
              final task = Task.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
              if (boardId != null) {
                debugPrint(
                  '[DEBUG] TaskService: Loaded task ${task.taskId} for board $boardId with taskBoardId = ${task.taskBoardId}',
                );
              }
              return task;
            } catch (e) {
              debugPrint('âš ï¸ Error parsing task ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Task>()
          .toList(); // filter out nulls

      if (boardId != null) {
        debugPrint(
          '[DEBUG] TaskService: Returning ${tasks.length} tasks for boardId = $boardId',
        );
      }
      return tasks;
    });
  }

  /// Convenience method for streaming tasks for a board
  Stream<List<Task>> streamTasksByBoardId(String boardId) {
    return streamTasks(boardId: boardId);
  }

  /// Stream tasks by a list of task IDs
  Stream<List<Task>> streamTasksByIds(List<String> taskIds) {
    if (taskIds.isEmpty) {
      return Stream.value([]);
    }

    // Firestore has a limit of 10 items for "in" queries, so we need to batch them
    const batchSize = 10;
    final batches = <List<String>>[];

    for (var i = 0; i < taskIds.length; i += batchSize) {
      final end = (i + batchSize < taskIds.length)
          ? i + batchSize
          : taskIds.length;
      batches.add(taskIds.sublist(i, end));
    }

    // If only one batch, return it directly
    if (batches.length == 1) {
      return _tasks
          .where(FieldPath.documentId, whereIn: batches[0])
          .where('taskIsDeleted', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) {
                  try {
                    return Task.fromMap(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    );
                  } catch (e) {
                    debugPrint('âš ï¸ Error parsing task ${doc.id}: $e');
                    return null;
                  }
                })
                .whereType<Task>()
                .toList();
          });
    }

    // For multiple batches, keep all batch subscriptions live and merge updates.
    final streams = batches.map((batch) {
      return _tasks
          .where(FieldPath.documentId, whereIn: batch)
          .where('taskIsDeleted', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) {
                  try {
                    return Task.fromMap(
                      doc.data() as Map<String, dynamic>,
                      doc.id,
                    );
                  } catch (e) {
                    debugPrint('âš ï¸ Error parsing task ${doc.id}: $e');
                    return null;
                  }
                })
                .whereType<Task>()
                .toList();
          });
    }).toList();

    final idOrder = <String, int>{};
    for (var i = 0; i < taskIds.length; i++) {
      idOrder[taskIds[i]] = i;
    }

    return Stream<List<Task>>.multi((multi) {
      final latestByBatch = <int, List<Task>>{};
      final subscriptions = <StreamSubscription<List<Task>>>[];

      void emitMerged() {
        final merged = <Task>[];
        for (var i = 0; i < streams.length; i++) {
          final batchTasks = latestByBatch[i];
          if (batchTasks != null) {
            merged.addAll(batchTasks);
          }
        }

        merged.sort((a, b) {
          final ai = idOrder[a.taskId] ?? taskIds.length;
          final bi = idOrder[b.taskId] ?? taskIds.length;
          return ai.compareTo(bi);
        });

        multi.add(merged);
      }

      for (var i = 0; i < streams.length; i++) {
        final index = i;
        subscriptions.add(
          streams[index].listen((tasks) {
            latestByBatch[index] = tasks;
            emitMerged();
          }, onError: multi.addError),
        );
      }

      multi.onCancel = () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
      };
    });
  }

  Stream<List<Task>> streamTasksAssignedTo(String userId) {
    return _tasks
        .where('taskAssignedTo', isEqualTo: userId)
        .where('taskIsDeleted', isEqualTo: false)
        .orderBy('taskCreatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  return Task.fromMap(
                    doc.data() as Map<String, dynamic>,
                    doc.id,
                  );
                } catch (e) {
                  debugPrint('âš ï¸ Error parsing task ${doc.id}: $e');
                  return null;
                }
              })
              .whereType<Task>()
              .toList();
        });
  }

  /// Get a single task by ID
  Future<Task?> getTaskById(String taskId) async {
    try {
      final doc = await _tasks.doc(taskId).get();
      if (doc.exists && doc.data() != null) {
        return Task.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
    } catch (e) {
      debugPrint('âš ï¸ Error fetching task $taskId: $e');
    }
    return null;
  }

  /// Fetch TaskStats for a given task
  Future<TaskStats?> getTaskStatsById(String taskId) async {
    return await _taskStatsService.getTaskStatsById(taskId);
  }

  /// Request to volunteer for an unassigned task or help with a declined task
  Future<void> volunteerForTask(
    String taskId,
    String userId,
    String userName,
  ) async {
    try {
      final task = await getTaskById(taskId);
      if (task == null) return;

      // Check if user already has a pending request
      final existingRequest = await _firestore
          .collection('task_volunteer_requests')
          .where('taskId', isEqualTo: taskId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        debugPrint('âš ï¸ User already has a pending volunteer request for this task');
        return;
      }

      // Create volunteer request
      final requestId = _firestore
          .collection('task_volunteer_requests')
          .doc()
          .id;
      await _firestore
          .collection('task_volunteer_requests')
          .doc(requestId)
          .set({
            'taskId': taskId,
            'boardId': task.taskBoardId,
            'userId': userId,
            'userName': userName,
            'status': 'pending',
            'createdAt': Timestamp.now(),
            'respondedAt': null,
            'respondedBy': null,
            'respondedByName': null,
          });

      await _activityEventService.logEvent(
        userId: userId,
        userName: userName,
        activityType: 'task_volunteer_requested',
        boardId: task.taskBoardId.isNotEmpty ? task.taskBoardId : null,
        taskId: taskId,
        description: 'requested to volunteer for a task',
        metadata: {'taskTitle': task.taskTitle, 'requestId': requestId},
      );

      debugPrint('âœ… $userName requested to volunteer for task $taskId');
    } catch (e) {
      debugPrint('âš ï¸ Error creating volunteer request: $e');
    }
  }

}



