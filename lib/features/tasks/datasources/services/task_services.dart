import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task_model.dart'; // Ensure TaskModel is imported
import '../models/task_stats_model.dart'; // Ensure TaskStats is imported
import 'task_stats_services.dart';
import '../../../../shared/features/users/datasources/services/activity_event_services.dart';
import '../../../notifications/datasources/helpers/notification_helper.dart';

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
      taskAcceptanceStatus: null,
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
          boardId: normalizedTask.taskBoardId.isNotEmpty
              ? normalizedTask.taskBoardId
              : null,
          taskId: normalizedTask.taskId,
          description: 'created a task',
          metadata: {'taskTitle': normalizedTask.taskTitle},
        );
      }

      // Send deadline notification if task has a deadline
      if (normalizedTask.taskDeadline != null &&
          normalizedTask.taskBoardId.isNotEmpty) {
        print(
          '[Notification] Task has deadline: ${normalizedTask.taskDeadline}, sending notifications...',
        );
        await _sendDeadlineNotification(normalizedTask);
      } else {
        print(
          '[Notification] Task has no deadline or empty boardId. Deadline: ${normalizedTask.taskDeadline}, BoardId: ${normalizedTask.taskBoardId}',
        );
      }

      print('✅ Task ${normalizedTask.taskId} added successfully');
    } catch (e) {
      print('⚠️ Error adding task: $e');
      rethrow;
    }
  }

  /// Update existing task
  Future<void> updateTask(Task task) async {
    try {
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

      print('✅ Task ${normalizedTask.taskId} updated successfully');
    } catch (e) {
      print('⚠️ Error updating task: $e');
      rethrow;
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
          metadata: {'taskTitle': task.taskTitle},
        );
      }

      print('✅ Task ${task.taskId} soft-deleted');
    } catch (e) {
      print('⚠️ Error soft deleting task: $e');
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
          print('[DEBUG] TaskService: Logging task_deleted activity event');
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
            metadata: {'taskTitle': taskData.taskTitle},
          );
        }
      }

      print('✅ Task $taskId permanently deleted');
    } catch (e) {
      print('⚠️ Error hard deleting task: $e');
      rethrow;
    }
  }

  /// Toggle task done status
  Future<void> toggleTaskDone(Task task) async {
    try {
      await _assertTaskNotCompleted(task.taskId);
      final newIsDone = task.taskIsDone;
      final taskOutcome = newIsDone
          ? Task.outcomeSuccessful
          : (task.effectiveTaskOutcome == Task.outcomeSuccessful
                ? Task.outcomeNone
                : task.effectiveTaskOutcome);
      var completedSubtasksCount = 0;
      if (newIsDone) {
        completedSubtasksCount = await _completeRemainingSubtasksForTask(
          task.taskId,
        );
      }
      await _tasks.doc(task.taskId).update({
        'taskIsDone': newIsDone,
        'taskIsDoneAt': newIsDone ? Timestamp.now() : null,
        'taskStatus': task.taskStatus,
        'taskOutcome': taskOutcome,
        if (newIsDone && completedSubtasksCount > 0)
          'taskStats.taskSubtasksDoneCount': FieldValue.increment(
            completedSubtasksCount,
          ),
      });

      // Update task stats if needed (e.g., task edits count, etc.)
      await _taskStatsService.incrementEditsCount(task.taskId);

      // Log activity event
      final user = _auth.currentUser;
      if (user != null && newIsDone) {
        await _activityEventService.logEvent(
          userId: user.uid,
          userName: user.displayName ?? 'Unknown User',
          activityType: 'task_completed',
          userProfilePicture: user.photoURL,
          boardId: task.taskBoardId.isNotEmpty ? task.taskBoardId : null,
          taskId: task.taskId,
          description: 'completed a task',
          metadata: {'taskTitle': task.taskTitle},
        );
      }

      print('✅ Task ${task.taskId} done status toggled to $newIsDone');
    } catch (e) {
      print('⚠️ Error toggling task done status: $e');
    }
  }

  Future<int> _completeRemainingSubtasksForTask(String taskId) async {
    final snapshot = await _firestore
        .collection('subtasks')
        .where('parentTaskId', isEqualTo: taskId)
        .where('subtaskIsDeleted', isEqualTo: false)
        .where('subtaskIsDone', isEqualTo: false)
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
          'subtaskIsDone': true,
          'subtaskIsDoneAt': Timestamp.now(),
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
      print('[DEBUG] TaskService: Streaming tasks for boardId = $boardId');
      query = query.where('taskBoardId', isEqualTo: boardId);
    }
    if (ownerId != null) {
      print('[DEBUG] TaskService: Streaming tasks for ownerId = $ownerId');
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
                print(
                  '[DEBUG] TaskService: Loaded task ${task.taskId} for board $boardId with taskBoardId = ${task.taskBoardId}',
                );
              }
              return task;
            } catch (e) {
              print('⚠️ Error parsing task ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Task>()
          .toList(); // filter out nulls

      if (boardId != null) {
        print(
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
                    print('⚠️ Error parsing task ${doc.id}: $e');
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
                    print('⚠️ Error parsing task ${doc.id}: $e');
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
                  print('⚠️ Error parsing task ${doc.id}: $e');
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
      print('⚠️ Error fetching task $taskId: $e');
    }
    return null;
  }

  /// Fetch TaskStats for a given task
  Future<TaskStats?> getTaskStatsById(String taskId) async {
    return await _taskStatsService.getTaskStatsById(taskId);
  }

  /// Accept a task (user indicates "I got this")
  Future<void> acceptTask(String taskId, String userId, String userName) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final taskRef = _tasks.doc(taskId);
        final snapshot = await transaction.get(taskRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final proposedId = (data['taskProposedAssigneeId'] as String?)?.trim();
        final proposedName = (data['taskProposedAssigneeName'] as String?)
            ?.trim();

        if (proposedId == null || proposedId.isEmpty || proposedId != userId) {
          throw StateError('No pending assignment found for this user.');
        }

        transaction.update(taskRef, {
          'taskAssignedTo': userId,
          'taskAssignedToName':
              (proposedName != null && proposedName.isNotEmpty)
              ? proposedName
              : userName,
          'taskAcceptanceStatus': 'accepted',
          'taskProposedAssigneeId': FieldValue.delete(),
          'taskProposedAssigneeName': FieldValue.delete(),
        });
      });

      final task = await getTaskById(taskId);
      await _activityEventService.logEvent(
        userId: userId,
        userName: userName,
        activityType: 'task_assignment_accepted',
        boardId: task?.taskBoardId.isNotEmpty == true
            ? task!.taskBoardId
            : null,
        taskId: taskId,
        description: 'accepted a task assignment',
        metadata: {'taskTitle': task?.taskTitle ?? ''},
      );

      print('Task $taskId accepted by $userName');
    } catch (e) {
      print('Error accepting task: $e');
      rethrow;
    }
  }

  /// Decline a task (user indicates "I need help")
  Future<void> declineTask(
    String taskId,
    String userId,
    String userName,
  ) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final taskRef = _tasks.doc(taskId);
        final snapshot = await transaction.get(taskRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final proposedId = (data['taskProposedAssigneeId'] as String?)?.trim();
        if (proposedId == null || proposedId.isEmpty || proposedId != userId) {
          throw StateError('No pending assignment found for this user.');
        }

        transaction.update(taskRef, {
          'taskAssignedTo': 'None',
          'taskAssignedToName': 'Unassigned',
          'taskAcceptanceStatus': 'declined',
          'taskProposedAssigneeId': FieldValue.delete(),
          'taskProposedAssigneeName': FieldValue.delete(),
        });
      });

      final task = await getTaskById(taskId);
      await _activityEventService.logEvent(
        userId: userId,
        userName: userName,
        activityType: 'task_assignment_declined',
        boardId: task?.taskBoardId.isNotEmpty == true
            ? task!.taskBoardId
            : null,
        taskId: taskId,
        description: 'declined a task assignment',
        metadata: {'taskTitle': task?.taskTitle ?? ''},
      );

      print('Task $taskId declined by $userName');
    } catch (e) {
      print('Error declining task: $e');
      rethrow;
    }
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
        print('⚠️ User already has a pending volunteer request for this task');
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

      print('✅ $userName requested to volunteer for task $taskId');
    } catch (e) {
      print('⚠️ Error creating volunteer request: $e');
    }
  }

  /// Send deadline notification to the assigned user
  Future<void> _sendDeadlineNotification(Task task) async {
    try {
      print(
        '[Notification] Task has deadline: ${task.taskDeadline}, sending notifications...',
      );

      // Send notification to the person assigned to the task
      final assignedUserId = task.taskAssignedTo;
      if (assignedUserId.isEmpty || assignedUserId == 'None') {
        print(
          '[Notification] ⚠️ Task has no assignee, skipping deadline notification',
        );
        return;
      }

      print('[Notification] Starting to send deadline notifications...');

      var boardTitle = (task.taskBoardTitle ?? '').trim();
      var boardManagerName = '';
      final taskSummary = _buildTaskSummary(task.taskDescription);

      if (task.taskBoardId.trim().isNotEmpty) {
        try {
          final boardDoc = await _firestore
              .collection('boards')
              .doc(task.taskBoardId)
              .get();
          if (boardDoc.exists) {
            final boardData = boardDoc.data() as Map<String, dynamic>;
            if (boardTitle.isEmpty) {
              boardTitle = (boardData['boardTitle'] as String? ?? '').trim();
            }
            boardManagerName =
                (boardData['boardManagerName'] as String? ?? '').trim();
          }
        } catch (_) {
          // Best effort enrichment for notification content.
        }
      }

      final resolvedBoardTitle = boardTitle.isNotEmpty ? boardTitle : 'Unknown Board';
      final resolvedManagerName = boardManagerName.isNotEmpty
          ? boardManagerName
          : 'Unknown Manager';
      final remainingTime = _formatDeadline(task.taskDeadline!);
      final deadlineSentence =
          '${task.taskTitle} from $resolvedBoardTitle by $resolvedManagerName is due in $remainingTime.';

      await NotificationHelper.createInAppOnly(
        userId: assignedUserId,
        title: 'Task Deadline',
        message: deadlineSentence,
        category: NotificationHelper.categoryTaskDeadline,
        metadata: {
          'taskId': task.taskId,
          'boardId': task.taskBoardId,
          'type': 'task_deadline',
          'taskTitle': task.taskTitle,
          'boardTitle': resolvedBoardTitle,
          'boardManagerName': resolvedManagerName,
          'taskPriorityLevel': task.taskPriorityLevel,
          if (taskSummary.isNotEmpty) 'taskSummary': taskSummary,
          if (task.taskDeadline != null)
            'deadline': task.taskDeadline!.toIso8601String(),
        },
      );
    } catch (e) {
      print('[Notification] ❌ Error sending deadline notification: $e');
    }
  }

  /// Format deadline for display
  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now);

    if (difference.inHours < 1) {
      return '${difference.inMinutes} minutes';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours';
    } else {
      return '${difference.inDays} days';
    }
  }

  String _buildTaskSummary(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    if (text.length <= 180) return text;
    return '${text.substring(0, 177)}...';
  }
}
