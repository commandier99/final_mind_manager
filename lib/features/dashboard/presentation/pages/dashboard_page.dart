import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../../shared/features/users/datasources/providers/activity_event_provider.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../../boards/datasources/providers/board_join_request_provider.dart';
import '../widgets/task_engagement_section.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {

  @override
  void initState() {
    super.initState();
    print('[DEBUG] DashboardPage: initState called - Initializing dashboard');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<UserProvider>().userId;
      print('[DEBUG] DashboardPage: userId from UserProvider = $userId');
      if (userId != null) {
        print('[DEBUG] DashboardPage: Streaming board join requests for userId: $userId');
        context.read<BoardJoinRequestProvider>().streamRequestsByUser(userId);
        print('[DEBUG] DashboardPage: Streaming all user tasks for userId: $userId');
        context.read<TaskProvider>().streamAllUserTasks(userId);
        print('[DEBUG] DashboardPage: Streaming activity events for userId: $userId');
        context.read<ActivityEventProvider>().listenToUser(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print('[DEBUG] DashboardPage: build called - Rendering dashboard UI');

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Completion Streak Section
            _buildCompletionStreak(),
            const SizedBox(height: 32),

            // Task Engagement Section
            const TaskEngagementSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionStreak() {
    final taskProvider = context.watch<TaskProvider>();
    final tasks = taskProvider.tasks;

    // Calculate streak: consecutive days with task completions
    int currentStreak = 0;
    int longestStreak = 0;
    DateTime currentDate = DateTime.now();
    
    // Group completed tasks by date
    Map<String, bool> daysWithCompletions = {};
    for (var task in tasks) {
      if (task.taskIsDone && task.taskIsDoneAt != null) {
        String dateKey = '${task.taskIsDoneAt!.year}-${task.taskIsDoneAt!.month}-${task.taskIsDoneAt!.day}';
        daysWithCompletions[dateKey] = true;
      }
    }

    // Calculate current streak (consecutive days ending today)
    DateTime checkDate = currentDate;
    while (true) {
      String dateKey = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
      if (daysWithCompletions.containsKey(dateKey)) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    // Calculate longest streak
    if (daysWithCompletions.isNotEmpty) {
      List<DateTime> sortedDates = daysWithCompletions.keys.map((key) {
        final parts = key.split('-');
        return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }).toList();
      sortedDates.sort();

      int tempStreak = 1;
      for (int i = 1; i < sortedDates.length; i++) {
        if (sortedDates[i].difference(sortedDates[i - 1]).inDays == 1) {
          tempStreak++;
          if (tempStreak > longestStreak) {
            longestStreak = tempStreak;
          }
        } else {
          tempStreak = 1;
        }
      }
      if (longestStreak == 0) longestStreak = 1;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department, color: Colors.orange[700], size: 28),
                const SizedBox(width: 8),
                Text(
                  'Completion Streak',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStreakStat(
                  'Current Streak',
                  currentStreak.toString(),
                  'days',
                  Colors.blue,
                  Icons.trending_up,
                ),
                Container(
                  width: 1,
                  height: 60,
                  color: Colors.grey[300],
                ),
                _buildStreakStat(
                  'Longest Streak',
                  longestStreak.toString(),
                  'days',
                  Colors.purple,
                  Icons.emoji_events,
                ),
              ],
            ),
            if (currentStreak > 0)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentStreak == 1
                            ? 'Keep it up! Complete a task tomorrow to continue your streak.'
                            : '🔥 You\'re on fire! $currentStreak days of task completions!',
                        style: TextStyle(
                          color: Colors.green[900],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Start your streak today by completing a task!',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakStat(String label, String value, String unit, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
