import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../../tasks/presentation/widgets/cards/task_card.dart';
import '/features/plans/datasources/models/plans_model.dart';
import '/features/plans/datasources/providers/plan_provider.dart';

class GoWithFlowTaskStream extends StatefulWidget {
  final String userId;
  final String mode;

  const GoWithFlowTaskStream({
    super.key,
    required this.userId,
    required this.mode,
  });

  @override
  State<GoWithFlowTaskStream> createState() => _GoWithFlowTaskStreamState();
}

class _GoWithFlowTaskStreamState extends State<GoWithFlowTaskStream> {
  @override
  void initState() {
    super.initState();
    _streamTasks();
  }

  @override
  void didUpdateWidget(covariant GoWithFlowTaskStream oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _streamTasks();
    }
  }

  void _streamTasks() {
    final taskProvider = context.read<TaskProvider>();
    taskProvider.streamUserActiveTasks(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Unplanned Tasks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Consumer<PlanProvider>(
            builder: (context, planProvider, _) {
              return StreamBuilder<List<Plan>>(
                stream: planProvider.streamUserPlans(widget.userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Text('Error loading plans: ${snapshot.error}');
                  }

                  final plans = snapshot.data ?? [];
                  final plannedTaskIds = <String>{};
                  for (final plan in plans) {
                    plannedTaskIds.addAll(plan.taskIds);
                  }

                  return Consumer<TaskProvider>(
                    builder: (context, taskProvider, _) {
                      if (taskProvider.isLoading &&
                          taskProvider.tasks.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final unplannedTasks = taskProvider.tasks
                          .where((task) => !plannedTaskIds.contains(task.taskId))
                          .toList();

                      if (unplannedTasks.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Text(
                              'No unplanned tasks yet.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: unplannedTasks.length,
                        itemBuilder: (context, index) {
                          final task = unplannedTasks[index];
                          return TaskCard(
                            task: task,
                            onToggleDone: (isDone) {
                              final taskProvider = Provider.of<TaskProvider>(
                                context,
                                listen: false,
                              );
                              taskProvider.toggleTaskDone(
                                task.copyWith(
                                  taskIsDone: isDone ?? false,
                                  taskStatus:
                                      (isDone ?? false) ? 'COMPLETED' : 'To Do',
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
