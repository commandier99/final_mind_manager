import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../widgets/stat_card_widget.dart';

class TodaysOverviewSection extends StatelessWidget {
  const TodaysOverviewSection({super.key});

  @override
  Widget build(BuildContext context) {
    print('[DEBUG] TodaysOverviewSection: build called');
    final taskProvider = context.watch<TaskProvider>();
    print('[DEBUG] TodaysOverviewSection: TaskProvider has ${taskProvider.tasks.length} total tasks');

    final todayTasks = taskProvider.tasks.where((task) {
      if (task.taskDeadline == null) return false;
      final today = DateTime.now();
      final deadline = task.taskDeadline!;
      return deadline.year == today.year &&
          deadline.month == today.month &&
          deadline.day == today.day;
    }).length;
    print('[DEBUG] TodaysOverviewSection: Tasks due today = $todayTasks');

    final completedToday = taskProvider.tasks.where((task) {
      if (!task.taskIsDone || task.taskIsDoneAt == null) return false;
      final today = DateTime.now();
      final doneAt = task.taskIsDoneAt!;
      return doneAt.year == today.year &&
          doneAt.month == today.month &&
          doneAt.day == today.day;
    }).length;
    print('[DEBUG] TodaysOverviewSection: Tasks completed today = $completedToday');

    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: 'Due Today',
            count: todayTasks,
            icon: Icons.event_available,
            color: const Color(0xFF5B9BD5),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            title: 'Completed Today',
            count: completedToday,
            icon: Icons.verified,
            color: const Color(0xFF66BB6A),
          ),
        ),
      ],
    );
  }
}
