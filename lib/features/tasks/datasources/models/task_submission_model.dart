import 'package:cloud_firestore/cloud_firestore.dart';

class TaskSubmission {
  final String submissionId;
  final String taskId;
  final String submittedBy;
  final String submittedByName;
  final String? submittedByProfilePicture;
  final DateTime submittedAt;
  final String? message;
  final List<SubmissionFile> files;
  final String
  status; // 'submitted', 'approved', 'rejected', 'revision_requested'
  final String? feedback; // Manager's feedback
  final DateTime? reviewedAt;
  final String? reviewedBy;

  TaskSubmission({
    required this.submissionId,
    required this.taskId,
    required this.submittedBy,
    required this.submittedByName,
    this.submittedByProfilePicture,
    required this.submittedAt,
    this.message,
    required this.files,
    required this.status,
    this.feedback,
    this.reviewedAt,
    this.reviewedBy,
  });

  factory TaskSubmission.fromMap(Map<String, dynamic> data, String documentId) {
    return TaskSubmission(
      submissionId: documentId,
      taskId: data['taskId'] ?? '',
      submittedBy: data['submittedBy'] ?? '',
      submittedByName: data['submittedByName'] ?? 'Unknown',
      submittedByProfilePicture: data['submittedByProfilePicture'] as String?,
      submittedAt:
          (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      message: data['message'] as String?,
      files:
          (data['files'] as List<dynamic>?)
              ?.map((f) => SubmissionFile.fromMap(f as Map<String, dynamic>))
              .toList() ??
          [],
      status: data['status'] ?? 'submitted',
      feedback: data['feedback'] as String?,
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'submittedBy': submittedBy,
      'submittedByName': submittedByName,
      if (submittedByProfilePicture != null)
        'submittedByProfilePicture': submittedByProfilePicture,
      'submittedAt': Timestamp.fromDate(submittedAt),
      if (message != null) 'message': message,
      'files': files.map((f) => f.toMap()).toList(),
      'status': status,
      if (feedback != null) 'feedback': feedback,
      if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
      if (reviewedBy != null) 'reviewedBy': reviewedBy,
    };
  }
}

class SubmissionFile {
  final String fileName;
  final String fileUrl;
  final String fileType; // e.g., 'pdf', 'docx', 'image', etc.
  final int fileSize; // in bytes
  final String storagePath; // Firebase Storage path

  SubmissionFile({
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    required this.storagePath,
  });

  factory SubmissionFile.fromMap(Map<String, dynamic> data) {
    return SubmissionFile(
      fileName: data['fileName'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      fileType: data['fileType'] ?? '',
      fileSize: data['fileSize'] ?? 0,
      storagePath: data['storagePath'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileSize': fileSize,
      'storagePath': storagePath,
    };
  }
}
