import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/models/task_submission_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/datasources/services/task_submission_service.dart';

class BoardSubmissionsSection extends StatelessWidget {
  final String boardId;

  const BoardSubmissionsSection({super.key, required this.boardId});

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        final boardTasks = taskProvider.tasks
            .where(
              (task) =>
                  task.taskBoardId == boardId &&
                  !task.taskIsDeleted &&
                  task.taskBoardLane == Task.lanePublished,
            )
            .toList();

        if (boardTasks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: _buildStyledNoSubmissionsState(),
          );
        }

        final taskIds = boardTasks.map((t) => t.taskId).toSet();

        return StreamBuilder<List<TaskSubmission>>(
          stream: TaskSubmissionService().streamAllSubmissions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final allSubmissions = snapshot.data ?? const <TaskSubmission>[];
            final boardSubmissions = allSubmissions
                .where((submission) => taskIds.contains(submission.taskId))
                .toList();

            final latestSubmissionByTaskId = <String, TaskSubmission>{};
            for (final submission in boardSubmissions) {
              final existing = latestSubmissionByTaskId[submission.taskId];
              if (existing == null ||
                  submission.submittedAt.isAfter(existing.submittedAt)) {
                latestSubmissionByTaskId[submission.taskId] = submission;
              }
            }

            final tasksWithSubmission =
                boardTasks
                    .where(
                      (task) =>
                          latestSubmissionByTaskId.containsKey(task.taskId),
                    )
                    .toList()
                  ..sort((a, b) {
                    final aSub = latestSubmissionByTaskId[a.taskId]!;
                    final bSub = latestSubmissionByTaskId[b.taskId]!;
                    return bSub.submittedAt.compareTo(aSub.submittedAt);
                  });

            final missingTasks =
                boardTasks
                    .where(
                      (task) =>
                          !latestSubmissionByTaskId.containsKey(task.taskId),
                    )
                    .toList()
                  ..sort((a, b) {
                    if (a.taskDeadline == null && b.taskDeadline == null) {
                      return 0;
                    }
                    if (a.taskDeadline == null) {
                      return 1;
                    }
                    if (b.taskDeadline == null) {
                      return -1;
                    }
                    return a.taskDeadline!.compareTo(b.taskDeadline!);
                  });

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track completed uploads and tasks still missing submissions.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildCountPill(
                        icon: Icons.assignment,
                        label: 'Tasks',
                        value: '${boardTasks.length}',
                        color: Colors.blueGrey,
                      ),
                      _buildCountPill(
                        icon: Icons.check_circle_outline,
                        label: 'Submitted',
                        value: '${tasksWithSubmission.length}',
                        color: Colors.green,
                      ),
                      _buildCountPill(
                        icon: Icons.error_outline,
                        label: 'Missing',
                        value: '${missingTasks.length}',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildSectionTitle('Missing Submissions'),
                  const SizedBox(height: 8),
                  if (missingTasks.isEmpty)
                    _buildInfoState(
                      icon: Icons.verified_outlined,
                      title: 'No missing submissions',
                      subtitle:
                          'All published tasks currently have at least one submission.',
                    )
                  else ...[
                    ...missingTasks.map(_buildMissingTaskTile),
                  ],
                  const SizedBox(height: 14),
                  _buildSectionTitle('Submitted'),
                  const SizedBox(height: 8),
                  if (tasksWithSubmission.isEmpty)
                    _buildStyledNoSubmissionsState()
                  else ...[
                    ...tasksWithSubmission.map(
                      (task) => _buildSubmittedTile(
                        task: task,
                        submission: latestSubmissionByTaskId[task.taskId]!,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCountPill({
    required IconData icon,
    required String label,
    required String value,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.shade700),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.blueGrey.shade700,
      ),
    );
  }

  Widget _buildMissingTaskTile(Task task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
        color: Colors.orange.shade50,
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.taskTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Assignee: ${task.taskAssignedToName.isEmpty ? 'Unassigned' : task.taskAssignedToName} - Due: ${_formatDate(task.taskDeadline)}',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedTile({
    required Task task,
    required TaskSubmission submission,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
        color: Colors.green.shade50,
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Colors.green.shade700,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.taskTitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'By ${submission.submittedByName} - ${submission.files.length} file(s) - ${_formatDateTime(submission.submittedAt)}',
                  style: TextStyle(fontSize: 11, color: Colors.green.shade900),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white,
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(
              submission.status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.green.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.grey.shade50,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledNoSubmissionsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueGrey.shade100),
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blueGrey.shade50, Colors.white],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blueGrey.shade100),
            ),
            child: Icon(
              Icons.inbox_outlined,
              size: 18,
              color: Colors.blueGrey.shade500,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No submissions yet\nMembers have not uploaded files for these tasks yet.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: Colors.blueGrey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} $hour:$minute $period';
  }
}
