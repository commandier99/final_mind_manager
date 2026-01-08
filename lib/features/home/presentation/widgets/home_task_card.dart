import 'package:flutter/material.dart';
import '../../../tasks/datasources/models/task_model.dart';
import '../../../tasks/presentation/pages/task_details_page.dart';

class HomeTaskCard extends StatefulWidget {
  final Task task;
  final Widget leadingWidget;
  final Color priorityColor;
  final TextStyle? titleStyle;
  final ValueChanged<bool?>? onToggleDone;

  const HomeTaskCard({
    super.key,
    required this.task,
    required this.leadingWidget,
    required this.priorityColor,
    this.titleStyle,
    this.onToggleDone,
  });

  @override
  State<HomeTaskCard> createState() => _HomeTaskCardState();
}

class _HomeTaskCardState extends State<HomeTaskCard> {
  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'TODO':
        return Colors.grey;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'IN_REVIEW':
        return Colors.purple;
      case 'ON_PAUSE':
        return Colors.orange;
      case 'UNDER_REVISION':
        return Colors.red;
      case 'COMPLETED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
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

  double _getProgress() {
    final done = widget.task.taskStats.taskSubtasksDoneCount ?? 0;
    final total = widget.task.taskStats.taskSubtasksCount ?? 0;
    return total > 0 ? done / total : 0.0;
  }

  bool _hasSubtasks() {
    return (widget.task.taskStats.taskSubtasksCount ?? 0) > 0;
  }

  String _getProgressPercent() {
    final total = widget.task.taskStats.taskSubtasksCount ?? 0;
    if (total == 0) return "0%";
    final percent = ((_getProgress()) * 100).round();
    return "$percent%";
  }

  @override
  Widget build(BuildContext context) {
    final progress = _getProgress();
    final percent = widget.task.taskIsDone ? 100 : (int.tryParse(_getProgressPercent()) ?? 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailsPage(task: widget.task),
            ),
          );
        },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Checkbox
                  Checkbox(
                    value: widget.task.taskIsDone,
                    onChanged: (bool? newValue) {
                      widget.onToggleDone?.call(newValue);
                    },
                  ),
                  const SizedBox(width: 8),

                  // Task info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.taskTitle,
                          style: widget.titleStyle ??
                              const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.label,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.task.taskBoardTitle ?? 'Personal',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: widget.priorityColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.task.taskPriorityLevel,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: widget.priorityColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Progress circle
                  if (_hasSubtasks())
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 2.5,
                            backgroundColor: Colors.grey.shade300,
                            color: widget.task.taskIsDone ? Colors.green : Colors.blue,
                          ),
                          Text(
                            widget.task.taskIsDone ? "100%" : "$percent%",
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8),

                  // const SizedBox(width: 8),
                  // // Focus button - Commented out
                  // SizedBox(
                  //   width: 40,
                  //   height: 40,
                  //   child: GestureDetector(
                  //     onTap: () {
                  //       if (_isFocused) {
                  //         setState(() {
                  //           _isFocused = false;
                  //         });
                  //       } else {
                  //         showDialog(
                  //           context: context,
                  //           builder: (context) =>
                  //               FocusTimerSetupDialog(task: widget.task),
                  //         );
                  //         setState(() {
                  //           _isFocused = true;
                  //         });
                  //       }
                  //     },
                  //     child: Container(
                  //       padding: const EdgeInsets.all(8),
                  //       decoration: BoxDecoration(
                  //         color: _isFocused
                  //             ? widget.priorityColor
                  //             : Colors.transparent,
                  //         border: Border.all(
                  //           color: widget.priorityColor,
                  //           width: 1,
                  //         ),
                  //         borderRadius: BorderRadius.circular(4),
                  //       ),
                  //       child: Icon(
                  //         Icons.adjust,
                  //         size: 18,
                  //         color: _isFocused ? Colors.white : widget.priorityColor,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        );
  }
}
