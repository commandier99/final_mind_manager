import 'package:flutter/material.dart';

import '../../../tasks/datasources/models/task_model.dart';
import '../../../tasks/datasources/services/task_upload_service.dart';
import '../../../tasks/presentation/pages/task_details_page.dart';

class SessionTaskSubmissionHelper {
  SessionTaskSubmissionHelper._();

  static final TaskUploadService _taskUploadService = TaskUploadService();

  static Future<void> openSubmissionFlow(
    BuildContext context,
    Task task,
  ) async {
    final uploads = await _taskUploadService.streamTaskUploads(task.taskId).first;
    if (!context.mounted) return;

    if (uploads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Upload a file first in Task Details > Uploads so you can select it for submission.',
          ),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsPage(
          task: task,
          initialTab: TaskDetailsPage.tabUploads,
        ),
      ),
    );
  }
}
