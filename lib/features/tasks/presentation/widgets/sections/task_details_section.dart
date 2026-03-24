import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/models/task_model.dart';
import '../../../datasources/providers/task_provider.dart';

class TaskDetailsSection extends StatefulWidget {
  final String taskId;
  final Task? fallbackTask;

  const TaskDetailsSection({
    super.key,
    required this.taskId,
    this.fallbackTask,
  });

  @override
  State<TaskDetailsSection> createState() => _TaskDetailsSectionState();
}

class _TaskDetailsSectionState extends State<TaskDetailsSection> {
  bool _isDescriptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        Task? task;
        try {
          task = taskProvider.tasks.firstWhere(
            (t) => t.taskId == widget.taskId,
          );
        } catch (_) {
          task = widget.fallbackTask;
        }

        if (task == null) {
          return const SizedBox.shrink();
        }

        final currentTask = task;
        final priorityColor = _getPriorityColor(currentTask.taskPriorityLevel);
        final priorityBg = _getPriorityBackgroundColor(
          currentTask.taskPriorityLevel,
        );
        final statusColor = _getStatusColor(currentTask.taskStatus);

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: priorityBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 13,
                          color: priorityColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          currentTask.taskPriorityLevel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: priorityColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(currentTask.taskStatus),
                          size: 13,
                          color: statusColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          currentTask.taskStatus,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  if (currentTask.taskTitle.isNotEmpty) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Task Title'),
                        content: SingleChildScrollView(
                          child: Text(currentTask.taskTitle),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  }
                },
                child: Text(
                  currentTask.taskTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Created by ${currentTask.taskOwnerName}',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    icon: Icons.event_outlined,
                    label: 'Due ${_formatDate(currentTask.taskDeadline)}',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: Colors.grey.shade300, height: 1),
              const SizedBox(height: 12),
              _buildSectionLabel('Description'),
              const SizedBox(height: 6),
              Text(
                currentTask.taskDescription.isEmpty
                    ? 'No description'
                    : currentTask.taskDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.35,
                ),
                maxLines: _isDescriptionExpanded ? null : 4,
                overflow: _isDescriptionExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
              if (currentTask.taskDescription.isNotEmpty &&
                  currentTask.taskDescription.length > 140)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isDescriptionExpanded = !_isDescriptionExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _isDescriptionExpanded ? 'See less' : 'See more',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (currentTask.taskAssignedTo.isNotEmpty &&
                  currentTask.taskAssignedTo != 'None') ...[
                const SizedBox(height: 14),
                Divider(color: Colors.grey.shade300, height: 1),
                const SizedBox(height: 12),
                _buildSectionLabel('Assignment'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildInfoChip(
                      icon: Icons.person_outline,
                      label: currentTask.taskAssignedToName,
                    ),
                  ],
                ),
              ],
              if (currentTask.taskIsRepeating) ...[
                const SizedBox(height: 14),
                Divider(color: Colors.grey.shade300, height: 1),
                const SizedBox(height: 12),
                _buildSectionLabel('Repeating'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (currentTask.taskRepeatInterval != null &&
                        currentTask.taskRepeatInterval!.isNotEmpty)
                      _buildInfoChip(
                        icon: Icons.today_outlined,
                        label:
                            'Days ${_formatRepeatDays(currentTask.taskRepeatInterval)}',
                      ),
                    if (currentTask.taskRepeatTime != null)
                      _buildInfoChip(
                        icon: Icons.schedule_outlined,
                        label: 'Time ${currentTask.taskRepeatTime}',
                      ),
                    if (currentTask.taskRepeatEndDate != null)
                      _buildInfoChip(
                        icon: Icons.event_busy_outlined,
                        label:
                            'Until ${_formatDate(currentTask.taskRepeatEndDate)}',
                      ),
                    if (currentTask.taskNextRepeatDate != null)
                      _buildInfoChip(
                        icon: Icons.update_outlined,
                        label:
                            'Next ${_formatDate(currentTask.taskNextRepeatDate)}',
                      ),
                  ],
                ),
              ],
              if ((currentTask.taskStats.taskStepsCount ?? 0) > 0) ...[
                const SizedBox(height: 14),
                Divider(color: Colors.grey.shade300, height: 1),
                const SizedBox(height: 12),
                _buildSectionLabel('Progress'),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _getProgress(currentTask),
                    minHeight: 12,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getProgress(currentTask) == 1.0
                          ? Colors.green
                          : Colors.blue.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getProgressText(currentTask),
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.blueGrey.shade700,
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    Color? textColor,
  }) {
    final effectiveText = textColor ?? Colors.blueGrey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.grey.shade100,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: effectiveText),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: effectiveText,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade700;
      case 'medium':
        return Colors.orange.shade700;
      case 'low':
      default:
        return Colors.green.shade700;
    }
  }

  Color _getPriorityBackgroundColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade100;
      case 'medium':
        return Colors.orange.shade100;
      case 'low':
      default:
        return Colors.green.shade100;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green.shade700;
      case 'in progress':
        return Colors.blue.shade700;
      case 'paused':
        return Colors.orange.shade700;
      case 'submitted':
        return Colors.purple.shade700;
      case 'rejected':
        return Colors.red.shade700;
      case 'to do':
      default:
        return Colors.blueGrey.shade700;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'in progress':
        return Icons.play_circle_outline;
      case 'paused':
        return Icons.pause_circle_outline;
      case 'submitted':
        return Icons.upload_file_outlined;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'to do':
      default:
        return Icons.radio_button_unchecked;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  double _getProgress(Task task) {
    final done = task.taskStats.taskStepsDoneCount ?? 0;
    final total = task.taskStats.taskStepsCount ?? 0;

    if (task.taskIsDone) return 1.0;
    if (total == 0) return 0.0;

    return done / total;
  }

  String _getProgressText(Task task) {
    final done = task.taskStats.taskStepsDoneCount ?? 0;
    final total = task.taskStats.taskStepsCount ?? 0;
    final percent = (_getProgress(task) * 100).round();

    if (task.taskIsDone) {
      return 'Task completed';
    }

    if (total == 0) {
      return 'No steps - 0% complete';
    }

    return '$done of $total steps completed ($percent%)';
  }

  String _formatRepeatDays(String? repeatInterval) {
    if (repeatInterval == null || repeatInterval.isEmpty) return 'Unknown';
    final days = repeatInterval.split(',');
    return days.map((day) => day.substring(0, 3)).join(', ');
  }
}

