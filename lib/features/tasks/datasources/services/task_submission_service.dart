import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../models/task_submission_model.dart';
import '../models/task_model.dart';
import '../models/task_stats_model.dart';
import '../../../boards/datasources/models/board_roles.dart';
import '../../../notifications/datasources/helpers/notification_helper.dart';
import '../../../../shared/utilities/cloudinary_service.dart';
import '../../../../shared/features/users/datasources/services/activity_event_services.dart';

class TaskSubmissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CloudinaryService _cloudinary = CloudinaryService();
  final ActivityEventService _activityEventService = ActivityEventService();

  CollectionReference get _submissions =>
      _firestore.collection('task_submissions');

  Future<void> _assertTaskOpenForMutation(String taskId) async {
    final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
    if (!taskDoc.exists) {
      throw Exception('Task not found');
    }
    final taskData = taskDoc.data() as Map<String, dynamic>;
    final isDone = taskData['taskIsDone'] as bool? ?? false;
    if (isDone) {
      throw Exception('This task is completed and locked.');
    }
  }

  // ========================
  // CREATE SUBMISSION
  // ========================

  /// Upload files and create submission
  /// onProgress callback: (submissionId, currentFile, totalFiles, fileName, progress)
  Future<String> createSubmission({
    required String taskId,
    required List<PlatformFile> files,
    String? message,
    Function(String, int, int, String, double)? onProgress,
  }) async {
    try {
      debugPrint('📤 [Upload] Starting submission for task: $taskId');
      debugPrint('📤 [Upload] Number of files: ${files.length}');

      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');
      await _assertTaskOpenForMutation(taskId);

      // Get user data
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userData = userDoc.data();

      final submissionId = _submissions.doc().id;
      final uploadedFiles = <SubmissionFile>[];

      debugPrint('📤 [Upload] Submission ID: $submissionId');

      // Upload each file to Cloudinary
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        debugPrint(
          '📤 [Upload] Processing file ${i + 1}/${files.length}: ${file.name}',
        );
        debugPrint('📤 [Upload] File size: ${file.size} bytes');
        debugPrint('📤 [Upload] Has bytes: ${file.bytes != null}');

        if (file.bytes != null) {
          debugPrint('📤 [Upload] Uploading to Cloudinary...');

          // Report progress
          onProgress?.call(submissionId, i + 1, files.length, file.name, 0.0);

          // Upload to Cloudinary
          final uploadResult = await _cloudinary.uploadSubmissionFile(
            file: file,
            taskId: taskId,
            submissionId: submissionId,
          );

          debugPrint('📤 [Upload] Upload successful!');
          debugPrint('📤 [Upload] URL: ${uploadResult['url']}');
          debugPrint('📤 [Upload] Public ID: ${uploadResult['publicId']}');

          // Report progress complete for this file
          onProgress?.call(submissionId, i + 1, files.length, file.name, 1.0);

          // Get file extension
          final fileType = file.extension ?? 'unknown';

          uploadedFiles.add(
            SubmissionFile(
              fileName: file.name,
              fileUrl: uploadResult['url']!,
              fileType: fileType,
              fileSize: file.size,
              storagePath:
                  uploadResult['publicId']!, // Store Cloudinary public ID
            ),
          );

          debugPrint(
            '📤 [Upload] File added to list. Total files: ${uploadedFiles.length}',
          );
        } else {
          debugPrint('⚠️ [Upload] File has no bytes, skipping');
        }
      }

      debugPrint(
        '📤 [Upload] All files processed. Total uploaded: ${uploadedFiles.length}',
      );

      // Create submission document
      final submission = TaskSubmission(
        submissionId: submissionId,
        taskId: taskId,
        submittedBy: currentUser.uid,
        submittedByName: userData?['userName'] ?? 'Unknown',
        submittedByProfilePicture: userData?['userProfilePicture'],
        submittedAt: DateTime.now(),
        message: message,
        files: uploadedFiles,
        status: TaskSubmission.statusPending,
      );

      debugPrint('📤 [Upload] Saving submission to Firestore...');
      debugPrint('📤 [Upload] Submission has ${submission.files.length} files');

      await _submissions.doc(submissionId).set(submission.toMap());

      debugPrint('📤 [Upload] Submission saved to Firestore');

      // Load task metadata once for activity logging + reviewer notifications.
      String? boardId;
      Map<String, dynamic>? taskData;
      try {
        final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
        taskData = taskDoc.data();
        boardId = taskData?['taskBoardId'] as String?;
      } catch (_) {
        // Non-critical: keep submission creation successful.
      }

      // Link latest submission to task without mutating execution state.
      final taskRef = _firestore.collection('tasks').doc(taskId);
      await taskRef.update({
        'taskSubmissionId': submissionId,
        'taskStatus': Task.statusSubmitted,
        if ((taskData?['taskRequiresApproval'] as bool? ?? false) == true)
          'taskApprovalStatus': 'pending',
      });

      // Log activity if task is part of a board
      try {
        await _activityEventService.logEvent(
          userId: currentUser.uid,
          userName: userData?['userName'] ?? 'Unknown',
          activityType: 'file_submitted',
          userProfilePicture: userData?['userProfilePicture'],
          taskId: taskId,
          boardId: boardId,
          description: 'Submitted ${uploadedFiles.length} file(s) to task',
          metadata: {
            'fileCount': uploadedFiles.length,
            'submissionId': submissionId,
          },
        );
      } catch (e) {
        debugPrint('⚠️ Failed to log activity: $e');
      }

      // Notify reviewers that a member submitted work.
      try {
        await _notifySubmissionReviewers(
          taskId: taskId,
          submissionId: submissionId,
          taskData: taskData,
          submitterId: currentUser.uid,
          submitterName: userData?['userName'] ?? 'Unknown',
        );
      } catch (e) {
        debugPrint('⚠️ Failed to notify reviewers: $e');
      }

      debugPrint(
        '✅ Submission created: $submissionId with ${uploadedFiles.length} files',
      );
      return submissionId;
    } catch (e) {
      debugPrint('⚠️ Error creating submission: $e');
      rethrow;
    }
  }

  Future<void> _notifySubmissionReviewers({
    required String taskId,
    required String submissionId,
    required Map<String, dynamic>? taskData,
    required String submitterId,
    required String submitterName,
  }) async {
    final effectiveTaskData =
        taskData ??
        (await _firestore.collection('tasks').doc(taskId).get()).data();
    if (effectiveTaskData == null) return;

    final taskTitle = (effectiveTaskData['taskTitle'] as String? ?? 'Task')
        .trim();
    final taskOwnerId = (effectiveTaskData['taskOwnerId'] as String? ?? '')
        .trim();
    final taskBoardId = (effectiveTaskData['taskBoardId'] as String? ?? '')
        .trim();

    final recipientIds = <String>{};
    if (taskOwnerId.isNotEmpty && taskOwnerId != submitterId) {
      recipientIds.add(taskOwnerId);
    }

    if (taskBoardId.isNotEmpty) {
      final boardDoc = await _firestore
          .collection('boards')
          .doc(taskBoardId)
          .get();
      if (boardDoc.exists) {
        final boardData = boardDoc.data() as Map<String, dynamic>;
        final managerId = (boardData['boardManagerId'] as String? ?? '').trim();
        if (managerId.isNotEmpty && managerId != submitterId) {
          recipientIds.add(managerId);
        }
        final memberRoles = Map<String, dynamic>.from(
          boardData['memberRoles'] ?? const <String, dynamic>{},
        );
        memberRoles.forEach((userId, rawRole) {
          final role = BoardRoles.normalize(rawRole?.toString());
          if (role == BoardRoles.supervisor && userId != submitterId) {
            recipientIds.add(userId);
          }
        });
      }
    }

    for (final recipientId in recipientIds) {
      await NotificationHelper.createNotificationPair(
        userId: recipientId,
        title: 'New Submission',
        message: '$submitterName submitted work for "$taskTitle".',
        category: NotificationHelper.categoryApproval,
        relatedId: submissionId,
        metadata: {
          'taskId': taskId,
          'submissionId': submissionId,
          'submitterId': submitterId,
          'submitterName': submitterName,
          if (taskBoardId.isNotEmpty) 'boardId': taskBoardId,
        },
      );
    }
  }

  // ========================
  // READ SUBMISSIONS
  // ========================

  /// Get submission by ID
  Future<TaskSubmission?> getSubmissionById(String submissionId) async {
    try {
      final doc = await _submissions.doc(submissionId).get();
      if (!doc.exists) return null;

      return TaskSubmission.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      debugPrint('⚠️ Error getting submission: $e');
      return null;
    }
  }

  /// Stream submissions for a task
  Stream<List<TaskSubmission>> streamSubmissionsForTask(String taskId) {
    return _submissions
        .where('taskId', isEqualTo: taskId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => TaskSubmission.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
        });
  }

  /// Stream all submissions (for board-level aggregation views)
  Stream<List<TaskSubmission>> streamAllSubmissions() {
    return _submissions
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => TaskSubmission.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
        });
  }

  /// Get submissions by user
  Future<List<TaskSubmission>> getSubmissionsByUser(String userId) async {
    try {
      final snapshot = await _submissions
          .where('submittedBy', isEqualTo: userId)
          .orderBy('submittedAt', descending: true)
          .get();

      return snapshot.docs
          .map(
            (doc) => TaskSubmission.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('⚠️ Error getting user submissions: $e');
      return [];
    }
  }

  /// Get total uploaded bytes for a specific task (sum of all submission files)
  Future<int> getTotalBytesForTask(String taskId) async {
    try {
      final snapshot = await _submissions
          .where('taskId', isEqualTo: taskId)
          .get();

      int total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final files = (data['files'] as List<dynamic>?) ?? [];
        for (final f in files) {
          final fileSize = (f as Map<String, dynamic>)['fileSize'] as int? ?? 0;
          total += fileSize;
        }
      }
      return total;
    } catch (e) {
      debugPrint('⚠️ Error calculating total task bytes: $e');
      return 0;
    }
  }

  // ========================
  // DELETE SUBMISSION
  // ========================

  /// Deletes a submission document and unlinks it from task if it was the latest one.
  /// Note: Cloudinary deletion is not supported by cloudinary_public; files remain in storage.
  Future<void> deleteSubmission(String submissionId) async {
    try {
      // Get submission to obtain taskId and details for logging
      final doc = await _submissions.doc(submissionId).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final String taskId = data['taskId'] as String? ?? '';
      final String submittedBy = data['submittedBy'] as String? ?? '';
      final String submittedByName =
          data['submittedByName'] as String? ?? 'Unknown';
      final List<dynamic> files = (data['files'] as List<dynamic>?) ?? [];

      await _assertTaskOpenForMutation(taskId);

      // Delete submission document
      await _submissions.doc(submissionId).delete();

      // Update task: clear submission link only.
      final taskRef = _firestore.collection('tasks').doc(taskId);
      final taskDoc = await taskRef.get();
      if (taskDoc.exists) {
        final taskData = taskDoc.data() as Map<String, dynamic>;
        final currentSubmissionId = taskData['taskSubmissionId'] as String?;
        if (currentSubmissionId == submissionId) {
          await taskRef.update({'taskSubmissionId': null});
        }
      }

      // Log deletion activity
      try {
        final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
        final boardId = (taskDoc.data())?['taskBoardId'];
        await _activityEventService.logEvent(
          userId: submittedBy,
          userName: submittedByName,
          activityType: 'file_submission_deleted',
          boardId: boardId,
          taskId: taskId,
          description: 'Deleted a submission',
          metadata: {'submissionId': submissionId, 'fileCount': files.length},
        );
      } catch (e) {
        debugPrint('⚠️ Failed to log deletion activity: $e');
      }
    } catch (e) {
      debugPrint('⚠️ Error deleting submission: $e');
      rethrow;
    }
  }

  // ========================
  // UPDATE SUBMISSION
  // ========================

  /// Review submission (approve/reject/request revision)
  Future<void> reviewSubmission({
    required String submissionId,
    required String status, // 'approved', 'rejected', 'revision_requested'
    String? feedback,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final submission = await getSubmissionById(submissionId);
      if (submission == null) throw Exception('Submission not found');

      final taskDoc = await _firestore
          .collection('tasks')
          .doc(submission.taskId)
          .get();
      if (!taskDoc.exists) throw Exception('Task not found');
      final taskData = taskDoc.data() as Map<String, dynamic>;
      if ((taskData['taskIsDone'] as bool? ?? false) == true) {
        throw Exception('This task is completed and locked.');
      }
      final taskOwnerId = taskData['taskOwnerId'] as String? ?? '';
      final taskBoardId = taskData['taskBoardId'] as String? ?? '';

      bool canReview = currentUser.uid == taskOwnerId;
      if (!canReview && taskBoardId.isNotEmpty) {
        final boardDoc = await _firestore
            .collection('boards')
            .doc(taskBoardId)
            .get();
        if (boardDoc.exists) {
          final boardData = boardDoc.data() as Map<String, dynamic>;
          final boardManagerId = boardData['boardManagerId'] as String? ?? '';
          final memberRoles = Map<String, dynamic>.from(
            boardData['memberRoles'] ?? const <String, dynamic>{},
          );
          final reviewerRole = BoardRoles.normalize(
            memberRoles[currentUser.uid]?.toString(),
          );
          canReview =
              currentUser.uid == boardManagerId ||
              reviewerRole == BoardRoles.supervisor;
        }
      }
      if (!canReview) {
        throw Exception(
          'Only task owner, manager, or supervisor can review submissions.',
        );
      }

      String? revisionTaskId;
      final normalizedStatus = TaskSubmission.normalizeStatus(status);
      if (normalizedStatus == TaskSubmission.statusRejected ||
          normalizedStatus == TaskSubmission.statusRevisionRequested) {
        revisionTaskId = await _ensureRevisionTask(
          submission: submission,
          taskData: taskData,
          reviewerId: currentUser.uid,
          feedback: feedback,
        );
      }

      await _submissions.doc(submissionId).update({
        'status': normalizedStatus,
        if (feedback != null) 'feedback': feedback,
        if (revisionTaskId != null) 'revisionTaskId': revisionTaskId,
        'reviewedAt': Timestamp.fromDate(DateTime.now()),
        'reviewedBy': currentUser.uid,
      });

      await _firestore.collection('tasks').doc(submission.taskId).update({
        'taskApprovalStatus': switch (normalizedStatus) {
          TaskSubmission.statusApproved => 'approved',
          TaskSubmission.statusRejected => 'rejected',
          TaskSubmission.statusRevisionRequested => 'changes_requested',
          _ => 'pending',
        },
      });

      try {
        await _notifySubmissionResult(
          submission: submission,
          status: normalizedStatus,
          reviewerId: currentUser.uid,
          taskData: taskData,
          feedback: feedback,
        );
      } catch (e) {
        debugPrint('⚠️ Failed to notify submitter of review result: $e');
      }

      // Intentionally do not mutate task execution fields here.
      // Submission review is separate from taskStatus/taskIsDone/taskOutcome.

      // Log review activity for dashboard analytics.
      try {
        final reviewer = _auth.currentUser;
        if (reviewer != null) {
          final reviewType = switch (normalizedStatus) {
            'approved' => 'submission_approved',
            'rejected' => 'submission_rejected',
            'revision_requested' => 'submission_revision_requested',
            _ => 'submission_reviewed',
          };
          await _activityEventService.logEvent(
            userId: reviewer.uid,
            userName: reviewer.displayName ?? 'Reviewer',
            userProfilePicture: reviewer.photoURL,
            activityType: reviewType,
            boardId: taskBoardId,
            taskId: submission.taskId,
            description: 'Reviewed a task submission: $normalizedStatus',
            metadata: {
              'submissionId': submissionId,
              'status': normalizedStatus,
            },
          );
        }
      } catch (e) {
        debugPrint('Failed to log submission review activity: $e');
      }

      debugPrint('✅ Submission reviewed: $submissionId');
    } catch (e) {
      debugPrint('⚠️ Error reviewing submission: $e');
      rethrow;
    }
  }

  Future<String> _ensureRevisionTask({
    required TaskSubmission submission,
    required Map<String, dynamic> taskData,
    required String reviewerId,
    String? feedback,
  }) async {
    final existing = await _firestore
        .collection('tasks')
        .where('taskRevisionOfSubmissionId', isEqualTo: submission.submissionId)
        .where('taskIsDeleted', isEqualTo: false)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final taskTitle = (taskData['taskTitle'] as String? ?? 'Task').trim();
    final taskDescription = (taskData['taskDescription'] as String? ?? '')
        .trim();
    final boardId = (taskData['taskBoardId'] as String? ?? '').trim();
    final boardTitle = (taskData['taskBoardTitle'] as String?)?.trim();
    final assignedBy = (taskData['taskAssignedBy'] as String?)?.trim();
    final assigneeName = (submission.submittedByName).trim();

    final revisionTitle = 'Revision: $taskTitle';
    final feedbackText = feedback?.trim();
    final revisionDescription = <String>[
      'Follow-up task for submission ${submission.submissionId}.',
      if (feedbackText != null && feedbackText.isNotEmpty)
        'Feedback: $feedbackText',
      if (taskDescription.isNotEmpty) '',
      if (taskDescription.isNotEmpty) 'Original task notes: $taskDescription',
    ].join('\n');

    final revisionTaskRef = _firestore.collection('tasks').doc();
    final revisionTask = Task(
      taskId: revisionTaskRef.id,
      taskBoardId: boardId,
      taskBoardTitle: boardTitle,
      taskOwnerId: reviewerId,
      taskOwnerName: _auth.currentUser?.displayName ?? 'Reviewer',
      taskAssignedBy: assignedBy != null && assignedBy.isNotEmpty
          ? assignedBy
          : reviewerId,
      taskAssignedTo: submission.submittedBy,
      taskAssignedToName: assigneeName.isNotEmpty ? assigneeName : 'Unknown',
      taskCreatedAt: DateTime.now(),
      taskTitle: revisionTitle,
      taskDescription: revisionDescription,
      taskStats: TaskStats(),
      taskStatus: Task.statusToDo,
      taskIsDone: false,
      taskIsDoneAt: null,
      taskFailed: false,
      taskOutcome: Task.outcomeNone,
      taskAllowsSubmissions: true,
      taskRequiresSubmission: true,
      taskRequiresApproval: true,
      taskSubmissionId: null,
      taskBoardLane: Task.lanePublished,
      taskRevisionOfTaskId: submission.taskId,
      taskRevisionOfSubmissionId: submission.submissionId,
    );

    await revisionTaskRef.set(revisionTask.toMap());

    return revisionTaskRef.id;
  }

  Future<void> _notifySubmissionResult({
    required TaskSubmission submission,
    required String status,
    required String reviewerId,
    required Map<String, dynamic> taskData,
    String? feedback,
  }) async {
    if (submission.submittedBy == reviewerId) return;

    final taskTitle = (taskData['taskTitle'] as String? ?? 'Task').trim();
    final boardId = (taskData['taskBoardId'] as String? ?? '').trim();
    final feedbackText = feedback?.trim();

    final resultText = switch (status) {
      TaskSubmission.statusApproved => 'approved',
      TaskSubmission.statusRejected => 'rejected',
      TaskSubmission.statusRevisionRequested => 'sent back for revision',
      _ => 'reviewed',
    };

    await NotificationHelper.createNotificationPair(
      userId: submission.submittedBy,
      title: 'Submission Update',
      message: 'Your submission for "$taskTitle" was $resultText.',
      category: NotificationHelper.categoryApproval,
      relatedId: submission.submissionId,
      metadata: {
        'taskId': submission.taskId,
        'submissionId': submission.submissionId,
        'status': status,
        if (boardId.isNotEmpty) 'boardId': boardId,
        if (feedbackText != null && feedbackText.isNotEmpty)
          'feedback': feedbackText,
      },
    );
  }
}
