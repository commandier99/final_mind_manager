import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/features/users/datasources/providers/user_stats_provider.dart';
import '../widgets/stat_card_widget.dart';

class UserStatsSection extends StatelessWidget {
  const UserStatsSection({super.key});

  @override
  Widget build(BuildContext context) {
    print('[DEBUG] UserStatsSection: build called');

    try {
      final statsProvider = context.watch<UserStatsProvider>();
      print('[DEBUG] UserStatsSection: UserStatsProvider accessed successfully');
      print('[DEBUG] UserStatsSection: Tasks created = ${statsProvider.stats?.userTasksCreatedCount ?? 0}');
      print('[DEBUG] UserStatsSection: Boards created = ${statsProvider.stats?.userBoardsCreatedCount ?? 0}');

      if (statsProvider.stats == null) {
        print('[DEBUG] UserStatsSection: Stats is null, showing loading');
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Stats',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Tasks Created',
                  count: statsProvider.stats!.userTasksCreatedCount,
                  icon: Icons.task_alt,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Boards Created',
                  count: statsProvider.stats!.userBoardsCreatedCount,
                  icon: Icons.dashboard,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ],
      );
    } catch (e) {
      print('[ERROR] UserStatsSection: Error accessing UserStatsProvider: $e');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error loading stats: $e'),
        ),
      );
    }
  }
}
