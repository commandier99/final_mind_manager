import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/providers/task_provider.dart';
import '../../../datasources/models/task_model.dart';
import '../../../../../shared/features/search/providers/search_provider.dart';
import '../cards/task_card.dart';

class TasksCompletedSection extends StatelessWidget {
  final String userId;

  const TasksCompletedSection({
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
              .where((task) => task.taskIsDone)
              .toList();
        } else {
          // Use all completed tasks from provider
          tasksToDisplay = taskProvider.tasks
              .where((task) => task.taskIsDone)
              .toList();
        }

        // Show section only if there are completed tasks
        if (tasksToDisplay.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Completed Tasks',
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
                        taskStatus: (isDone ?? false) ? 'COMPLETED' : 'To Do',
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
}
