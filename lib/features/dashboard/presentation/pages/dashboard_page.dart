import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/features/users/datasources/providers/activity_event_provider.dart';
import '../../../../shared/features/users/datasources/providers/user_daily_activity_provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../boards/datasources/providers/board_request_provider.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../widgets/daily_check_in_streak_section.dart';
import '../widgets/mind_set_activity_section.dart';
import '../widgets/task_engagement_section.dart';
import 'daily_check_in_details_page.dart';
import 'daily_productivity_details_page.dart';
import 'task_engagement_details_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<UserProvider>().userId;
      if (userId == null) return;
      context.read<BoardRequestProvider>().streamRequestsByUser(userId);
      context.read<TaskProvider>().streamAllUserTasks(userId);
      context.read<ActivityEventProvider>().listenToUser(userId);
      context.read<UserDailyActivityProvider>().loadRecentDays(userId, days: 14);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DailyCheckInStreakSection(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const DailyCheckInDetailsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _dailyProductivityOverviewCard(),
            const SizedBox(height: 16),
            TaskEngagementSection(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TaskEngagementDetailsPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const MindSetActivitySection(),
          ],
        ),
      ),
    );
  }

  Widget _dailyProductivityOverviewCard() {
    final recent = context.watch<UserDailyActivityProvider>().recentDays;
    final last7 = recent.length <= 7 ? recent : recent.sublist(recent.length - 7);

    int scoreFor(dynamic day) =>
        day.tasksCompletedCount + day.stepsCompletedCount + day.stepsCreatedCount;

    final todayScore = recent.isEmpty ? 0 : scoreFor(recent.last);
    final weeklyTotal = last7.fold<int>(0, (sum, day) => sum + scoreFor(day));
    final weeklyAvg = last7.isEmpty ? 0 : (weeklyTotal / last7.length).round();
    final bestDay = last7.isEmpty
        ? 0
        : last7.map<int>(scoreFor).reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const DailyProductivityDetailsPage(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Daily Productivity',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    'Today: $todayScore',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _overviewMetric(
                      label: '7-Day Avg',
                      value: '$weeklyAvg',
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _overviewMetric(
                      label: 'Best Day',
                      value: '$bestDay',
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _overviewMetric(
                      label: '7-Day Total',
                      value: '$weeklyTotal',
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Tap to open full productivity analytics and choose metrics.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overviewMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

