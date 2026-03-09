import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/models/task_submission_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/datasources/services/task_submission_service.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../datasources/providers/board_provider.dart';

class BoardSubmissionsSection extends StatefulWidget {
  final String boardId;

  const BoardSubmissionsSection({super.key, required this.boardId});

  @override
  State<BoardSubmissionsSection> createState() => _BoardSubmissionsSectionState();
}

class _BoardSubmissionsSectionState extends State<BoardSubmissionsSection> {
  final TaskSubmissionService _submissionService = TaskSubmissionService();
  final Set<String> _reviewingSubmissionIds = <String>{};

  int _statusRank(String status) {
    switch (TaskSubmission.normalizeStatus(status)) {
      case TaskSubmission.statusPending:
        return 0;
      case TaskSubmission.statusRevisionRequested:
        return 1;
      case TaskSubmission.statusRejected:
        return 2;
      case TaskSubmission.statusApproved:
        return 3;
      default:
        return 9;
    }
  }

  Color _statusColor(String status) {
    switch (TaskSubmission.normalizeStatus(status)) {
      case TaskSubmission.statusApproved:
        return Colors.green;
      case TaskSubmission.statusRejected:
        return Colors.red;
      case TaskSubmission.statusRevisionRequested:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _statusLabel(String status) {
    return TaskSubmission.normalizeStatus(
      status,
    ).replaceAll('_', ' ').toUpperCase();
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _reviewSubmission({
    required TaskSubmission submission,
    required String status,
  }) async {
    final feedbackController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(status == 'approved' ? 'Approve submission?' : 'Reject submission?'),
        content: TextField(
          controller: feedbackController,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Feedback (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      feedbackController.dispose();
      return;
    }

    setState(() => _reviewingSubmissionIds.add(submission.submissionId));
    try {
      final feedback = feedbackController.text.trim();
      await _submissionService.reviewSubmission(
        submissionId: submission.submissionId,
        status: status,
        feedback: feedback.isEmpty ? null : feedback,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission ${status.replaceAll('_', ' ')}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to review submission: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      feedbackController.dispose();
      if (mounted) {
        setState(() => _reviewingSubmissionIds.remove(submission.submissionId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<TaskProvider, BoardProvider, UserProvider>(
      builder: (context, taskProvider, boardProvider, userProvider, _) {
        final currentUserId = userProvider.userId;
        final board = boardProvider.getBoardById(widget.boardId);
        final canReview = board?.canReviewSubmissions(currentUserId) == true;

        final boardTasks = taskProvider.tasks
            .where(
              (task) =>
                  task.taskBoardId == widget.boardId &&
                  !task.taskIsDeleted &&
                  task.taskBoardLane == Task.lanePublished &&
                  task.taskAllowsSubmissions,
            )
            .toList();

        if (boardTasks.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('No tasks with submissions enabled.')),
          );
        }

        final taskById = <String, Task>{for (final t in boardTasks) t.taskId: t};
        final boardTaskIds = boardTasks.map((t) => t.taskId).toList();

        return StreamBuilder<List<TaskSubmission>>(
          stream: _submissionService.streamSubmissionsForTaskIds(boardTaskIds),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Error loading submissions: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            final allSubmissions = snapshot.data ?? const <TaskSubmission>[];
            final submissions = allSubmissions
                .where((s) => taskById.containsKey(s.taskId))
                .toList()
              ..sort((a, b) {
                final statusCompare = _statusRank(a.status).compareTo(
                  _statusRank(b.status),
                );
                if (statusCompare != 0) return statusCompare;
                return b.submittedAt.compareTo(a.submittedAt);
              });

            if (submissions.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('No file submissions yet.')),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: submissions.length,
              itemBuilder: (context, index) {
                final submission = submissions[index];
                final task = taskById[submission.taskId]!;
                final statusColor = _statusColor(submission.status);
                final isReviewing = _reviewingSubmissionIds.contains(
                  submission.submissionId,
                );
                final canReviewThis =
                    canReview &&
                    !isReviewing &&
                    TaskSubmission.normalizeStatus(submission.status) !=
                        TaskSubmission.statusApproved;

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.taskTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _statusLabel(submission.status),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'By ${submission.submittedByName} • ${_formatDateTime(submission.submittedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        if (submission.feedback != null &&
                            submission.feedback!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Feedback: ${submission.feedback}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        ...submission.files.map(
                          (file) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: InkWell(
                              onTap: () => _openFile(file.fileUrl),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.attach_file,
                                      size: 16,
                                      color: Colors.blue,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        file.fileName,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (canReviewThis) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _reviewSubmission(
                                    submission: submission,
                                    status: TaskSubmission.statusApproved,
                                  ),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Approve'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _reviewSubmission(
                                    submission: submission,
                                    status: TaskSubmission.statusRejected,
                                  ),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Reject'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else if (isReviewing) ...[
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(minHeight: 3),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)} ${two(dateTime.hour)}:${two(dateTime.minute)}';
  }
}
