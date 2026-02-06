import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../tasks/datasources/models/task_model.dart';
import '../../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../../tasks/presentation/widgets/cards/task_card.dart';

class FollowThroughTaskStream extends StatefulWidget {
  final List<String> taskIds;
  final String mode;

  const FollowThroughTaskStream({
    super.key,
    required this.taskIds,
    required this.mode,
  });

  @override
  State<FollowThroughTaskStream> createState() => _FollowThroughTaskStreamState();
}

class _FollowThroughTaskStreamState extends State<FollowThroughTaskStream> {
  @override
  void initState() {
    super.initState();
    _streamTasks();
  }

  @override
  void didUpdateWidget(covariant FollowThroughTaskStream oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.taskIds, widget.taskIds)) {
      _streamTasks();
    }
  }

  void _streamTasks() {
    final taskProvider = context.read<TaskProvider>();
    taskProvider.streamTasksByIds(widget.taskIds);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Plan Tasks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Consumer<TaskProvider>(
            builder: (context, taskProvider, _) {
              if (taskProvider.isLoading && taskProvider.tasks.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (widget.taskIds.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Text(
                      'This plan has no tasks yet.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final tasks = _sortTasksByPlan(taskProvider.tasks, widget.taskIds);

              if (tasks.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Text(
                      'No tasks found for this plan.',
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
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return TaskCard(
                    task: task,
                    onToggleDone: (isDone) {
                      final taskProvider =
                          Provider.of<TaskProvider>(context, listen: false);
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
          ),
        ),
      ],
    );
  }

  List<Task> _sortTasksByPlan(List<Task> tasks, List<String> order) {
    final orderMap = <String, int>{};
    for (var i = 0; i < order.length; i++) {
      orderMap[order[i]] = i;
    }

    final sorted = [...tasks];
    sorted.sort((a, b) {
      final aIndex = orderMap[a.taskId] ?? order.length;
      final bIndex = orderMap[b.taskId] ?? order.length;
      return aIndex.compareTo(bIndex);
    });
    return sorted;
  }
}
