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

  /// Add a new task
  Future<void> addTask(Task task) async {
    try {
      // Add task to the 'tasks' collection
      await _tasks.doc(task.taskId).set(task.toMap());

      // Add task stats to the 'task_stats' collection using TaskStatsService
      await _taskStatsService.addTaskStats(task.taskId, task.taskStats);

      // Log activity event
      final user = _auth.currentUser;
      if (user != null) {
        await _activityEventService.logEvent(
          userId: user.uid,
          userName: user.displayName ?? 'Unknown User',
          activityType: 'task_created',
          userProfilePicture: user.photoURL,
          boardId: task.taskBoardId.isNotEmpty ? task.taskBoardId : null,
          taskId: task.taskId,
          description: 'created a task',
          metadata: {'taskTitle': task.taskTitle},
        );
      }

      print('✅ Task ${task.taskId} added successfully');
    } catch (e) {
      print('⚠️ Error adding task: $e');
    }
  }

  /// Update existing task
  Future<void> updateTask(Task task) async {
    try {
      // Update task in the 'tasks' collection
      await _tasks.doc(task.taskId).update(task.toMap());

      // Update task stats in the 'task_stats' collection using TaskStatsService
      await _taskStatsService.updateTaskStats(task.taskId, task.taskStats);

      print('✅ Task ${task.taskId} updated successfully');
    } catch (e) {
      print('⚠️ Error updating task: $e');
    }
  }

  /// Soft-delete a task
  Future<void> softDeleteTask(Task task) async {
    try {
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
      // Get task data if not provided (for activity logging)
      Task? taskData = task;
      if (taskData == null) {
        taskData = await getTaskById(taskId);
      }

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
            boardId: taskData.taskBoardId.isNotEmpty ? taskData.taskBoardId : null,
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
      final newIsDone = !task.taskIsDone;
      await _tasks.doc(task.taskId).update({
        'taskIsDone': newIsDone,
        'taskIsDoneAt': newIsDone ? Timestamp.now() : null,
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

  /// Stream tasks safely for a specific board or user
  Stream<List<Task>> streamTasks({String? boardId, String? ownerId}) {
    Query query = _tasks.where('taskIsDeleted', isEqualTo: false);

    if (boardId != null) query = query.where('taskBoardId', isEqualTo: boardId);
    if (ownerId != null) query = query.where('taskOwnerId', isEqualTo: ownerId);

    query = query.orderBy('taskCreatedAt', descending: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) {
            try {
              return Task.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            } catch (e) {
              print('⚠️ Error parsing task ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Task>()
          .toList(); // filter out nulls
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
      final end = (i + batchSize < taskIds.length) ? i + batchSize : taskIds.length;
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
                return Task.fromMap(doc.data() as Map<String, dynamic>, doc.id);
              } catch (e) {
                print('⚠️ Error parsing task ${doc.id}: $e');
                return null;
              }
            })
            .whereType<Task>()
            .toList();
      });
    }

    // For multiple batches, combine the streams
    final streams = batches.map((batch) {
      return _tasks
          .where(FieldPath.documentId, whereIn: batch)
          .where('taskIsDeleted', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) {
              try {
                return Task.fromMap(doc.data() as Map<String, dynamic>, doc.id);
              } catch (e) {
                print('⚠️ Error parsing task ${doc.id}: $e');
                return null;
              }
            })
            .whereType<Task>()
            .toList();
      });
    }).toList();

    // Combine all batch streams into one
    return streams[0].asyncMap((firstBatch) async {
      final allTasks = <Task>[...firstBatch];
      for (var i = 1; i < streams.length; i++) {
        final batch = await streams[i].first;
        allTasks.addAll(batch);
      }
      return allTasks;
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
      await _tasks.doc(taskId).update({'taskAcceptanceStatus': 'accepted'});

      print('✅ Task $taskId accepted by $userName');
    } catch (e) {
      print('⚠️ Error accepting task: $e');
    }
  }

  /// Decline a task (user indicates "I need help")
  Future<void> declineTask(
    String taskId,
    String userId,
    String userName,
  ) async {
    try {
      await _tasks.doc(taskId).update({'taskAcceptanceStatus': 'declined'});

      print('✅ Task $taskId declined by $userName');
    } catch (e) {
      print('⚠️ Error declining task: $e');
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
      final existingRequest =
          await _firestore
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
      final requestId =
          _firestore.collection('task_volunteer_requests').doc().id;
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

      print('✅ $userName requested to volunteer for task $taskId');
    } catch (e) {
      print('⚠️ Error creating volunteer request: $e');
    }
  }

  /// Accept a volunteer request (manager only)
  Future<void> acceptVolunteerRequest(
    String requestId,
    String managerId,
    String managerName,
  ) async {
    try {
      // Get the request
      final requestDoc =
          await _firestore
              .collection('task_volunteer_requests')
              .doc(requestId)
              .get();

      if (!requestDoc.exists) {
        print('⚠️ Volunteer request not found');
        return;
      }

      final requestData = requestDoc.data()!;
      final taskId = requestData['taskId'] as String;
      final userId = requestData['userId'] as String;
      final userName = requestData['userName'] as String;
      final boardId = requestData['boardId'] as String;

      // Get the task
      final task = await getTaskById(taskId);
      if (task == null) return;

      // Check if this is for an unassigned task or to help
      if (task.taskAssignedTo.isEmpty) {
        // Unassigned task - assign to volunteer
        await _tasks.doc(taskId).update({
          'taskAssignedTo': userId,
          'taskAssignedToName': userName,
          'taskAcceptanceStatus': 'accepted',
        });
      } else {
        // Task needs help - add to helpers list
        final updatedHelpers = List<String>.from(task.taskHelpers);
        final updatedHelperNames = Map<String, String>.from(
          task.taskHelperNames,
        );

        if (!updatedHelpers.contains(userId)) {
          updatedHelpers.add(userId);
          updatedHelperNames[userId] = userName;

          await _tasks.doc(taskId).update({
            'taskHelpers': updatedHelpers,
            'taskHelperNames': updatedHelperNames,
          });
        }
      }

      // Update request status
      await _firestore
          .collection('task_volunteer_requests')
          .doc(requestId)
          .update({
            'status': 'accepted',
            'respondedAt': Timestamp.now(),
            'respondedBy': managerId,
            'respondedByName': managerName,
          });

      print('✅ Volunteer request $requestId accepted by $managerName');
    } catch (e) {
      print('⚠️ Error accepting volunteer request: $e');
    }
  }

  /// Decline a volunteer request (manager only)
  Future<void> declineVolunteerRequest(
    String requestId,
    String managerId,
    String managerName,
  ) async {
    try {
      // Get the request
      final requestDoc =
          await _firestore
              .collection('task_volunteer_requests')
              .doc(requestId)
              .get();

      if (!requestDoc.exists) {
        print('⚠️ Volunteer request not found');
        return;
      }

      final requestData = requestDoc.data()!;
      final taskId = requestData['taskId'] as String;
      final userName = requestData['userName'] as String;
      final boardId = requestData['boardId'] as String;

      // Get the task
      final task = await getTaskById(taskId);
      if (task == null) return;

      // Update request status
      await _firestore
          .collection('task_volunteer_requests')
          .doc(requestId)
          .update({
            'status': 'declined',
            'respondedAt': Timestamp.now(),
            'respondedBy': managerId,
            'respondedByName': managerName,
          });

      print('✅ Volunteer request $requestId declined by $managerName');
    } catch (e) {
      print('⚠️ Error declining volunteer request: $e');
    }
  }

  /// Stream volunteer requests for a board
  Stream<List<Map<String, dynamic>>> streamVolunteerRequests(String boardId) {
    return _firestore
        .collection('task_volunteer_requests')
        .where('boardId', isEqualTo: boardId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['requestId'] = doc.id;
            return data;
          }).toList();
        });
  }
}
