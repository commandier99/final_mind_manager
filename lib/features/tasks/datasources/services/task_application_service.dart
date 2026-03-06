import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../notifications/datasources/helpers/notification_helper.dart';
import '../models/task_model.dart';
import '../../../../shared/features/users/datasources/services/activity_event_services.dart';

class TaskApplicationService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ActivityEventService _activityEventService;

  TaskApplicationService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance,
      _activityEventService = ActivityEventService();

  CollectionReference<Map<String, dynamic>> _applicationsRef(String taskId) {
    return _firestore
        .collection('tasks')
        .doc(taskId)
        .collection('applications');
  }

  CollectionReference<Map<String, dynamic>> _legacyAppealsRef(String taskId) {
    return _firestore.collection('tasks').doc(taskId).collection('appeals');
  }

  Future<bool> _canUseApplicationsCollection(String taskId) async {
    try {
      await _applicationsRef(taskId).limit(1).get();
      return true;
    } on FirebaseException catch (e) {
      // If rules/path are not yet deployed for applications, fallback to legacy appeals.
      if (e.code == 'permission-denied') {
        return false;
      }
      rethrow;
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamApplications(
    String taskId,
  ) {
    return Stream.fromFuture(_canUseApplicationsCollection(taskId)).asyncExpand(
      (useApplications) {
        final ref = useApplications
            ? _applicationsRef(taskId)
            : _legacyAppealsRef(taskId);
        return ref.orderBy('createdAt', descending: true).snapshots();
      },
    );
  }

  Stream<bool> hasUserApplied(String taskId, String userId) {
    return Stream.fromFuture(_canUseApplicationsCollection(taskId)).asyncExpand(
      (useApplications) {
        final ref = useApplications
            ? _applicationsRef(taskId)
            : _legacyAppealsRef(taskId);
        return ref
            .where('userId', isEqualTo: userId)
            .snapshots()
            .map((snapshot) => snapshot.docs.isNotEmpty);
      },
    );
  }

  Future<void> submitApplication({
    required String taskId,
    required String userId,
    required String applicationText,
  }) async {
    try {
      await _applicationsRef(taskId).add({
        'userId': userId,
        'applicationText': applicationText,
        // Keep legacy key too so older UI still reads it.
        'appealText': applicationText,
        'createdAt': Timestamp.now(),
      });
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      await _legacyAppealsRef(taskId).add({
        'userId': userId,
        'appealText': applicationText,
        'createdAt': Timestamp.now(),
      });
    }

    final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
    final taskData = taskDoc.data();
    final task = taskData == null ? null : Task.fromMap(taskData, taskDoc.id);
    final applicantDoc = await _firestore.collection('users').doc(userId).get();
    final applicantData = applicantDoc.data();
    final applicantName =
        _auth.currentUser?.displayName ??
        (applicantData?['userName'] as String? ?? 'Unknown User');
    await _activityEventService.logEvent(
      userId: userId,
      userName: applicantName,
      userProfilePicture: _auth.currentUser?.photoURL,
      activityType: 'task_application_submitted',
      boardId: taskData?['taskBoardId'] as String?,
      taskId: taskId,
      description: 'submitted a task application',
      metadata: {'taskTitle': taskData?['taskTitle'] as String? ?? ''},
    );

    if (task != null) {
      await _notifyApplicationReviewers(
        task: task,
        applicantId: userId,
        applicantName: applicantName,
      );
    }
  }

  Future<void> removeUserApplications({
    required String taskId,
    required String userId,
  }) async {
    Future<void> deleteFromRef(
      CollectionReference<Map<String, dynamic>> ref,
    ) async {
      final query = await ref.where('userId', isEqualTo: userId).get();
      for (final doc in query.docs) {
        await doc.reference.delete();
      }
    }

    try {
      await deleteFromRef(_applicationsRef(taskId));
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      await deleteFromRef(_legacyAppealsRef(taskId));
    }

    final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
    final taskData = taskDoc.data();
    await _activityEventService.logEvent(
      userId: userId,
      userName: _auth.currentUser?.displayName ?? 'Unknown User',
      userProfilePicture: _auth.currentUser?.photoURL,
      activityType: 'task_application_withdrawn',
      boardId: taskData?['taskBoardId'] as String?,
      taskId: taskId,
      description: 'withdrew a task application',
      metadata: {'taskTitle': taskData?['taskTitle'] as String? ?? ''},
    );
  }

  Future<void> deleteApplication({
    required String taskId,
    required String applicationDocId,
  }) async {
    Map<String, dynamic>? applicationData;
    try {
      final appDoc = await _applicationsRef(taskId).doc(applicationDocId).get();
      applicationData = appDoc.data();
    } catch (_) {
      // Ignore pre-read errors and continue delete flow.
    }

    try {
      await _applicationsRef(taskId).doc(applicationDocId).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      final legacyDoc = await _legacyAppealsRef(
        taskId,
      ).doc(applicationDocId).get();
      applicationData ??= legacyDoc.data();
      await _legacyAppealsRef(taskId).doc(applicationDocId).delete();
    }

    final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
    final taskData = taskDoc.data();
    final actor = _auth.currentUser;
    if (actor != null) {
      await _activityEventService.logEvent(
        userId: actor.uid,
        userName: actor.displayName ?? 'Unknown User',
        userProfilePicture: actor.photoURL,
        activityType: 'task_application_deleted',
        boardId: taskData?['taskBoardId'] as String?,
        taskId: taskId,
        description: 'deleted a task application',
        metadata: {
          'taskTitle': taskData?['taskTitle'] as String? ?? '',
          'applicationId': applicationDocId,
          'applicationUserId': applicationData?['userId'] as String?,
        },
      );
    }
  }

  Future<void> _notifyApplicationReviewers({
    required Task task,
    required String applicantId,
    required String applicantName,
  }) async {
    final reviewerIds = <String>{};

    if (task.taskOwnerId.isNotEmpty && task.taskOwnerId != applicantId) {
      reviewerIds.add(task.taskOwnerId);
    }

    if (task.taskBoardId.isNotEmpty) {
      final boardDoc = await _firestore
          .collection('boards')
          .doc(task.taskBoardId)
          .get();
      if (boardDoc.exists) {
        final boardData = boardDoc.data() as Map<String, dynamic>;
        final managerId = (boardData['boardManagerId'] as String? ?? '').trim();
        if (managerId.isNotEmpty && managerId != applicantId) {
          reviewerIds.add(managerId);
        }
        final memberRoles = Map<String, dynamic>.from(
          boardData['memberRoles'] ?? const <String, dynamic>{},
        );
        memberRoles.forEach((memberId, rawRole) {
          if (rawRole?.toString() == 'supervisor' && memberId != applicantId) {
            reviewerIds.add(memberId);
          }
        });
      }
    }

    final title = 'Task Application';
    final message = '$applicantName applied for "${task.taskTitle}".';
    for (final reviewerId in reviewerIds) {
      await NotificationHelper.createInAppOnly(
        userId: reviewerId,
        title: title,
        message: message,
        category: NotificationHelper.categoryApproval,
        relatedId: task.taskId,
        metadata: {
          'kind': 'task_application',
          'taskId': task.taskId,
          'taskTitle': task.taskTitle,
          'applicantId': applicantId,
          'applicantName': applicantName,
          if (task.taskBoardId.isNotEmpty) 'boardId': task.taskBoardId,
        },
      );
    }
  }
}
