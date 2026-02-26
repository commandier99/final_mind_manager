import 'package:flutter/material.dart';
import '../../../datasources/models/task_model.dart';

class FocusedTaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onPause;
  final ValueChanged<bool?>? onToggleDone;
  final bool isPomodoroMode;

  const FocusedTaskCard({
    super.key,
    required this.task,
    this.onPause,
    this.onToggleDone,
    this.isPomodoroMode = false,
  });

  Color _getPriorityColor() {
    switch (task.taskPriorityLevel.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor();
    final canPause = onPause != null && !isPomodoroMode;

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [priorityColor.withAlpha(30), priorityColor.withAlpha(8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: priorityColor.withAlpha(110), width: 1.4),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: priorityColor.withAlpha(28),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: Checkbox(
                    value: task.taskIsDone,
                    onChanged: onToggleDone,
                    activeColor: priorityColor,
                    side: BorderSide(
                      color: priorityColor.withAlpha(170),
                      width: 1.8,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.taskTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          decoration: task.taskIsDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'From ${task.taskBoardTitle ?? 'Unknown'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (canPause)
                  IconButton(
                    onPressed: onPause,
                    tooltip: 'Pause task',
                    style: IconButton.styleFrom(
                      backgroundColor: priorityColor.withAlpha(220),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(8),
                    ),
                    icon: const Icon(Icons.pause, size: 20),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
