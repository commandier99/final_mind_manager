import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../../../datasources/models/task_model.dart';
import '../../../datasources/providers/task_provider.dart';
import '../../pages/task_details_page.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final ValueChanged<bool?>? onToggleDone;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onDelete,
    this.onToggleDone,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  bool _hasSubtasks() {
    return (widget.task.taskStats.taskSubtasksCount ?? 0) > 0;
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityBackgroundColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade100;
      case 'medium':
        return Colors.orange.shade100;
      case 'low':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OVERDUE':
        return Colors.red;
      case 'TODO':
        return Colors.grey;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'IN_REVIEW':
        return Colors.yellow;
      case 'ON_PAUSE':
        return const Color.fromARGB(255, 0, 225, 255);
      case 'UNDER_REVISION':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'OVERDUE':
        return Icons.error;
      case 'TODO':
        return Icons.circle_outlined;
      case 'IN_PROGRESS':
        return Icons.autorenew;
      case 'IN_REVIEW':
        return Icons.visibility;
      case 'ON_PAUSE':
        return Icons.pause_circle;
      case 'UNDER_REVISION':
        return Icons.edit;
      case 'COMPLETED':
        return Icons.check_circle;
      default:
        return Icons.circle_outlined;
    }
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

  @override
  Widget build(BuildContext context) {
    final done = widget.task.taskStats.taskSubtasksDoneCount ?? 0;
    final total = widget.task.taskStats.taskSubtasksCount ?? 0;
    final progress =
        widget.task.taskIsDone ? 1.0 : (total > 0 ? done / total : 0.0);
    final percent =
        widget.task.taskIsDone
            ? 100
            : (total > 0 ? (progress * 100).round() : 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Slidable(
        key: ValueKey(widget.task.taskId),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) => widget.onDelete?.call(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
              borderRadius: BorderRadius.circular(12),
            ),
              ],
            ),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskDetailsPage(task: widget.task),
                  ),
                );
              },
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                  side: BorderSide(
                    color: Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.zero,
                    color: Colors.transparent,
                  ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.label,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.task.taskBoardTitle ?? 'Personal',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(width: 8),
                                  // Priority badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getPriorityBackgroundColor(
                                        widget.task.taskPriorityLevel,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      widget.task.taskPriorityLevel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _getPriorityColor(
                                          widget.task.taskPriorityLevel,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // Right side - just status
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _getStatusColor(
                                      widget.task.taskStatus,
                                    ),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Status: ${widget.task.taskStatus}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusColor(
                                      widget.task.taskStatus,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Divider(height: 1, color: Colors.grey.shade300),
                          // Additional badges row (approval, acceptance, helpers)
                          if (widget.task.taskRequiresApproval ||
                              widget.task.taskAcceptanceStatus != null ||
                              widget.task.taskHelpers.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  // Approval indicator
                                  if (widget.task.taskRequiresApproval)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Tooltip(
                                        message: 'Requires approval',
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.check_circle_outline,
                                            size: 12,
                                            color: Colors.amber.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 6),
                                  // Acceptance status
                                  if (widget.task.taskAcceptanceStatus !=
                                      null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Tooltip(
                                        message: _getAcceptanceStatusLabel(
                                          widget.task.taskAcceptanceStatus,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                _getAcceptanceStatusColor(
                                                  widget
                                                      .task
                                                      .taskAcceptanceStatus,
                                                ).withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _getAcceptanceStatusLabel(
                                              widget.task
                                                  .taskAcceptanceStatus,
                                            ),
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  _getAcceptanceStatusColor(
                                                    widget
                                                        .task
                                                        .taskAcceptanceStatus,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 6),
                                  // Helpers count
                                  if (widget.task.taskHelpers.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Tooltip(
                                        message:
                                            '${widget.task.taskHelpers.length} helper${widget.task.taskHelpers.length > 1 ? 's' : ''}',
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade100,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.people,
                                                size: 11,
                                                color: Colors.teal.shade700,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                widget.task.taskHelpers.length
                                                    .toString(),
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: widget.task.taskIsDone,
                            onChanged: (bool? newValue) {
                              widget.onToggleDone?.call(newValue);
                            },
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.task.taskTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Flexible(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.task.taskDeadline != null
                                              ? _formatDate(
                                                widget.task.taskDeadline!,
                                              )
                                              : 'No deadline',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                        if (widget.task.taskIsRepeating) ...[
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.repeat,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatRepeatDays(
                                              widget.task.taskRepeatInterval,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_hasSubtasks())
                            SizedBox(
                              width: 45,
                              height: 45,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 3,
                                    backgroundColor: Colors.grey.shade300,
                                    color:
                                        widget.task.taskIsDone
                                            ? Colors.green
                                            : Colors.blue,
                                  ),
                                  Text(
                                    widget.task.taskIsDone ? "100%" : "$percent%",
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(width: 8),
                          // const SizedBox(width: 8),
                          // // Focus button - Commented out, focus session feature not used
                          // Tooltip(
                          //   message: _isFocused ? 'Unfocus' : 'Set as current task',
                          //   child: GestureDetector(
                          //     onTap: () {
                          //       setState(() {
                          //         _isFocused = !_isFocused;
                          //       });
                          //     },
                          //     child: Container(
                          //       padding: const EdgeInsets.all(8),
                          //       decoration: BoxDecoration(
                          //         color: _isFocused ? Colors.blue : Colors.blue.shade50,
                          //         borderRadius: BorderRadius.circular(8),
                          //         border: Border.all(
                          //           color: Colors.blue,
                          //           width: 1.5,
                          //         ),
                          //       ),
                          //       child: Icon(
                          //         Icons.adjust,
                          //         size: 20,
                          //         color: _isFocused ? Colors.white : Colors.blue,
                          //       ),
                          //     ),
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _formatRepeatDays(String? repeatInterval) {
    if (repeatInterval == null || repeatInterval.isEmpty) {
      return '';
    }

    final days = repeatInterval.split(',');
    const allDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const dayAbbreviations = {
      'Monday': 'Mo',
      'Tuesday': 'Tu',
      'Wednesday': 'We',
      'Thursday': 'Th',
      'Friday': 'Fr',
      'Saturday': 'Sa',
      'Sunday': 'Su',
    };

    // Check if all days are selected
    if (days.length == 7 &&
        days.every((day) => allDays.contains(day.trim()))) {
      return 'Daily';
    }

    // Abbreviate selected days
    return days.map((day) => dayAbbreviations[day.trim()] ?? '').join(', ');
  }
}
