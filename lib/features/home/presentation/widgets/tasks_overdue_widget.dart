import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../../tasks/datasources/models/task_model.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import 'home_task_card.dart';

class TasksOverdueWidget extends StatelessWidget {
  const TasksOverdueWidget({super.key});

  bool _isOverdue(Task task) {
    if (task.taskDeadline == null || task.taskIsDone) return false;

    final now = DateTime.now();
    final deadline = task.taskDeadline!;

    // Task is overdue if the deadline time has passed
    return deadline.isBefore(now);
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
        // Get current user ID
        final userId = context.read<UserProvider>().userId;
        
        final tasksOverdue = taskProvider.tasks
            .where((task) {
              final isOverdue = _isOverdue(task);
              final isUserInvolved = task.taskAssignedTo == userId || 
                                     task.taskOwnerId == userId ||
                                     task.taskHelpers.contains(userId);
              return isOverdue && isUserInvolved;
            })
            .toList();
        
        print('[DEBUG] TasksOverdueWidget: Found ${tasksOverdue.length} overdue tasks for user $userId');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Overdue Tasks',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tasksOverdue.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            if (taskProvider.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (tasksOverdue.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'No overdue tasks. Great job!',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tasksOverdue.length,
                itemBuilder: (context, index) {
                  final task = tasksOverdue[index];
                  final priorityColor = _getPriorityColor(
                    task.taskPriorityLevel,
                  );

                  return HomeTaskCard(
                    task: task,
                    priorityColor: priorityColor,
                    leadingWidget: Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
