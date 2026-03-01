import 'package:flutter/material.dart';
import '../../../datasources/models/task_model.dart';

class TaskStatsSection extends StatelessWidget {
  final Task task;

  const TaskStatsSection({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final totalSubtasks = task.taskStats.taskSubtasksCount ?? 0;
    final doneSubtasks = task.taskStats.taskSubtasksDoneCount ?? 0;
    final deletedSubtasks = task.taskStats.taskSubtasksDeletedCount ?? 0;
    final edits = task.taskStats.taskEditsCount ?? 0;
    final deadlinesMissed = task.taskStats.deadlinesMissedCount ?? 0;
    final deadlinesExtended = task.taskStats.deadlinesExtendedCount ?? 0;
    final taskFailed = task.taskStats.tasksFailedCount ?? 0;

    final completionRate = totalSubtasks > 0
        ? doneSubtasks / totalSubtasks
        : 0.0;
    final completionLabel = '${(completionRate * 100).toStringAsFixed(0)}%';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task Stats',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Progress snapshot for this task',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(
            context: context,
            completionRate: completionRate,
            completionLabel: completionLabel,
            doneSubtasks: doneSubtasks,
            totalSubtasks: totalSubtasks,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMetricTile(
                label: 'Subtasks',
                value: '$totalSubtasks',
                icon: Icons.format_list_bulleted,
                color: Colors.indigo,
              ),
              _buildMetricTile(
                label: 'Subtasks Done',
                value: '$doneSubtasks',
                icon: Icons.done_all,
                color: Colors.teal,
              ),
              _buildMetricTile(
                label: 'Subtasks Deleted',
                value: '$deletedSubtasks',
                icon: Icons.remove_done,
                color: Colors.deepOrange,
              ),
              _buildMetricTile(
                label: 'Edits',
                value: '$edits',
                icon: Icons.edit_outlined,
                color: Colors.blue,
              ),
              _buildMetricTile(
                label: 'Missed Deadlines',
                value: '$deadlinesMissed',
                icon: Icons.warning_amber_rounded,
                color: Colors.redAccent,
              ),
              _buildMetricTile(
                label: 'Deadline Extensions',
                value: '$deadlinesExtended',
                icon: Icons.event_repeat_outlined,
                color: Colors.amber,
              ),
              _buildMetricTile(
                label: 'Failed Count',
                value: '$taskFailed',
                icon: Icons.error_outline,
                color: Colors.pink,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required double completionRate,
    required String completionLabel,
    required int doneSubtasks,
    required int totalSubtasks,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50, Colors.cyan.shade50],
        ),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: completionRate,
                  strokeWidth: 7,
                  backgroundColor: Colors.blue.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completionRate >= 1.0 ? Colors.green : Colors.blue,
                  ),
                ),
                Text(
                  completionLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Subtask Completion',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '$doneSubtasks of $totalSubtasks subtasks completed',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(height: 2),
                Text(
                  totalSubtasks == 0
                      ? 'No subtasks created yet'
                      : 'Keep this moving to 100%',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 160,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
