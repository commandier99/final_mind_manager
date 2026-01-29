import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/models/plans_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../boards/presentation/widgets/cards/board_task_card.dart';

class PlanTasksSection extends StatelessWidget {
  final Plan plan;
  final bool isOwner;

  const PlanTasksSection({
    super.key,
    required this.plan,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tasks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isOwner)
                TextButton.icon(
                  onPressed: () {
                    // TODO: Add functionality to add/remove tasks from plan
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Edit tasks functionality coming soon!'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Tasks List
          Consumer<TaskProvider>(
            builder: (context, taskProvider, _) {
              if (plan.taskIds.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.task_alt,
                          size: 56,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No tasks in this plan',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (taskProvider.isLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              // Filter tasks that belong to this plan
              final planTasks = taskProvider.tasks
                  .where((task) => plan.taskIds.contains(task.taskId))
                  .toList();

              // Sort tasks by the order specified in plan.taskOrder
              planTasks.sort((a, b) {
                final orderA = plan.taskOrder[a.taskId] ?? 999;
                final orderB = plan.taskOrder[b.taskId] ?? 999;
                return orderA.compareTo(orderB);
              });

              if (planTasks.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 56,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tasks not found',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: planTasks.length,
                itemBuilder: (context, index) {
                  final task = planTasks[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: BoardTaskCard(
                      task: task,
                      currentUserId: taskProvider.tasks.isNotEmpty
                          ? task.taskAssignedTo
                          : null,
                      onToggleDone: (isDone) async {
                        await taskProvider.toggleTaskDone(task);
                      },
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
