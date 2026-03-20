import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../../../shared/utilities/cloudinary_service.dart';
import '../models/task_upload_model.dart';

typedef TaskUploadProgressCallback =
    void Function(
      String uploadId,
      String fileName,
      int currentFile,
      int totalFiles,
      double progress,
    );

class TaskUploadService {
  TaskUploadService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _uploads =>
      _firestore.collection('task_uploads');

  Stream<List<TaskUpload>> streamTaskUploads(String taskId) {
    return _uploads
        .where('taskId', isEqualTo: taskId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                try {
                  return TaskUpload.fromMap(doc.data(), doc.id);
                } catch (e) {
                  debugPrint(
                    '[TaskUploadService] Failed to parse upload ${doc.id}: $e',
                  );
                  return null;
                }
              })
              .whereType<TaskUpload>()
              .toList();
        });
  }

  Future<List<TaskUpload>> uploadFiles({
    required String taskId,
    required String boardId,
    required String uploadedByUserId,
    required String uploadedByUserName,
    required List<PlatformFile> files,
    TaskUploadProgressCallback? onProgress,
  }) async {
    final createdUploads = <TaskUpload>[];
    final totalFiles = files.length;

    for (var index = 0; index < files.length; index++) {
      final file = files[index];
      final uploadRef = _uploads.doc();
      onProgress?.call(uploadRef.id, file.name, index + 1, totalFiles, 0.0);

      final uploadResult = await CloudinaryService().uploadSubmissionFile(
        file: file,
        taskId: taskId,
        submissionId: uploadRef.id,
      );

      final upload = TaskUpload(
        uploadId: uploadRef.id,
        taskId: taskId,
        boardId: boardId,
        uploadedByUserId: uploadedByUserId,
        uploadedByUserName: uploadedByUserName,
        fileName: file.name,
        fileUrl: uploadResult['url'] ?? '',
        filePublicId: uploadResult['publicId'] ?? '',
        fileExtension: file.extension,
        fileSizeBytes: file.size,
        uploadedAt: DateTime.now(),
      );

      await uploadRef.set(upload.toMap());
      createdUploads.add(upload);
      onProgress?.call(uploadRef.id, file.name, index + 1, totalFiles, 1.0);
    }

    return createdUploads;
  }

  Future<void> softDeleteUpload(String uploadId) async {
    await _uploads.doc(uploadId).update({
      'isDeleted': true,
      'deletedAt': Timestamp.now(),
    });
  }
}
