import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/features/users/datasources/providers/activity_event_provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../widgets/daily_check_in_streak_section.dart';

class DailyCheckInDetailsPage extends StatelessWidget {
  const DailyCheckInDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Check-in')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DailyCheckInStreakSection(showMonthOverview: true),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Check in once a day to maintain streak consistency.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final userProvider = context.read<UserProvider>();
                      final userId = userProvider.userId;
                      if (userId == null) return;
                      await context.read<ActivityEventProvider>().logEvent(
                        userId: userId,
                        userName: userProvider.currentUser?.userName ?? 'User',
                        activityType: 'daily_check_in',
                        userProfilePicture:
                            userProvider.currentUser?.userProfilePicture,
                        description: 'Daily check-in',
                      );
                    },
                    child: const Text('Check In'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
