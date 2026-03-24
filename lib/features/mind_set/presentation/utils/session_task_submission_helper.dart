import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../boards/datasources/providers/board_provider.dart';
import '../../../notifications/datasources/models/notification_model.dart';
import '../../../notifications/datasources/providers/notification_provider.dart';
import '../../../tasks/datasources/models/task_model.dart';
import '../../../tasks/datasources/models/task_upload_model.dart';
import '../../../tasks/datasources/services/task_upload_service.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../../thoughts/datasources/models/thought_model.dart';
import '../../../thoughts/datasources/providers/thought_provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';

class SessionTaskSubmissionHelper {
  SessionTaskSubmissionHelper._();

  static final TaskUploadService _taskUploadService = TaskUploadService();
  static final Uuid _uuid = const Uuid();

  static bool canMarkTaskDone(BuildContext context, Task task) {
    if (task.isWorkDisabled) return false;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return false;
    if (task.taskOwnerId == currentUserId) return true;
    if (task.taskBoardId.trim().isEmpty) return false;

    final board = context.read<BoardProvider>().getBoardById(task.taskBoardId);
    if (board == null) return false;
    return board.isManager(currentUserId) || board.isSupervisor(currentUserId);
  }

  static bool shouldUseThoughtSubmit(BuildContext context, Task task) {
    if (task.isWorkDisabled) return false;
    if (task.taskRequiresSubmission) return true;
    return task.taskAllowsSubmissions && !canMarkTaskDone(context, task);
  }

  static bool isSessionTaskComplete(Task task) {
    return task.taskIsDone || task.taskStatus == Task.statusSubmitted;
  }

  static Future<bool> openSubmissionFlow(
    BuildContext context,
    Task task,
  ) async {
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) return false;

    final board = context.read<BoardProvider>().getBoardById(task.taskBoardId);
    final managerUserId = board?.boardManagerId ?? task.taskOwnerId;
    final managerUserName = board?.boardManagerName ?? task.taskOwnerName;
    if (managerUserId.trim().isEmpty || managerUserId == currentUser.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid reviewer was found for this submission.'),
        ),
      );
      return false;
    }

    final existingUploads = await _taskUploadService.streamTaskUploads(task.taskId).first;
    if (!context.mounted) return false;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _SessionSubmissionDialog(
        task: task,
        managerUserId: managerUserId,
        managerUserName: managerUserName,
        initialUploads: existingUploads,
      ),
    );

    if (!context.mounted || submitted != true) return false;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Submission thought created for review.')),
    );
    return true;
  }
}

class _SessionSubmissionDialog extends StatefulWidget {
  const _SessionSubmissionDialog({
    required this.task,
    required this.managerUserId,
    required this.managerUserName,
    required this.initialUploads,
  });

  final Task task;
  final String managerUserId;
  final String managerUserName;
  final List<TaskUpload> initialUploads;

  @override
  State<_SessionSubmissionDialog> createState() =>
      _SessionSubmissionDialogState();
}

class _SessionSubmissionDialogState extends State<_SessionSubmissionDialog> {
  late List<TaskUpload> _uploads;
  final Set<String> _selectedUploadIds = <String>{};
  final TextEditingController _noteController = TextEditingController();
  bool _isUploading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _uploads = List<TaskUpload>.from(widget.initialUploads);
    _selectedUploadIds.addAll(_uploads.map((upload) => upload.uploadId));
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Submit Thought'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload files here if needed, then choose which ones to send for review.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _isUploading || _isSubmitting ? null : _handleUploadFiles,
                  icon: Icon(
                    _isUploading ? Icons.hourglass_top : Icons.upload_file,
                  ),
                  label: Text(_isUploading ? 'Uploading...' : 'Upload Files'),
                ),
              ),
              const SizedBox(height: 12),
              if (_uploads.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    'No uploads yet. Add one or more files, then submit them for review.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._uploads.map((upload) {
                  return CheckboxListTile(
                    value: _selectedUploadIds.contains(upload.uploadId),
                    contentPadding: EdgeInsets.zero,
                    title: Text(upload.fileName, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      '${upload.uploadedByUserName} • ${_formatDate(upload.uploadedAt)}',
                    ),
                    onChanged: _isSubmitting
                        ? null
                        : (selected) {
                            setState(() {
                              if (selected ?? false) {
                                _selectedUploadIds.add(upload.uploadId);
                              } else {
                                _selectedUploadIds.remove(upload.uploadId);
                              }
                            });
                          },
                  );
                }),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                enabled: !_isSubmitting,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Submission Note',
                  border: OutlineInputBorder(),
                  hintText: 'Add context for the reviewer.',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading || _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isUploading || _isSubmitting || _selectedUploadIds.isEmpty
              ? null
              : _submitThought,
          child: Text(_isSubmitting ? 'Submitting...' : 'Submit'),
        ),
      ],
    );
  }

  Future<void> _handleUploadFiles() async {
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) return;

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (!mounted || picked == null || picked.files.isEmpty) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final createdUploads = await SessionTaskSubmissionHelper._taskUploadService
          .uploadFiles(
            taskId: widget.task.taskId,
            boardId: widget.task.taskBoardId,
            uploadedByUserId: currentUser.userId,
            uploadedByUserName: currentUser.userName,
            files: picked.files,
          );

      if (!mounted) return;
      setState(() {
        _uploads = [...createdUploads, ..._uploads];
        _selectedUploadIds.addAll(createdUploads.map((upload) => upload.uploadId));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload files: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _submitThought() async {
    final currentUser = context.read<UserProvider>().currentUser;
    final thoughtProvider = context.read<ThoughtProvider>();
    final notificationProvider = context.read<NotificationProvider>();
    final taskProvider = context.read<TaskProvider>();
    final boardTitle = (context
                .read<BoardProvider>()
                .getBoardById(widget.task.taskBoardId)
                ?.boardTitle ??
            '')
        .trim();
    if (currentUser == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final submissionRound =
          await thoughtProvider.countSubmissionThoughtsForTask(widget.task.taskId) + 1;
      final selectedUploads = _uploads
          .where((upload) => _selectedUploadIds.contains(upload.uploadId))
          .toList();
      final notificationSeed = SessionTaskSubmissionHelper._uuid.v4();
      final now = DateTime.now();
      final submissionNote = _noteController.text.trim();

      final thought = Thought(
        thoughtId: '',
        type: Thought.typeSubmissionFeedback,
        status: Thought.statusOpen,
        scopeType: Thought.scopeTask,
        boardId: widget.task.taskBoardId,
        taskId: widget.task.taskId,
        authorId: currentUser.userId,
        authorName: currentUser.userName,
        targetUserId: widget.managerUserId,
        targetUserName: widget.managerUserName,
        title:
            'Submission ${submissionRound.toString().padLeft(2, '0')}: ${widget.task.taskTitle}',
        message: submissionNote.isEmpty
            ? '${currentUser.userName} submitted ${selectedUploads.length} upload(s) for review.'
            : submissionNote,
        createdAt: now,
        updatedAt: now,
        metadata: {
          'submissionState': 'submitted',
          'submissionRound': submissionRound,
          'selectedUploadIds':
              selectedUploads.map((upload) => upload.uploadId).toList(),
          'selectedUploads': selectedUploads
              .map(
                (upload) => {
                  'uploadId': upload.uploadId,
                  'fileName': upload.fileName,
                  'fileUrl': upload.fileUrl,
                  'filePublicId': upload.filePublicId,
                  'fileExtension': upload.fileExtension,
                  'fileSizeBytes': upload.fileSizeBytes,
                },
              )
              .toList(),
          'taskTitle': widget.task.taskTitle,
          'boardTitle': boardTitle,
          'managerUserId': widget.managerUserId,
          'managerUserName': widget.managerUserName,
          'submittedByUserId': currentUser.userId,
          'submittedByUserName': currentUser.userName,
          'submittedAt': now.toIso8601String(),
          'notificationSeed': notificationSeed,
          'feedbackMessage': '',
          'verdict': 'pending',
        },
      );

      final thoughtId = await thoughtProvider.createThought(thought);

      await taskProvider.updateTask(
        widget.task.copyWith(
          taskStatus: Task.statusSubmitted,
          taskApprovalStatus: 'pending',
          taskLatestSubmissionThoughtId: thoughtId,
        ),
      );

      try {
        await notificationProvider.createNotifications([
          AppNotification(
            notificationId: '',
            recipientUserId: widget.managerUserId,
            title: 'Task Submission Received',
            message:
                '${currentUser.userName} submitted files for ${widget.task.taskTitle}.',
            type: 'thought_submission_received',
            deliveryStatus: AppNotification.deliveryPending,
            isRead: false,
            isDeleted: false,
            createdAt: now,
            updatedAt: now,
            actorUserId: currentUser.userId,
            actorUserName: currentUser.userName,
            boardId: widget.task.taskBoardId,
            taskId: widget.task.taskId,
            thoughtId: thoughtId,
            eventKey:
                '$notificationSeed:${widget.managerUserId}:thought_submission_received',
            metadata: {
              'thoughtType': Thought.typeSubmissionFeedback,
              'submissionRound': submissionRound,
            },
          ),
        ]);
      } catch (_) {}

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit thought: $e')),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$month/$day/$year';
  }
}
