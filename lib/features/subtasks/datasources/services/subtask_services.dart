import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/subtask_model.dart';
import '../../../../shared/features/users/datasources/services/activity_event_services.dart';

class SubtaskService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _subtaskCollection =
      FirebaseFirestore.instance.collection('subtasks');
  final ActivityEventService _activityEventService = ActivityEventService();

  static const Duration recycleBinRetention = Duration(days: 30);

  // ------------------------
  // STREAMS
  // ------------------------

  Stream<List<Subtask>> streamSubtasksByTaskId(String taskId) {
    return _subtaskCollection
        .where('parentTaskId', isEqualTo: taskId)
        .where('subtaskIsDeleted', isEqualTo: false)
        .orderBy('subtaskCreatedAt', descending: true)
        .snapshots()
        .map(_mapSubtaskSnapshot);
  }

  Stream<List<Subtask>> streamActiveSubtasksByTaskId(String taskId) {
    return _subtaskCollection
        .where('parentTaskId', isEqualTo: taskId)
        .where('subtaskIsDone', isEqualTo: false)
        .where('subtaskIsDeleted', isEqualTo: false)
        .orderBy('subtaskCreatedAt', descending: true)
        .snapshots()
        .map(_mapSubtaskSnapshot);
  }

  Stream<List<Subtask>> streamDeletedSubtasks() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _subtaskCollection
        .where('subtaskOwnerId', isEqualTo: user.uid)
        .where('subtaskIsDeleted', isEqualTo: true)
        .orderBy('subtaskDeletedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final now = DateTime.now();
      final subtasks = _mapSubtaskSnapshot(snapshot);

      // Auto-permanently delete expired subtasks
      for (var subtask in subtasks) {
        if (subtask.subtaskDeletedAt != null &&
            now.difference(subtask.subtaskDeletedAt!).abs() > recycleBinRetention) {
          _permanentlyDeleteSubtask(subtask.subtaskId);
        }
      }

      return subtasks;
    });
  }

  // ------------------------
  // CRUD
  // ------------------------

  Future<void> addSubtask({
    required String subtaskTaskId,
    required String subtaskBoardId,
    String? subtaskTitle,
    String? subtaskDescription,
    bool initialDone = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not signed in");

    final subtaskRef = _subtaskCollection.doc();
    final newSubtask = Subtask(
      subtaskId: subtaskRef.id,
      parentTaskId: subtaskTaskId,
      subtaskBoardId: subtaskBoardId,
      subtaskOwnerId: user.uid,
      subtaskOwnerName: user.displayName ?? 'Unknown',
      subtaskCreatedAt: DateTime.now(),
      subtaskDeletedAt: null,
      subtaskIsDeleted: false,
      subtaskTitle: (subtaskTitle?.isNotEmpty ?? false)
          ? subtaskTitle!
          : 'Untitled Subtask',
      subtaskDescription: (subtaskDescription?.trim().isEmpty ?? true)
          ? null
          : subtaskDescription!.trim(),
      subtaskIsDone: initialDone,
      subtaskIsDoneAt: initialDone ? DateTime.now() : null,
      subtaskStatsAmountOfTimesEdited: 0,
    );

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final taskRef = FirebaseFirestore.instance.collection('tasks').doc(subtaskTaskId);
      final taskSnapshot = await transaction.get(taskRef);

      transaction.set(subtaskRef, newSubtask.toMap());

      if (taskSnapshot.exists) {
        transaction.update(
          taskRef,
          {
            'taskStats.taskSubtasksCount': FieldValue.increment(1),
            if (initialDone)
              'taskStats.taskSubtasksDoneCount': FieldValue.increment(1),
          },
        );
      }
    });

    // Log activity event
    try {
      await _activityEventService.logEvent(
        userId: user.uid,
        userName: user.displayName ?? 'Unknown User',
        activityType: 'subtask_created',
        userProfilePicture: user.photoURL,
        boardId: subtaskBoardId,
        taskId: subtaskTaskId,
        description: 'created a subtask',
        metadata: {'subtaskTitle': newSubtask.subtaskTitle},
      );
    } catch (e) {
      print('[ERROR] Failed to log subtask created event: $e');
    }
  }

  Future<void> toggleSubtaskDoneStatus(Subtask subtask) async {
    final updatedSubtask = subtask.copyWith(
      subtaskIsDone: !subtask.subtaskIsDone,
      subtaskIsDoneAt: !subtask.subtaskIsDone ? DateTime.now() : null,
    );

    await updateSubtask(subtask.subtaskId, updatedSubtask);

    if ((subtask.parentTaskId).isNotEmpty) {
      await _incrementTaskSubtaskStats(
        subtask.parentTaskId,
        doneDelta: updatedSubtask.subtaskIsDone ? 1 : -1,
      );
    }

    // Log activity event if subtask was completed
    if (updatedSubtask.subtaskIsDone) {
      final user = _auth.currentUser;
      if (user != null) {
        try {
          await _activityEventService.logEvent(
            userId: user.uid,
            userName: user.displayName ?? 'Unknown User',
            activityType: 'subtask_completed',
            userProfilePicture: user.photoURL,
            boardId: subtask.subtaskBoardId,
            taskId: subtask.parentTaskId,
            description: 'completed a subtask',
            metadata: {'subtaskTitle': subtask.subtaskTitle},
          );
        } catch (e) {
          print('[ERROR] Failed to log subtask completed event: $e');
        }
      }
    }
  }

  Future<void> deleteSubtask(String subtaskId) async {
    await _subtaskCollection.doc(subtaskId).delete();
  }

  Future<void> softDeleteSubtask(Subtask subtask) async {
    final updatedSubtask = subtask.copyWith(
      subtaskIsDeleted: true,
      subtaskDeletedAt: DateTime.now(),
    );

    await updateSubtask(subtask.subtaskId, updatedSubtask);

    if ((subtask.parentTaskId).isNotEmpty) {
      await _incrementTaskSubtaskStats(
        subtask.parentTaskId,
        totalDelta: -1,
        deletedDelta: 1,
        doneDelta: subtask.subtaskIsDone ? -1 : 0,
      );
    }

    // Log activity event
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _activityEventService.logEvent(
          userId: user.uid,
          userName: user.displayName ?? 'Unknown User',
          activityType: 'subtask_deleted',
          userProfilePicture: user.photoURL,
          boardId: subtask.subtaskBoardId,
          taskId: subtask.parentTaskId,
          description: 'deleted a subtask',
          metadata: {'subtaskTitle': subtask.subtaskTitle},
        );
      } catch (e) {
        print('[ERROR] Failed to log subtask deleted event: $e');
      }
    }
  }

  Future<void> restoreSubtask(Subtask subtask) async {
    final updatedSubtask = subtask.copyWith(
      subtaskIsDeleted: false,
      subtaskDeletedAt: null,
    );

    await updateSubtask(subtask.subtaskId, updatedSubtask);

    if ((subtask.parentTaskId).isNotEmpty) {
      await _incrementTaskSubtaskStats(
        subtask.parentTaskId,
        totalDelta: 1,
        deletedDelta: -1,
        doneDelta: subtask.subtaskIsDone ? 1 : 0,
      );
    }

    // Log activity event
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _activityEventService.logEvent(
          userId: user.uid,
          userName: user.displayName ?? 'Unknown User',
          activityType: 'subtask_restored',
          userProfilePicture: user.photoURL,
          boardId: subtask.subtaskBoardId,
          taskId: subtask.parentTaskId,
          description: 'restored a subtask',
          metadata: {'subtaskTitle': subtask.subtaskTitle},
        );
      } catch (e) {
        print('[ERROR] Failed to log subtask restored event: $e');
      }
    }
  }

  Future<void> updateSubtask(String subtaskId, Subtask updatedSubtask) async {
    await _subtaskCollection.doc(subtaskId).update(updatedSubtask.toMap());
  }

  Future<Subtask?> getSubtaskById(String subtaskId) async {
    final doc = await _subtaskCollection.doc(subtaskId).get();
    if (!doc.exists) return null;
    return Subtask.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<Subtask?> getLatestActiveSubtaskForTask(String taskId) async {
    final snapshot = await _subtaskCollection
        .where('parentTaskId', isEqualTo: taskId)
        .where('subtaskIsDone', isEqualTo: false)
        .where('subtaskIsDeleted', isEqualTo: false)
        .orderBy('subtaskCreatedAt', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return Subtask.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<void> _permanentlyDeleteSubtask(String subtaskId) async {
    await _subtaskCollection.doc(subtaskId).delete();
  }

  // ------------------------
  // HELPERS
  // ------------------------

  Future<void> _incrementTaskSubtaskStats(
    String taskId, {
    int totalDelta = 0,
    int doneDelta = 0,
    int deletedDelta = 0,
  }) async {
    final taskRef = FirebaseFirestore.instance.collection('tasks').doc(taskId);
    final updates = <String, dynamic>{};
    if (totalDelta != 0) {
      updates['taskStats.taskSubtasksCount'] = FieldValue.increment(totalDelta);
    }
    if (doneDelta != 0) {
      updates['taskStats.taskSubtasksDoneCount'] = FieldValue.increment(
        doneDelta,
      );
    }
    if (deletedDelta != 0) {
      updates['taskStats.taskSubtasksDeletedCount'] = FieldValue.increment(
        deletedDelta,
      );
    }
    if (updates.isEmpty) return;
    await taskRef.update(updates);
  }

  Future<bool> hasActiveSubtasksForTask(String taskId) async {
    final snapshot = await _subtaskCollection
        .where('parentTaskId', isEqualTo: taskId)
        .where('subtaskIsDeleted', isEqualTo: false)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  List<Subtask> _mapSubtaskSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs
        .map((doc) => Subtask.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
}
