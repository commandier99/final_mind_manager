import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../../tasks/datasources/models/task_model.dart';
import 'home_task_card.dart';

class TasksCompletedTodayWidget extends StatelessWidget {
  const TasksCompletedTodayWidget({super.key});

  bool _isCompletedToday(Task task) {
    if (!task.taskIsDone || task.taskIsDoneAt == null) return false;

    final today = DateTime.now();
    final doneAt = task.taskIsDoneAt!;

    return doneAt.year == today.year &&
        doneAt.month == today.month &&
        doneAt.day == today.day;
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        final completedToday =
            taskProvider.tasks
                .where((task) => _isCompletedToday(task))
                .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Completed Today',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${completedToday.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (taskProvider.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (completedToday.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No tasks completed today yet',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Complete a task to see it here',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: completedToday.length,
                itemBuilder: (context, index) {
                  final task = completedToday[index];
                  final priorityColor = _getPriorityColor(
                    task.taskPriorityLevel,
                  );

                  return HomeTaskCard(
                    task: task,
                    priorityColor: priorityColor,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    ),
                    leadingWidget: Icon(
                      Icons.check_circle,
                      color: Colors.green.shade600,
                      size: 32,
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
