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
      subtaskIsDone: false,
      subtaskIsDoneAt: null,
      subtaskStatsAmountOfTimesEdited: 0,
    );

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final taskRef = FirebaseFirestore.instance.collection('tasks').doc(subtaskTaskId);
      final taskSnapshot = await transaction.get(taskRef);

      transaction.set(subtaskRef, newSubtask.toMap());

      if (taskSnapshot.exists) {
        transaction.update(
          taskRef,
          {'taskAmountOfSubtasks': FieldValue.increment(1)},
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
      await _updateTaskSubtasksDoneCount(
          subtask.parentTaskId, delta: updatedSubtask.subtaskIsDone ? 1 : -1);
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
      await _updateTaskSubtaskCount(subtask.parentTaskId, delta: -1);
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
      await _updateTaskSubtaskCount(subtask.parentTaskId, delta: 1);
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

  Future<void> _permanentlyDeleteSubtask(String subtaskId) async {
    await _subtaskCollection.doc(subtaskId).delete();
  }

  // ------------------------
  // HELPERS
  // ------------------------

  Future<void> _updateTaskSubtaskCount(String taskId, {required int delta}) async {
    final taskRef = FirebaseFirestore.instance.collection('tasks').doc(taskId);
    await taskRef.update({
      'taskAmountOfSubtasks': FieldValue.increment(delta),
    });
  }

  Future<void> _updateTaskSubtasksDoneCount(String taskId, {required int delta}) async {
    final taskRef = FirebaseFirestore.instance.collection('tasks').doc(taskId);
    await taskRef.update({
      'taskAmountOfSubtasksDone': FieldValue.increment(delta),
    });
  }

  List<Subtask> _mapSubtaskSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs
        .map((doc) => Subtask.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
}
