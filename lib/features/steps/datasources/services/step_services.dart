import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/step_model.dart';
import '../../../../shared/features/users/datasources/services/activity_event_services.dart';

class StepService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _stepCollection = FirebaseFirestore.instance
      .collection('steps');
  final ActivityEventService _activityEventService = ActivityEventService();

  static const Duration recycleBinRetention = Duration(days: 30);

  Future<void> _assertParentTaskNotCompleted(String taskId) async {
    final taskDoc = await FirebaseFirestore.instance
        .collection('tasks')
        .doc(taskId)
        .get();
    if (!taskDoc.exists) return;
    final data = taskDoc.data();
    final isDone = data?['taskIsDone'] as bool? ?? false;
    if (isDone) {
      throw StateError(
        'This task is completed and locked. Steps can no longer be changed.',
      );
    }
  }

  // ------------------------
  // STREAMS
  // ------------------------

  Stream<List<TaskStep>> streamStepsByTaskId(String taskId) {
    return _stepCollection
        .where('parentTaskId', isEqualTo: taskId)
        .where('stepIsDeleted', isEqualTo: false)
        .orderBy('stepCreatedAt', descending: false)
        .snapshots()
        .map((snapshot) {
          final steps = _mapStepSnapshot(snapshot);
          steps.sort(_stepSortComparator);
          return steps;
        });
  }

  Stream<List<TaskStep>> streamActiveStepsByTaskId(String taskId) {
    return _stepCollection
        .where('parentTaskId', isEqualTo: taskId)
        .where('stepIsDone', isEqualTo: false)
        .where('stepIsDeleted', isEqualTo: false)
        .orderBy('stepCreatedAt', descending: false)
        .snapshots()
        .map((snapshot) {
          final steps = _mapStepSnapshot(snapshot);
          steps.sort(_stepSortComparator);
          return steps;
        });
  }

  Stream<List<TaskStep>> streamDeletedSteps() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _stepCollection
        .where('stepOwnerId', isEqualTo: user.uid)
        .where('stepIsDeleted', isEqualTo: true)
        .orderBy('stepDeletedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          final steps = _mapStepSnapshot(snapshot);

          // Auto-permanently delete expired steps
          for (var step in steps) {
            if (step.stepDeletedAt != null &&
                now.difference(step.stepDeletedAt!).abs() >
                    recycleBinRetention) {
              _permanentlyDeleteStep(step.stepId);
            }
          }

          return steps;
        });
  }

  // ------------------------
  // CRUD
  // ------------------------

  Future<void> addStep({
    required String stepTaskId,
    required String stepBoardId,
    String? stepTitle,
    String? stepDescription,
    bool initialDone = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not signed in");
    await _assertParentTaskNotCompleted(stepTaskId);

    final stepRef = _stepCollection.doc();
    final order = await _nextStepOrder(stepTaskId);
    final newStep = TaskStep(
      stepId: stepRef.id,
      parentTaskId: stepTaskId,
      stepBoardId: stepBoardId,
      stepOwnerId: user.uid,
      stepOwnerName: user.displayName ?? 'Unknown',
      stepCreatedAt: DateTime.now(),
      stepDeletedAt: null,
      stepIsDeleted: false,
      stepTitle: (stepTitle?.isNotEmpty ?? false)
          ? stepTitle!
          : 'Untitled Step',
      stepDescription: (stepDescription?.trim().isEmpty ?? true)
          ? null
          : stepDescription!.trim(),
      stepIsDone: initialDone,
      stepIsDoneAt: initialDone ? DateTime.now() : null,
      stepOrder: order,
      stepStatsAmountOfTimesEdited: 0,
    );

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final taskRef = FirebaseFirestore.instance
          .collection('tasks')
          .doc(stepTaskId);
      final taskSnapshot = await transaction.get(taskRef);

      transaction.set(stepRef, newStep.toMap());

      if (taskSnapshot.exists) {
        transaction.update(taskRef, {
          'taskStats.taskStepsCount': FieldValue.increment(1),
          if (initialDone)
            'taskStats.taskStepsDoneCount': FieldValue.increment(1),
        });
      }
    });

    // Log activity event
    try {
      await _activityEventService.logEvent(
        userId: user.uid,
        userName: user.displayName ?? 'Unknown User',
        activityType: 'step_created',
        userProfilePicture: user.photoURL,
        boardId: stepBoardId,
        taskId: stepTaskId,
        description: 'created a step',
        metadata: {'stepTitle': newStep.stepTitle},
      );
    } catch (e) {
      debugPrint('[ERROR] Failed to log step created event: $e');
    }
  }

  Future<void> toggleStepDoneStatus(TaskStep step) async {
    await _assertParentTaskNotCompleted(step.parentTaskId);
    final updatedStep = step.copyWith(
      stepIsDone: !step.stepIsDone,
      stepIsDoneAt: !step.stepIsDone ? DateTime.now() : null,
    );

    await updateStep(step.stepId, updatedStep);

    if ((step.parentTaskId).isNotEmpty) {
      await _incrementTaskStepStats(
        step.parentTaskId,
        doneDelta: updatedStep.stepIsDone ? 1 : -1,
      );
    }

    // Log activity event if step was completed
    if (updatedStep.stepIsDone) {
      final user = _auth.currentUser;
      if (user != null) {
        try {
          await _activityEventService.logEvent(
            userId: user.uid,
            userName: user.displayName ?? 'Unknown User',
            activityType: 'step_completed',
            userProfilePicture: user.photoURL,
            boardId: step.stepBoardId,
            taskId: step.parentTaskId,
            description: 'completed a step',
            metadata: {'stepTitle': step.stepTitle},
          );
        } catch (e) {
          debugPrint('[ERROR] Failed to log step completed event: $e');
        }
      }
    }
  }

  Future<void> deleteStep(String stepId) async {
    final step = await getStepById(stepId);
    if (step != null) {
      await _assertParentTaskNotCompleted(step.parentTaskId);
    }
    await _stepCollection.doc(stepId).delete();
  }

  Future<void> softDeleteStep(TaskStep step) async {
    await _assertParentTaskNotCompleted(step.parentTaskId);
    final updatedStep = step.copyWith(
      stepIsDeleted: true,
      stepDeletedAt: DateTime.now(),
    );

    await updateStep(step.stepId, updatedStep);

    if ((step.parentTaskId).isNotEmpty) {
      await _incrementTaskStepStats(
        step.parentTaskId,
        totalDelta: -1,
        deletedDelta: 1,
        doneDelta: step.stepIsDone ? -1 : 0,
      );
    }

    // Log activity event
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _activityEventService.logEvent(
          userId: user.uid,
          userName: user.displayName ?? 'Unknown User',
          activityType: 'step_deleted',
          userProfilePicture: user.photoURL,
          boardId: step.stepBoardId,
          taskId: step.parentTaskId,
          description: 'deleted a step',
          metadata: {'stepTitle': step.stepTitle},
        );
      } catch (e) {
        debugPrint('[ERROR] Failed to log step deleted event: $e');
      }
    }
  }

  Future<void> restoreStep(TaskStep step) async {
    await _assertParentTaskNotCompleted(step.parentTaskId);
    final updatedStep = step.copyWith(
      stepIsDeleted: false,
      stepDeletedAt: null,
    );

    await updateStep(step.stepId, updatedStep);

    if ((step.parentTaskId).isNotEmpty) {
      await _incrementTaskStepStats(
        step.parentTaskId,
        totalDelta: 1,
        deletedDelta: -1,
        doneDelta: step.stepIsDone ? 1 : 0,
      );
    }

    // Log activity event
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _activityEventService.logEvent(
          userId: user.uid,
          userName: user.displayName ?? 'Unknown User',
          activityType: 'step_restored',
          userProfilePicture: user.photoURL,
          boardId: step.stepBoardId,
          taskId: step.parentTaskId,
          description: 'restored a step',
          metadata: {'stepTitle': step.stepTitle},
        );
      } catch (e) {
        debugPrint('[ERROR] Failed to log step restored event: $e');
      }
    }
  }

  Future<void> updateStep(String stepId, TaskStep updatedStep) async {
    await _assertParentTaskNotCompleted(updatedStep.parentTaskId);
    await _stepCollection.doc(stepId).update(updatedStep.toMap());
  }

  Future<void> swapStepOrder(TaskStep first, TaskStep second) async {
    if (first.parentTaskId != second.parentTaskId) {
      throw StateError('Cannot reorder steps from different parent tasks.');
    }

    await _assertParentTaskNotCompleted(first.parentTaskId);

    final firstOrder = _resolveStepOrder(first);
    final secondOrder = _resolveStepOrder(second);

    final firstRef = _stepCollection.doc(first.stepId);
    final secondRef = _stepCollection.doc(second.stepId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.update(firstRef, {'stepOrder': secondOrder});
      transaction.update(secondRef, {'stepOrder': firstOrder});
    });
  }

  Future<void> reorderSteps(
    String taskId,
    List<TaskStep> orderedSteps,
  ) async {
    if (orderedSteps.isEmpty) return;
    await _assertParentTaskNotCompleted(taskId);

    final nowBase = DateTime.now().microsecondsSinceEpoch;
    final batch = FirebaseFirestore.instance.batch();

    for (int i = 0; i < orderedSteps.length; i++) {
      final step = orderedSteps[i];
      if (step.parentTaskId != taskId) continue;
      final ref = _stepCollection.doc(step.stepId);
      batch.update(ref, {'stepOrder': nowBase + i});
    }

    await batch.commit();
  }

  Future<TaskStep?> getStepById(String stepId) async {
    final doc = await _stepCollection.doc(stepId).get();
    if (!doc.exists) return null;
    return TaskStep.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<TaskStep?> getLatestActiveStepForTask(String taskId) async {
    final snapshot = await _stepCollection
        .where('parentTaskId', isEqualTo: taskId)
        .where('stepIsDone', isEqualTo: false)
        .where('stepIsDeleted', isEqualTo: false)
        .orderBy('stepCreatedAt', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return TaskStep.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<void> _permanentlyDeleteStep(String stepId) async {
    await _stepCollection.doc(stepId).delete();
  }

  // ------------------------
  // HELPERS
  // ------------------------

  Future<void> _incrementTaskStepStats(
    String taskId, {
    int totalDelta = 0,
    int doneDelta = 0,
    int deletedDelta = 0,
  }) async {
    final taskRef = FirebaseFirestore.instance.collection('tasks').doc(taskId);
    final updates = <String, dynamic>{};
    if (totalDelta != 0) {
      updates['taskStats.taskStepsCount'] = FieldValue.increment(totalDelta);
    }
    if (doneDelta != 0) {
      updates['taskStats.taskStepsDoneCount'] = FieldValue.increment(
        doneDelta,
      );
    }
    if (deletedDelta != 0) {
      updates['taskStats.taskStepsDeletedCount'] = FieldValue.increment(
        deletedDelta,
      );
    }
    if (updates.isEmpty) return;
    await taskRef.update(updates);
  }

  Future<bool> hasActiveStepsForTask(String taskId) async {
    final snapshot = await _stepCollection
        .where('parentTaskId', isEqualTo: taskId)
        .where('stepIsDeleted', isEqualTo: false)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  List<TaskStep> _mapStepSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs
        .map(
          (doc) => TaskStep.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  int _resolveStepOrder(TaskStep step) {
    return step.stepOrder ??
        step.stepCreatedAt.microsecondsSinceEpoch;
  }

  int _stepSortComparator(TaskStep a, TaskStep b) {
    if (a.stepIsDone != b.stepIsDone) {
      return a.stepIsDone ? 1 : -1;
    }

    final orderCompare = _resolveStepOrder(
      a,
    ).compareTo(_resolveStepOrder(b));
    if (orderCompare != 0) return orderCompare;

    return a.stepCreatedAt.compareTo(b.stepCreatedAt);
  }

  Future<int> _nextStepOrder(String taskId) async {
    final snapshot = await _stepCollection
        .where('parentTaskId', isEqualTo: taskId)
        .where('stepIsDeleted', isEqualTo: false)
        .get();

    var maxOrder = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final model = TaskStep.fromMap(data, doc.id);
      final order = _resolveStepOrder(model);
      if (order > maxOrder) maxOrder = order;
    }

    if (maxOrder == 0) {
      return DateTime.now().microsecondsSinceEpoch;
    }
    return maxOrder + 1;
  }
}



