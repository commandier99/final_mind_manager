import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../../boards/datasources/providers/board_provider.dart';
import '../../../tasks/datasources/models/task_model.dart';
import '../../../tasks/datasources/services/task_upload_service.dart';
import '../../../tasks/presentation/pages/task_details_page.dart';

class SessionTaskSubmissionHelper {
  SessionTaskSubmissionHelper._();

  static final TaskUploadService _taskUploadService = TaskUploadService();

  static bool canMarkTaskDone(BuildContext context, Task task) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return false;
    if (task.taskOwnerId == currentUserId) return true;
    if (task.taskBoardId.trim().isEmpty) return false;

    final board = context.read<BoardProvider>().getBoardById(task.taskBoardId);
    if (board == null) return false;
    return board.isManager(currentUserId) || board.isSupervisor(currentUserId);
  }

  static bool shouldUseThoughtSubmit(BuildContext context, Task task) {
    if (task.taskRequiresSubmission) return true;
    return task.taskAllowsSubmissions && !canMarkTaskDone(context, task);
  }

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
