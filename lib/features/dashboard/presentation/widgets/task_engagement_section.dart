import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/features/users/datasources/providers/activity_event_provider.dart';
import '../../../../shared/features/users/datasources/models/activity_event_model.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../../tasks/datasources/models/task_model.dart';

class TaskEngagementSection extends StatelessWidget {
  const TaskEngagementSection({super.key});

  int _getTaskOpenedTodayCount(List<ActivityEvent> events) {
    final today = DateTime.now();
    return events.where((event) {
      final isToday =
          event.ActEvTimestamp.year == today.year &&
          event.ActEvTimestamp.month == today.month &&
          event.ActEvTimestamp.day == today.day;
      return isToday && event.ActEvType == 'task_opened';
    }).length;
  }

  int _getFileSubmissionsTodayCount(List<ActivityEvent> events) {
    final today = DateTime.now();
    return events.where((event) {
      final isToday =
          event.ActEvTimestamp.year == today.year &&
          event.ActEvTimestamp.month == today.month &&
          event.ActEvTimestamp.day == today.day;
      return isToday && event.ActEvType == 'file_submitted';
    }).length;
  }

  List<ActivityEvent> _getRecentlyOpenedTasks(List<ActivityEvent> events) {
    final today = DateTime.now();
    return events
        .where((event) {
          final isToday =
              event.ActEvTimestamp.year == today.year &&
              event.ActEvTimestamp.month == today.month &&
              event.ActEvTimestamp.day == today.day;
          return isToday && event.ActEvType == 'task_opened';
        })
        .toList()
        .take(1)
        .toList();
  }

  Task? _getMostVisitedTask(
    List<ActivityEvent> events,
    TaskProvider taskProvider,
  ) {
    final today = DateTime.now();
    final todayEvents = events.where((event) {
      final isToday =
          event.ActEvTimestamp.year == today.year &&
          event.ActEvTimestamp.month == today.month &&
          event.ActEvTimestamp.day == today.day;
      return isToday && event.ActEvType == 'task_opened';
    }).toList();

    if (todayEvents.isEmpty) return null;

    // Count opens per task
    final taskOpenCounts = <String, int>{};
    for (final event in todayEvents) {
      if (event.ActEvTaskId != null) {
        taskOpenCounts[event.ActEvTaskId!] =
            (taskOpenCounts[event.ActEvTaskId!] ?? 0) + 1;
      }
    }

    if (taskOpenCounts.isEmpty) return null;

    // Find the most opened task
    final mostOpenedTaskId = taskOpenCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return taskProvider.tasks.firstWhereOrNull(
      (t) => t.taskId == mostOpenedTaskId,
    );
  }

  Task? _getFirstTaskVisited(
    List<ActivityEvent> events,
    TaskProvider taskProvider,
  ) {
    final today = DateTime.now();
    final todayEvents = events.where((event) {
      final isToday =
          event.ActEvTimestamp.year == today.year &&
          event.ActEvTimestamp.month == today.month &&
          event.ActEvTimestamp.day == today.day;
      return isToday && event.ActEvType == 'task_opened';
    }).toList();

    if (todayEvents.isEmpty) return null;

    // Sort by timestamp (earliest first)
    todayEvents.sort((a, b) => a.ActEvTimestamp.compareTo(b.ActEvTimestamp));

    final firstTaskId = todayEvents.first.ActEvTaskId;
    if (firstTaskId == null) return null;

    return taskProvider.tasks.firstWhereOrNull((t) => t.taskId == firstTaskId);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ActivityEventProvider, TaskProvider>(
      builder: (context, activityProvider, taskProvider, _) {
        final taskOpenedToday = _getTaskOpenedTodayCount(
          activityProvider.events,
        );
        final submissionsToday = _getFileSubmissionsTodayCount(
          activityProvider.events,
        );
        final recentTasks = _getRecentlyOpenedTasks(activityProvider.events);
        final mostVisitedTask = _getMostVisitedTask(
          activityProvider.events,
          taskProvider,
        );
        final firstTaskVisited = _getFirstTaskVisited(
          activityProvider.events,
          taskProvider,
        );

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Task Engagement for Today',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.task_alt,
                        label: 'Tasks Opened',
                        value: taskOpenedToday.toString(),
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.upload_file,
                        label: 'Files Submitted',
                        value: submissionsToday.toString(),
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Most Visited Task Card
                if (mostVisitedTask != null)
                  _buildMostVisitedTaskCard(context, mostVisitedTask),

                if (mostVisitedTask != null && firstTaskVisited != null)
                  const SizedBox(height: 12),

                // First Task Visited Card
                if (firstTaskVisited != null)
                  _buildFirstTaskVisitedCard(context, firstTaskVisited),

                const SizedBox(height: 20),

                // Recently Opened Tasks
                if (recentTasks.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      'Recently opened task',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _buildRecentTasksList(context, recentTasks, taskProvider),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.task_alt,
                            size: 40,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No tasks opened yet today',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTasksList(
    BuildContext context,
    List<ActivityEvent> recentTasks,
    TaskProvider taskProvider,
  ) {
    return Column(
      children: recentTasks.asMap().entries.map((entry) {
        final index = entry.key;
        final event = entry.value;

        // Find the task in task provider
        final task = taskProvider.tasks.firstWhereOrNull(
          (t) => t.taskId == event.ActEvTaskId,
        );

        if (task == null) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            _buildTaskItem(context, task, event),
            if (index < recentTasks.length - 1)
              Divider(height: 12, color: Colors.grey.shade200),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMostVisitedTaskCard(BuildContext context, Task task) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility, color: Colors.purple, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Most Visited Task',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.taskTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                if (task.taskBoardTitle != null)
                  Text(
                    task.taskBoardTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getPriorityColor(task.taskPriorityLevel).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              task.taskPriorityLevel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _getPriorityColor(task.taskPriorityLevel),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirstTaskVisitedCard(BuildContext context, Task task) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.star, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'First Task Visited',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.taskTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                if (task.taskBoardTitle != null)
                  Text(
                    task.taskBoardTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getPriorityColor(task.taskPriorityLevel).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              task.taskPriorityLevel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _getPriorityColor(task.taskPriorityLevel),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, Task task, ActivityEvent event) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task status indicator
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: task.taskIsDone ? Colors.green : Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Task info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.taskTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (task.taskBoardTitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                    child: Text(
                      task.taskBoardTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(event.ActEvTimestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(
                          task.taskPriorityLevel,
                        ).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        task.taskPriorityLevel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getPriorityColor(task.taskPriorityLevel),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Task status badge
          if (task.taskIsDone)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            )
          else if (task.taskStatus == 'IN_PROGRESS')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'In Progress',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            ),
        ],
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

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

extension FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}
