import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/providers/task_provider.dart';
import '../../../datasources/models/task_model.dart';
import '../../../../../shared/features/search/providers/search_provider.dart';
import '../cards/task_card.dart';

class TasksOngoingSection extends StatelessWidget {
  final String userId;

  const TasksOngoingSection({
    required this.userId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<TaskProvider, SearchProvider>(
      builder: (context, taskProvider, searchProvider, child) {
        // Determine which tasks to display
        List<Task> tasksToDisplay = [];
        
        if (searchProvider.query.isNotEmpty) {
          // Use search results if searching
          tasksToDisplay = searchProvider.filteredTaskResults
              .where((task) => !task.taskIsDone)
              .toList();
        } else {
          // Use all ongoing tasks from provider
          tasksToDisplay = taskProvider.tasks
              .where((task) => !task.taskIsDone)
              .toList();
        }

        // Show empty state
        if (tasksToDisplay.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Icon(
                  Icons.task_alt,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'No ongoing tasks',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a new task to get started',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ongoing Tasks',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ...tasksToDisplay.map((task) {
                return TaskCard(
                  task: task,
                  onDelete: () {
                    final taskProvider =
                        Provider.of<TaskProvider>(context, listen: false);
                    taskProvider.deleteTask(task.taskId);
                  },
                  onToggleDone: (isDone) {
                    final taskProvider =
                        Provider.of<TaskProvider>(context, listen: false);
                    taskProvider.toggleTaskDone(
                      task.copyWith(
                        taskIsDone: isDone ?? false,
                        taskStatus: (isDone ?? false) ? 'COMPLETED' : 'TODO',
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLeadingWidget(Task task) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _getPriorityColor(task.taskPriorityLevel).withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          task.taskPriorityLevel.isNotEmpty 
              ? task.taskPriorityLevel[0].toUpperCase() 
              : 'T',
          style: TextStyle(
            color: _getPriorityColor(task.taskPriorityLevel),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
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
}
