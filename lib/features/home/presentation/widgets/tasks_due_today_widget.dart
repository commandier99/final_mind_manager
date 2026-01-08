import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../../tasks/datasources/models/task_model.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import 'home_task_card.dart';

class TasksDueTodayWidget extends StatelessWidget {
  const TasksDueTodayWidget({super.key});

  bool _isDueToday(Task task) {
    if (task.taskDeadline == null || task.taskIsDone) return false;

    final now = DateTime.now();
    final deadline = task.taskDeadline!;

    // Check if deadline is today
    final isToday = deadline.year == now.year &&
        deadline.month == now.month &&
        deadline.day == now.day;

    // Only show if it's due today AND the time hasn't passed yet (not overdue)
    return isToday && deadline.isAfter(now);
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
        
        final tasksDueToday = taskProvider.tasks
            .where((task) {
              final isDueToday = _isDueToday(task);
              final isUserInvolved = task.taskAssignedTo == userId || 
                                     task.taskOwnerId == userId ||
                                     task.taskHelpers.contains(userId);
              return isDueToday && isUserInvolved;
            })
            .toList();
        
        print('[DEBUG] TasksDueTodayWidget: Found ${tasksDueToday.length} tasks due today for user $userId');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tasks Due Today',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tasksDueToday.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
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
            else if (tasksDueToday.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Press ',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                          Icon(
                            Icons.task,
                            size: 18,
                            color: Colors.grey[600],
                          ),
                          Text(
                            ' to view more tasks.',
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
                itemCount: tasksDueToday.length,
                itemBuilder: (context, index) {
                  final task = tasksDueToday[index];
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
                        color: priorityColor,
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
