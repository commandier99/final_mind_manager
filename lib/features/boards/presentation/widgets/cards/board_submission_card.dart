import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../../notifications/datasources/models/notification_model.dart';
import '../../../../notifications/datasources/providers/notification_provider.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/datasources/services/task_services.dart';
import '../../../../thoughts/datasources/models/thought_model.dart';
import '../../../../thoughts/datasources/providers/thought_provider.dart';
import '../../../../../shared/features/users/datasources/models/user_model.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../datasources/models/board_model.dart';

class BoardSubmissionCard extends StatefulWidget {
  const BoardSubmissionCard({
    super.key,
    required this.thought,
    required this.board,
  });

  final Thought thought;
  final Board board;

  @override
  State<BoardSubmissionCard> createState() => _BoardSubmissionCardState();
}

class _BoardSubmissionCardState extends State<BoardSubmissionCard> {
  final TaskService _taskService = TaskService();
  bool _isActing = false;

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<UserProvider>().userId ?? '';
    final isManager = widget.board.isManager(currentUserId);
    final isOwnSubmission = widget.thought.authorId == currentUserId;
    final metadata = widget.thought.metadata ?? const <String, dynamic>{};
    final submissionState =
        (metadata['submissionState']?.toString() ?? '').trim().toLowerCase();
    final selectedUploads = _selectedUploads(metadata);
    final canAccessUploads =
        isManager || isOwnSubmission || submissionState == 'approved';
    final canReview = isManager && submissionState == 'submitted' && !_isActing;
    final feedbackMessage = (metadata['feedbackMessage']?.toString() ?? '').trim();
    final taskTitle = _metadataValue(metadata, 'taskTitle') ?? 'Task';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.thought.title.trim().isEmpty
                      ? 'Submission'
                      : widget.thought.title.trim(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _statusPill(submissionState),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.thought.message.trim().isEmpty
                ? 'No note added.'
                : widget.thought.message.trim(),
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaPill(Icons.task_alt_outlined, taskTitle),
              _metaPill(Icons.person_outline, widget.thought.authorName),
              _metaPill(
                Icons.attach_file,
                '${selectedUploads.length} upload(s)',
              ),
            ],
          ),
          if (feedbackMessage.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Feedback: $feedbackMessage',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
          if (selectedUploads.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              canAccessUploads ? 'Files' : 'Files are available after approval.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedUploads.map((upload) {
                final fileName = upload['fileName'] ?? 'File';
                final fileUrl = upload['fileUrl'] ?? '';
                return OutlinedButton.icon(
                  onPressed: canAccessUploads && fileUrl.isNotEmpty
                      ? () => _openUpload(fileUrl)
                      : null,
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: Text(fileName),
                );
              }).toList(),
            ),
          ],
          if (canReview) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _reviewSubmission,
                    child: const Text('Review Submission'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String submissionState) {
    final label = submissionState.isEmpty
        ? 'submitted'
        : submissionState.replaceAll('_', ' ');
    final color = switch (submissionState) {
      'approved' => Colors.green,
      'rejected' => Colors.red,
      'changes_requested' => Colors.orange,
      _ => Colors.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String? _metadataValue(Map<String, dynamic> metadata, String key) {
    final value = metadata[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  List<Map<String, String>> _selectedUploads(Map<String, dynamic> metadata) {
    final raw = metadata['selectedUploads'];
    if (raw is! List) return const <Map<String, String>>[];
    return raw
        .whereType<Map>()
        .map(
          (entry) => {
            'uploadId': (entry['uploadId']?.toString() ?? '').trim(),
            'fileName': (entry['fileName']?.toString() ?? '').trim(),
            'fileUrl': (entry['fileUrl']?.toString() ?? '').trim(),
          },
        )
        .toList();
  }

  Future<void> _openUpload(String fileUrl) async {
    final uri = Uri.tryParse(fileUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _reviewSubmission() async {
    final messenger = ScaffoldMessenger.of(context);
    final thoughtProvider = context.read<ThoughtProvider>();
    final taskProvider = context.read<TaskProvider>();
    final notificationProvider = context.read<NotificationProvider>();
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No signed-in user found.')),
      );
      return;
    }

    final review = await _showSubmissionReviewDialog();
    if (!mounted || review == null) return;

    setState(() {
      _isActing = true;
    });

    try {
      final task = await _taskService.getTaskById(widget.thought.taskId);
      if (task == null) {
        throw StateError('Task not found.');
      }

      final metadata = Map<String, dynamic>.from(
        widget.thought.metadata ?? const <String, dynamic>{},
      );
      final now = DateTime.now();
      String submissionState = 'approved';
      Task updatedTask = task.copyWith(
        taskLatestSubmissionThoughtId: widget.thought.thoughtId,
      );

      switch (review.verdict) {
        case _SubmissionVerdict.success:
          submissionState = 'approved';
          updatedTask = updatedTask.copyWith(
            taskIsDone: true,
            taskIsDoneAt: now,
            taskStatus: Task.statusCompleted,
            taskOutcome: Task.outcomeSuccessful,
            taskFailed: false,
            taskApprovalStatus: 'approved',
          );
          break;
        case _SubmissionVerdict.failure:
          submissionState = 'rejected';
          updatedTask = updatedTask.copyWith(
            taskIsDone: true,
            taskIsDoneAt: now,
            taskStatus: Task.statusCompleted,
            taskOutcome: Task.outcomeFailed,
            taskFailed: true,
            taskApprovalStatus: 'rejected',
          );
          break;
        case _SubmissionVerdict.needsRevision:
          submissionState = 'changes_requested';
          updatedTask = updatedTask.copyWith(
            taskIsDone: false,
            taskIsDoneAt: null,
            taskStatus: Task.statusPaused,
            taskOutcome: Task.outcomeNone,
            taskFailed: false,
            taskApprovalStatus: 'changes_requested',
          );
          break;
      }

      await taskProvider.updateTask(updatedTask);
      await thoughtProvider.updateThought(
        widget.thought.copyWith(
          status: Thought.statusResolved,
          updatedAt: now,
          actionedAt: now,
          actionedBy: currentUser.userId,
          actionedByName: currentUser.userName,
          metadata: {
            ...metadata,
            'submissionState': submissionState,
            'feedbackMessage': review.feedback.trim(),
            'verdict': review.verdict.name,
            'reviewedByUserId': currentUser.userId,
            'reviewedByUserName': currentUser.userName,
            'reviewedAt': now.toIso8601String(),
          },
        ),
      );

      await _createSubmissionReviewNotification(
        notificationProvider: notificationProvider,
        reviewer: currentUser,
        verdict: review.verdict,
        feedback: review.feedback.trim(),
      );

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Submission marked as ${review.verdict.label}.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to review submission: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
        });
      }
    }
  }

  Future<_SubmissionReviewResult?> _showSubmissionReviewDialog() async {
    final feedbackController = TextEditingController();
    var verdict = _SubmissionVerdict.success;

    final result = await showDialog<_SubmissionReviewResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Review Submission'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<_SubmissionVerdict>(
                      segments: _SubmissionVerdict.values
                          .map(
                            (value) => ButtonSegment<_SubmissionVerdict>(
                              value: value,
                              label: Text(value.segmentLabel),
                            ),
                          )
                          .toList(),
                      selected: {verdict},
                      onSelectionChanged: (selection) {
                        if (selection.isEmpty) return;
                        setDialogState(() {
                          verdict = selection.first;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: feedbackController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Feedback',
                        border: OutlineInputBorder(),
                        hintText: 'Leave feedback for the member.',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(
                    _SubmissionReviewResult(
                      verdict: verdict,
                      feedback: feedbackController.text,
                    ),
                  ),
                  child: const Text('Save Review'),
                ),
              ],
            );
          },
        );
      },
    );
    feedbackController.dispose();
    return result;
  }

  Future<void> _createSubmissionReviewNotification({
    required NotificationProvider notificationProvider,
    required UserModel reviewer,
    required _SubmissionVerdict verdict,
    required String feedback,
  }) async {
    final recipientUserId = widget.thought.authorId.trim();
    if (recipientUserId.isEmpty || recipientUserId == reviewer.userId) return;

    final reviewerName = reviewer.userName.trim().isEmpty
        ? 'Unknown'
        : reviewer.userName.trim();
    final metadata = widget.thought.metadata ?? const <String, dynamic>{};
    final notificationSeed =
        (metadata['notificationSeed']?.toString() ?? const Uuid().v4()).trim();

    final title = switch (verdict) {
      _SubmissionVerdict.success => 'Submission Approved',
      _SubmissionVerdict.failure => 'Submission Failed',
      _SubmissionVerdict.needsRevision => 'Revisions Requested',
    };

    final message = switch (verdict) {
      _SubmissionVerdict.success =>
        '$reviewerName approved your submission for ${_metadataValue(metadata, 'taskTitle') ?? 'the task'}.',
      _SubmissionVerdict.failure =>
        '$reviewerName marked your submission for ${_metadataValue(metadata, 'taskTitle') ?? 'the task'} as failed.',
      _SubmissionVerdict.needsRevision =>
        '$reviewerName requested revisions for your submission to ${_metadataValue(metadata, 'taskTitle') ?? 'the task'}.',
    };

    await notificationProvider.createNotification(
      AppNotification(
        notificationId: '',
        recipientUserId: recipientUserId,
        title: title,
        message: feedback.isEmpty ? message : '$message Feedback: $feedback',
        type: 'thought_submission_reviewed',
        deliveryStatus: AppNotification.deliveryPending,
        isRead: false,
        isDeleted: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        actorUserId: reviewer.userId,
        actorUserName: reviewerName,
        boardId: widget.thought.boardId.trim().isEmpty ? null : widget.thought.boardId,
        taskId: widget.thought.taskId.trim().isEmpty ? null : widget.thought.taskId,
        thoughtId: widget.thought.thoughtId,
        eventKey:
            '$notificationSeed:$recipientUserId:thought_submission_reviewed:${verdict.name}',
        metadata: {
          'thoughtType': Thought.typeSubmissionFeedback,
          'verdict': verdict.name,
        },
      ),
    );
  }
}

enum _SubmissionVerdict { success, failure, needsRevision }

extension on _SubmissionVerdict {
  String get label => switch (this) {
    _SubmissionVerdict.success => 'successful',
    _SubmissionVerdict.failure => 'failed',
    _SubmissionVerdict.needsRevision => 'needs revisions',
  };

  String get segmentLabel => switch (this) {
    _SubmissionVerdict.success => 'Success',
    _SubmissionVerdict.failure => 'Fail',
    _SubmissionVerdict.needsRevision => 'Revise',
  };
}

class _SubmissionReviewResult {
  const _SubmissionReviewResult({
    required this.verdict,
    required this.feedback,
  });

  final _SubmissionVerdict verdict;
  final String feedback;
}
