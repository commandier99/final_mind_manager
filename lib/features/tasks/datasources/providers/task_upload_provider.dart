import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/task_upload_model.dart';
import '../services/task_upload_service.dart';

class TaskUploadProvider extends ChangeNotifier {
  TaskUploadProvider({TaskUploadService? service})
    : _service = service ?? TaskUploadService();

  final TaskUploadService _service;

  List<TaskUpload> _uploads = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription<List<TaskUpload>>? _subscription;
  String? _currentTaskId;

  List<TaskUpload> get uploads => _uploads;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void streamTaskUploads(String taskId) {
    if (_currentTaskId == taskId) return;

    _subscription?.cancel();
    _currentTaskId = taskId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    _subscription = _service.streamTaskUploads(taskId).listen(
      (uploads) {
        _uploads = uploads;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _uploads = [];
        _isLoading = false;
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  Future<List<TaskUpload>> uploadFiles({
    required String taskId,
    required String boardId,
    required String uploadedByUserId,
    required String uploadedByUserName,
    required List<PlatformFile> files,
    TaskUploadProgressCallback? onProgress,
  }) async {
    try {
      _error = null;
      return await _service.uploadFiles(
        taskId: taskId,
        boardId: boardId,
        uploadedByUserId: uploadedByUserId,
        uploadedByUserName: uploadedByUserName,
        files: files,
        onProgress: onProgress,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> softDeleteUpload(String uploadId) async {
    try {
      _error = null;
      await _service.softDeleteUpload(uploadId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
