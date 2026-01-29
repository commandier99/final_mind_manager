import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../models/task_submission_model.dart';
import '../../../../shared/utilities/cloudinary_service.dart';
import '../../../../shared/features/users/datasources/services/activity_event_services.dart';

class TaskSubmissionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CloudinaryService _cloudinary = CloudinaryService();
  final ActivityEventService _activityEventService = ActivityEventService();

  CollectionReference get _submissions =>
      _firestore.collection('task_submissions');

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
      print('📤 [Upload] Starting submission for task: $taskId');
      print('📤 [Upload] Number of files: ${files.length}');

      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get user data
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data();

      final submissionId = _submissions.doc().id;
      final uploadedFiles = <SubmissionFile>[];

      print('📤 [Upload] Submission ID: $submissionId');

      // Upload each file to Cloudinary
      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        print(
          '📤 [Upload] Processing file ${i + 1}/${files.length}: ${file.name}',
        );
        print('📤 [Upload] File size: ${file.size} bytes');
        print('📤 [Upload] Has bytes: ${file.bytes != null}');

        if (file.bytes != null) {
          print('📤 [Upload] Uploading to Cloudinary...');
          
          // Report progress
          onProgress?.call(submissionId, i + 1, files.length, file.name, 0.0);

          // Upload to Cloudinary
          final uploadResult = await _cloudinary.uploadSubmissionFile(
            file: file,
            taskId: taskId,
            submissionId: submissionId,
          );

          print('📤 [Upload] Upload successful!');
          print('📤 [Upload] URL: ${uploadResult['url']}');
          print('📤 [Upload] Public ID: ${uploadResult['publicId']}');
          
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

          print(
            '📤 [Upload] File added to list. Total files: ${uploadedFiles.length}',
          );
        } else {
          print('⚠️ [Upload] File has no bytes, skipping');
        }
      }

      print(
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
        status: 'submitted',
      );

      print('📤 [Upload] Saving submission to Firestore...');
      print('📤 [Upload] Submission has ${submission.files.length} files');

      await _submissions.doc(submissionId).set(submission.toMap());

      print('📤 [Upload] Submission saved to Firestore');

      // Update task with submission ID and status
      await _firestore.collection('tasks').doc(taskId).update({
        'taskSubmissionId': submissionId,
        'taskStatus': 'IN_REVIEW',
      });

      // Log activity if task is part of a board
      try {
        final taskDoc = await _firestore.collection('tasks').doc(taskId).get();
        final taskData = taskDoc.data();
        final boardId = taskData?['taskBoardId'];
        
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
        print('⚠️ Failed to log activity: $e');
      }

      print(
        '✅ Submission created: $submissionId with ${uploadedFiles.length} files',
      );
      return submissionId;
    } catch (e) {
      print('⚠️ Error creating submission: $e');
      rethrow;
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
      print('⚠️ Error getting submission: $e');
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

  /// Get submissions by user
  Future<List<TaskSubmission>> getSubmissionsByUser(String userId) async {
    try {
      final snapshot =
          await _submissions
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
      print('⚠️ Error getting user submissions: $e');
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
      print('⚠️ Error calculating total task bytes: $e');
      return 0;
    }
  }

  // ========================
  // DELETE SUBMISSION
  // ========================

  /// Deletes a submission document and updates the related task.
  /// Note: Cloudinary deletion is not supported by cloudinary_public; files remain in storage.
  Future<void> deleteSubmission(String submissionId) async {
    try {
      // Get submission to obtain taskId and details for logging
      final doc = await _submissions.doc(submissionId).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final String taskId = data['taskId'] as String? ?? '';
      final String submittedBy = data['submittedBy'] as String? ?? '';
      final String submittedByName = data['submittedByName'] as String? ?? 'Unknown';
      final List<dynamic> files = (data['files'] as List<dynamic>?) ?? [];

      // Delete submission document
      await _submissions.doc(submissionId).delete();

      // Update task: clear submissionId and reset status if needed
      final taskRef = _firestore.collection('tasks').doc(taskId);
      final taskDoc = await taskRef.get();
      if (taskDoc.exists) {
        final taskData = taskDoc.data() as Map<String, dynamic>;
        final currentSubmissionId = taskData['taskSubmissionId'] as String?;
        final currentStatus = taskData['taskStatus'] as String?;
        final updates = <String, dynamic>{};

        if (currentSubmissionId == submissionId) {
          updates['taskSubmissionId'] = null;
        }
        if (currentStatus == 'IN_REVIEW') {
          updates['taskStatus'] = 'IN_PROGRESS';
        }
        if (updates.isNotEmpty) {
          await taskRef.update(updates);
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
          metadata: {
            'submissionId': submissionId,
            'fileCount': files.length,
          },
        );
      } catch (e) {
        print('⚠️ Failed to log deletion activity: $e');
      }
    } catch (e) {
      print('⚠️ Error deleting submission: $e');
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

      await _submissions.doc(submissionId).update({
        'status': status,
        if (feedback != null) 'feedback': feedback,
        'reviewedAt': Timestamp.fromDate(DateTime.now()),
        'reviewedBy': currentUser.uid,
      });

      // Update task status based on review
      final submission = await getSubmissionById(submissionId);
      if (submission != null) {
        String taskStatus;
        switch (status) {
          case 'approved':
            taskStatus = 'DONE';
            break;
          case 'rejected':
            taskStatus = 'TODO';
            break;
          case 'revision_requested':
            taskStatus = 'IN_PROGRESS';
            break;
          default:
            taskStatus = 'IN_REVIEW';
        }

        await _firestore.collection('tasks').doc(submission.taskId).update({
          'taskStatus': taskStatus,
        });
      }

      print('✅ Submission reviewed: $submissionId');
    } catch (e) {
      print('⚠️ Error reviewing submission: $e');
      rethrow;
    }
  }


}
