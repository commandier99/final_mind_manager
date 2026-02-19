import 'package:flutter/material.dart';
import '../../../datasources/models/task_model.dart';

class FocusedTaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onPause;
  final ValueChanged<bool?>? onToggleDone;

  const FocusedTaskCard({
    super.key,
    required this.task,
    this.onPause,
    this.onToggleDone,
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

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              priorityColor.withAlpha(25),
              priorityColor.withAlpha(12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: priorityColor.withAlpha(100),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            // Checkbox
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: task.taskIsDone,
                onChanged: onToggleDone,
                activeColor: priorityColor,
                side: BorderSide(
                  color: priorityColor.withAlpha(150),
                  width: 2,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Task title and board
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.taskTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      decoration: task.taskIsDone ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'From ${task.taskBoardTitle ?? 'Unknown'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Pause button
            GestureDetector(
              onTap: onPause,
              child: Container(
                decoration: BoxDecoration(
                  color: priorityColor.withAlpha(220),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.pause,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}