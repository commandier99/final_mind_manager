import 'package:flutter/material.dart';

class UploadProgress {
  final String submissionId;
  final String fileName;
  final int currentFile;
  final int totalFiles;
  final double progress; // 0.0 to 1.0

  UploadProgress({
    required this.submissionId,
    required this.fileName,
    required this.currentFile,
    required this.totalFiles,
    required this.progress,
  });

  double get fileProgress => (currentFile - 1 + progress) / totalFiles;

  String get displayText => 'Uploading: $fileName ($currentFile/$totalFiles)';

  @override
  String toString() => 'UploadProgress($displayText, ${(fileProgress * 100).toStringAsFixed(1)}%)';
}

class UploadProgressProvider extends ChangeNotifier {
  final Map<String, UploadProgress> _uploads = {};

  Map<String, UploadProgress> get uploads => _uploads;
  bool get isUploading => _uploads.isNotEmpty;

  void updateProgress({
    required String submissionId,
    required String fileName,
    required int currentFile,
    required int totalFiles,
    required double progress,
  }) {
    _uploads[submissionId] = UploadProgress(
      submissionId: submissionId,
      fileName: fileName,
      currentFile: currentFile,
      totalFiles: totalFiles,
      progress: progress,
    );
    notifyListeners();
    print('📊 [UploadProgress] ${_uploads[submissionId]!}');
  }

  void clearProgress(String submissionId) {
    _uploads.remove(submissionId);
    notifyListeners();
    print('📊 [UploadProgress] Cleared submission: $submissionId');
  }
}
