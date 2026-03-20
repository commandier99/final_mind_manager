import 'package:cloud_firestore/cloud_firestore.dart';

class TaskUpload {
  final String uploadId;
  final String taskId;
  final String boardId;
  final String uploadedByUserId;
  final String uploadedByUserName;
  final String fileName;
  final String fileUrl;
  final String filePublicId;
  final String? fileExtension;
  final int fileSizeBytes;
  final bool isDeleted;
  final DateTime uploadedAt;
  final DateTime? deletedAt;

  const TaskUpload({
    required this.uploadId,
    required this.taskId,
    required this.boardId,
    required this.uploadedByUserId,
    required this.uploadedByUserName,
    required this.fileName,
    required this.fileUrl,
    required this.filePublicId,
    this.fileExtension,
    this.fileSizeBytes = 0,
    this.isDeleted = false,
    required this.uploadedAt,
    this.deletedAt,
  });

  factory TaskUpload.fromMap(Map<String, dynamic> data, String documentId) {
    return TaskUpload(
      uploadId: documentId,
      taskId: data['taskId'] as String? ?? '',
      boardId: data['boardId'] as String? ?? '',
      uploadedByUserId: data['uploadedByUserId'] as String? ?? '',
      uploadedByUserName: data['uploadedByUserName'] as String? ?? 'Unknown',
      fileName: data['fileName'] as String? ?? 'Unnamed file',
      fileUrl: data['fileUrl'] as String? ?? '',
      filePublicId: data['filePublicId'] as String? ?? '',
      fileExtension: data['fileExtension'] as String?,
      fileSizeBytes: data['fileSizeBytes'] as int? ?? 0,
      isDeleted: data['isDeleted'] as bool? ?? false,
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uploadId': uploadId,
      'taskId': taskId,
      'boardId': boardId,
      'uploadedByUserId': uploadedByUserId,
      'uploadedByUserName': uploadedByUserName,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'filePublicId': filePublicId,
      if (fileExtension != null) 'fileExtension': fileExtension,
      'fileSizeBytes': fileSizeBytes,
      'isDeleted': isDeleted,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      if (deletedAt != null) 'deletedAt': Timestamp.fromDate(deletedAt!),
    };
  }

  TaskUpload copyWith({
    String? uploadId,
    String? taskId,
    String? boardId,
    String? uploadedByUserId,
    String? uploadedByUserName,
    String? fileName,
    String? fileUrl,
    String? filePublicId,
    String? fileExtension,
    int? fileSizeBytes,
    bool? isDeleted,
    DateTime? uploadedAt,
    DateTime? deletedAt,
  }) {
    return TaskUpload(
      uploadId: uploadId ?? this.uploadId,
      taskId: taskId ?? this.taskId,
      boardId: boardId ?? this.boardId,
      uploadedByUserId: uploadedByUserId ?? this.uploadedByUserId,
      uploadedByUserName: uploadedByUserName ?? this.uploadedByUserName,
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      filePublicId: filePublicId ?? this.filePublicId,
      fileExtension: fileExtension ?? this.fileExtension,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      isDeleted: isDeleted ?? this.isDeleted,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
