import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../datasources/providers/task_provider.dart';
import '../../../datasources/models/task_model.dart';
import '../../../datasources/services/task_submission_service.dart';
import '../../../../boards/datasources/providers/board_provider.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../dialogs/edit_task_dialog.dart';

class TaskDetailsSection extends StatefulWidget {
  final String taskId;
  final VoidCallback? onFileUploadPressed;

  const TaskDetailsSection({
    super.key,
    required this.taskId,
    this.onFileUploadPressed,
  });

  @override
  State<TaskDetailsSection> createState() => _TaskDetailsSectionState();
}

class _TaskDetailsSectionState extends State<TaskDetailsSection> {
  bool _isDescriptionExpanded = false;
  final TaskSubmissionService _submissionService = TaskSubmissionService();

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final currentUserId = userProvider.userId ?? '';

    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        // Find the task from the provider's task list
        final task = taskProvider.tasks.firstWhere(
          (t) => t.taskId == widget.taskId,
          orElse: () => taskProvider.tasks.first, // Fallback
        );

        print(
          '[DEBUG] TaskDetailsSection: build called for taskId = ${task.taskId}',
        );
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title section
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (task.taskTitle.isNotEmpty) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Task Title'),
                                  content: SingleChildScrollView(
                                    child: Text(task.taskTitle),
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
                            task.taskTitle,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'by ${task.taskOwnerName ?? "Unknown"}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      // Only show edit button for task owner or board manager
                      if (_canEditTask(task, currentUserId))
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => EditTaskDialog(task: task),
                            );
                          },
                        ),
                      // Only show upload icon for board tasks
                      if (task.taskBoardId.isNotEmpty && _canToggleTask(task, currentUserId))
                        IconButton(
                          icon: const Icon(Icons.upload_file),
                          tooltip: 'View/Upload files',
                          onPressed: widget.onFileUploadPressed,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Description label and content
              Text(
                'Description:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.taskDescription.isEmpty
                        ? 'No description'
                        : task.taskDescription,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: _isDescriptionExpanded ? null : 3,
                    overflow: _isDescriptionExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                  ),
                  if (task.taskDescription.isNotEmpty &&
                      task.taskDescription.length > 120)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isDescriptionExpanded = !_isDescriptionExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _isDescriptionExpanded ? 'See less' : 'See more...',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Details row - Due, Priority, Status
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Text(
                    'Due: ${_formatDate(task.taskDeadline)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    'Priority: ${task.taskPriorityLevel}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    'Status: ${task.taskStatus}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Assignment info
              if (task.taskAssignedTo.isNotEmpty &&
                  task.taskAssignedTo != 'None')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assignment Info',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          'Assigned to: ${task.taskAssignedToName}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (task.taskAcceptanceStatus != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getAcceptanceStatusColor(
                                task.taskAcceptanceStatus,
                              ).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Acceptance: ${_getAcceptanceStatusLabel(task.taskAcceptanceStatus)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _getAcceptanceStatusColor(
                                  task.taskAcceptanceStatus,
                                ),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (task.taskRequiresApproval)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Requires Approval',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),

              // Helpers info
              if (task.taskHelpers.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Helpers (${task.taskHelpers.length})',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: task.taskHelpers
                          .asMap()
                          .entries
                          .map(
                            (entry) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                task.taskHelperNames[entry.value] ?? 'User',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),

              // Repeating info
              if (task.taskIsRepeating)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Repeating',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        if (task.taskRepeatInterval != null &&
                            task.taskRepeatInterval!.isNotEmpty)
                          Text(
                            'Days: ${_formatRepeatDays(task.taskRepeatInterval)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (task.taskRepeatTime != null)
                          Text(
                            'Time: ${task.taskRepeatTime}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (task.taskRepeatEndDate != null)
                          Text(
                            'Until: ${_formatDate(task.taskRepeatEndDate)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        if (task.taskNextRepeatDate != null)
                          Text(
                            'Next: ${_formatDate(task.taskNextRepeatDate)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _getProgress(task),
                  minHeight: 20,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgress(task) == 1.0 ? Colors.green : Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _getProgressText(task),
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),

              // Divider
              Divider(
                color: Theme.of(context).colorScheme.outlineVariant,
                thickness: 2,
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _getAcceptanceStatusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'declined':
        return 'Declined';
      default:
        return '';
    }
  }

  Color _getAcceptanceStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'declined':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  double _getProgress(Task task) {
    final done = task.taskStats.taskSubtasksDoneCount ?? 0;
    final total = task.taskStats.taskSubtasksCount ?? 0;

    // If task is marked as done, return 100%
    if (task.taskIsDone) return 1.0;

    // If there are no subtasks, return 0%
    if (total == 0) return 0.0;

    // Calculate based on subtasks completion
    return done / total;
  }

  String _getProgressText(Task task) {
    final done = task.taskStats.taskSubtasksDoneCount ?? 0;
    final total = task.taskStats.taskSubtasksCount ?? 0;
    final percent = (_getProgress(task) * 100).round();

    if (task.taskIsDone) {
      return 'Task completed';
    }

    if (total == 0) {
      return 'No subtasks - 0% complete';
    }

    return '$done of $total subtasks completed ($percent%)';
  }

  bool _canEditTask(Task task, String currentUserId) {
    // Task owner can edit
    if (task.taskOwnerId == currentUserId) return true;

    // Board manager can edit
    if (task.taskBoardId.isNotEmpty) {
      final boardProvider = context.read<BoardProvider>();
      final board = boardProvider.boards.firstWhere(
        (b) => b.boardId == task.taskBoardId,
        orElse: () => boardProvider.boards.first,
      );
      if (board.boardManagerId == currentUserId) return true;
    }

    // Members cannot edit
    return false;
  }

  bool _canToggleTask(Task task, String currentUserId) {
    // Task owner can toggle
    if (task.taskOwnerId == currentUserId) return true;

    // Board manager can toggle
    if (task.taskBoardId.isNotEmpty) {
      final boardProvider = context.read<BoardProvider>();
      final board = boardProvider.boards.firstWhere(
        (b) => b.boardId == task.taskBoardId,
        orElse: () => boardProvider.boards.first,
      );
      if (board.boardManagerId == currentUserId) return true;
    }

    // Members cannot toggle
    return false;
  }

  String _formatRepeatDays(String? repeatInterval) {
    if (repeatInterval == null || repeatInterval.isEmpty) return 'Unknown';
    final days = repeatInterval.split(',');
    return days.map((day) => day.substring(0, 3)).join(', ');
  }

  
}
