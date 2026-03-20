import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../boards/datasources/providers/board_provider.dart';
import '../../../../notifications/datasources/models/notification_model.dart';
import '../../../../notifications/datasources/providers/notification_provider.dart';
import '../../../../thoughts/datasources/models/thought_model.dart';
import '../../../../thoughts/datasources/providers/thought_provider.dart';
import '../../../datasources/models/task_model.dart';
import '../../../datasources/models/task_upload_model.dart';
import '../../../datasources/providers/task_provider.dart';
import '../../../datasources/providers/task_upload_provider.dart';
import '../../../datasources/providers/upload_progress_provider.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';

class TaskUploadsSection extends StatefulWidget {
  const TaskUploadsSection({
    super.key,
    required this.task,
    required this.canManageTask,
  });

  final Task task;
  final bool canManageTask;

  @override
  State<TaskUploadsSection> createState() => _TaskUploadsSectionState();
}

class _TaskUploadsSectionState extends State<TaskUploadsSection> {
  final Uuid _uuid = const Uuid();
  bool _isUploading = false;
  bool _isSubmittingThought = false;
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskUploadProvider>().streamTaskUploads(widget.task.taskId);
    });
  }

  @override
  void didUpdateWidget(covariant TaskUploadsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.taskId != widget.task.taskId) {
      context.read<TaskUploadProvider>().streamTaskUploads(widget.task.taskId);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().currentUser;
    final board = context.watch<BoardProvider>().getBoardById(widget.task.taskBoardId);
    final currentUserId = currentUser?.userId ?? '';
    final isAssignee = currentUserId.isNotEmpty &&
        currentUserId == widget.task.taskAssignedTo;
    final isFocusedTask = _isFocusedTask(widget.task);
    final canUpload = currentUser != null &&
        isFocusedTask &&
        (isAssignee || widget.canManageTask || currentUserId == widget.task.taskOwnerId);
    final canSubmitThought = currentUser != null && isFocusedTask && isAssignee;
    final managerUserId = board?.boardManagerId ?? widget.task.taskOwnerId;
    final managerUserName = board?.boardManagerName ?? widget.task.taskOwnerName;

    return Consumer2<TaskUploadProvider, UploadProgressProvider>(
      builder: (context, uploadProvider, progressProvider, _) {
        final uploads = uploadProvider.uploads;
        final hasUploads = uploads.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isFocusedTask) ...[
                _buildInfoBanner(
                  icon: Icons.info_outline,
                  message:
                      'Focus this task first to enable Upload Files and Submit Thought. You can also explore Mind:Set sessions to work on this task in a more guided way.',
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  const Spacer(),
                  if (canUpload)
                    FilledButton.icon(
                      onPressed: _isUploading ? null : _handleUploadFiles,
                      icon: Icon(_isUploading ? Icons.hourglass_top : Icons.upload_file),
                      label: Text(_isUploading ? 'Uploading...' : 'Upload Files'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _buildInfoBanner(
                icon: Icons.upload_file_outlined,
                message:
                    'Upload task files first, then choose which uploads to submit for manager review.',
              ),
              const SizedBox(height: 12),
              if (progressProvider.uploads.isNotEmpty) ...[
                ...progressProvider.uploads.values.map(_buildProgressCard),
                const SizedBox(height: 12),
              ],
              if (!hasUploads)
                _buildEmptyState(canUpload: canUpload)
              else ...[
                ...uploads.map(_buildUploadCard),
                if (canSubmitThought) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: _isSubmittingThought ||
                              !hasUploads ||
                              managerUserId.trim().isEmpty ||
                              managerUserId == currentUserId
                          ? null
                          : () => _showSubmitThoughtDialog(
                                uploads: uploads,
                                managerUserId: managerUserId,
                                managerUserName: managerUserName,
                              ),
                      icon: const Icon(Icons.rate_review_outlined),
                      label: Text(
                        _isSubmittingThought ? 'Submitting...' : 'Submit Thought',
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required bool canUpload}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.folder_open_outlined, size: 42, color: Colors.grey.shade500),
          const SizedBox(height: 8),
          const Text(
            'No uploads yet.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            canUpload
                ? 'Upload one or more files to prepare a submission for review.'
                : 'Uploads will appear here once the assignee adds files.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner({
    required IconData icon,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(UploadProgress progress) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            progress.displayText,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress.fileProgress),
        ],
      ),
    );
  }

  Widget _buildUploadCard(TaskUpload upload) {
    final extension = (upload.fileExtension ?? '').trim().toUpperCase();
    final sizeLabel = _formatBytes(upload.fileSizeBytes);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_file, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  upload.fileName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaPill(Icons.person_outline, upload.uploadedByUserName),
              _metaPill(
                Icons.schedule_outlined,
                _formatDateTime(upload.uploadedAt),
              ),
              if (extension.isNotEmpty) _metaPill(Icons.description_outlined, extension),
              _metaPill(Icons.data_usage_outlined, sizeLabel),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUploadFiles() async {
    final currentUser = context.read<UserProvider>().currentUser;
    final uploadProvider = context.read<TaskUploadProvider>();
    final progressProvider = context.read<UploadProgressProvider>();
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
      await uploadProvider.uploadFiles(
        taskId: widget.task.taskId,
        boardId: widget.task.taskBoardId,
        uploadedByUserId: currentUser.userId,
        uploadedByUserName: currentUser.userName,
        files: picked.files,
        onProgress: (uploadId, fileName, currentFile, totalFiles, progress) {
          progressProvider.updateProgress(
            submissionId: uploadId,
            fileName: fileName,
            currentFile: currentFile,
            totalFiles: totalFiles,
            progress: progress,
          );
          if (progress >= 1.0) {
            progressProvider.clearProgress(uploadId);
          }
        },
      );
      if (!mounted) return;
      _showSnackBar('${picked.files.length} file(s) uploaded.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to upload files: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _showSubmitThoughtDialog({
    required List<TaskUpload> uploads,
    required String managerUserId,
    required String managerUserName,
  }) async {
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

    final selectedUploadIds = <String>{};
    final noteController = TextEditingController();

    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Submit Thought'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose which uploaded files should be reviewed for this task.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 12),
                      ...uploads.map((upload) {
                        return CheckboxListTile(
                          value: selectedUploadIds.contains(upload.uploadId),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            upload.fileName,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            '${upload.uploadedByUserName} • ${_formatDateTime(upload.uploadedAt)}',
                          ),
                          onChanged: (selected) {
                            setDialogState(() {
                              if (selected ?? false) {
                                selectedUploadIds.add(upload.uploadId);
                              } else {
                                selectedUploadIds.remove(upload.uploadId);
                              }
                            });
                          },
                        );
                      }),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Submission Note',
                          border: OutlineInputBorder(),
                          hintText: 'Add context for the manager reviewing this submission.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: selectedUploadIds.isEmpty
                      ? null
                      : () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    final submissionNote = noteController.text.trim();
    noteController.dispose();
    if (!mounted || shouldSubmit != true) return;

    setState(() {
      _isSubmittingThought = true;
    });

    try {
      final submissionRound =
          await thoughtProvider.countSubmissionThoughtsForTask(widget.task.taskId) + 1;
      final selectedUploads = uploads
          .where((upload) => selectedUploadIds.contains(upload.uploadId))
          .toList();
      final notificationSeed = _uuid.v4();
      final now = DateTime.now();

      final thought = Thought(
        thoughtId: '',
        type: Thought.typeSubmissionFeedback,
        status: Thought.statusOpen,
        scopeType: Thought.scopeTask,
        boardId: widget.task.taskBoardId,
        taskId: widget.task.taskId,
        authorId: currentUser.userId,
        authorName: currentUser.userName,
        targetUserId: managerUserId,
        targetUserName: managerUserName,
        title: 'Submission ${submissionRound.toString().padLeft(2, '0')}: ${widget.task.taskTitle}',
        message: submissionNote.isEmpty
            ? '${currentUser.userName} submitted ${selectedUploads.length} upload(s) for review.'
            : submissionNote,
        createdAt: now,
        updatedAt: now,
        metadata: {
          'submissionState': 'submitted',
          'submissionRound': submissionRound,
          'selectedUploadIds': selectedUploads.map((upload) => upload.uploadId).toList(),
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
          'managerUserId': managerUserId,
          'managerUserName': managerUserName,
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
            recipientUserId: managerUserId,
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
            eventKey: '$notificationSeed:$managerUserId:thought_submission_received',
            metadata: {
              'thoughtType': Thought.typeSubmissionFeedback,
              'submissionRound': submissionRound,
            },
          ),
        ]);
      } catch (_) {}

      if (!mounted) return;
      _showSnackBar('Submission thought created for review.');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Failed to submit thought: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingThought = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$month/$day/$year';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool _isFocusedTask(Task task) {
    final normalized = task.taskStatus.toUpperCase().replaceAll(' ', '_');
    return normalized == 'IN_PROGRESS' || normalized == 'FOCUSED';
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    final messenger = _scaffoldMessenger;
    if (messenger == null || !messenger.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
