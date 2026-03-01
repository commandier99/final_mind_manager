import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/features/users/datasources/models/activity_event_model.dart';
import '../../../../shared/features/users/datasources/providers/activity_event_provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';

class DailyCheckInStreakSection extends StatefulWidget {
  const DailyCheckInStreakSection({
    super.key,
    this.showMonthOverview = false,
    this.onTap,
  });

  final bool showMonthOverview;
  final VoidCallback? onTap;

  @override
  State<DailyCheckInStreakSection> createState() =>
      _DailyCheckInStreakSectionState();
}

class _DailyCheckInStreakSectionState extends State<DailyCheckInStreakSection> {
  @override
  Widget build(BuildContext context) {
    final activityProvider = context.watch<ActivityEventProvider>();
    final userProvider = context.watch<UserProvider>();
    final streak = _DailyCheckInStreak.fromEvents(activityProvider.events);
    final checkedInToday = streak.checkedInToday;

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: Colors.orange.shade700,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Daily Check-in',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (!checkedInToday)
                ElevatedButton.icon(
                  onPressed: () async {
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
                  icon: const Icon(Icons.check),
                  label: const Text('Check In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Checked In',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                '${streak.currentStreak}',
                'days',
                Colors.blue,
                Icons.trending_up,
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.grey.shade300,
              ),
              _buildStreakStat(
                'Longest Streak',
                '${streak.longestStreak}',
                'days',
                Colors.purple,
                Icons.emoji_events,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: checkedInToday ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: checkedInToday
                    ? Colors.green.shade200
                    : Colors.orange.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  checkedInToday ? Icons.check_circle : Icons.info_outline,
                  color: checkedInToday
                      ? Colors.green.shade700
                      : Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    checkedInToday
                        ? (streak.currentStreak == 1
                              ? 'Keep it up! Check in tomorrow to continue your streak.'
                              : 'You\'re on fire! ${streak.currentStreak} days of check-ins!')
                        : 'Start your streak today by checking in!',
                    style: TextStyle(
                      color: checkedInToday
                          ? Colors.green.shade900
                          : Colors.orange.shade900,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.showMonthOverview) ...[
            const SizedBox(height: 12),
            _buildMonthOverview(streak.checkInDays),
          ],
        ],
      ),
    );

    return Card(
      elevation: 2,
      clipBehavior: widget.onTap != null ? Clip.antiAlias : Clip.none,
      child: widget.onTap == null
          ? content
          : InkWell(
              onTap: widget.onTap,
              child: content,
            ),
    );
  }

  Widget _buildStreakStat(
    String label,
    String value,
    String unit,
    Color color,
    IconData icon,
  ) {
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
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthOverview(Set<DateTime> checkInDays) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final last = DateTime(now.year, now.month + 1, 0);
    final totalDays = last.day;
    final startWeekday = first.weekday;

    final cells = <Widget>[];
    for (var i = 1; i < startWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (var day = 1; day <= totalDays; day++) {
      final date = DateTime(now.year, now.month, day);
      final isChecked = checkInDays.contains(date);
      final isToday = DateUtils.isSameDay(date, now);

      cells.add(
        Container(
          decoration: BoxDecoration(
            color: isChecked ? Colors.green.shade100 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isToday ? Colors.blue : Colors.transparent,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isChecked ? Colors.green.shade800 : Colors.grey.shade700,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_monthName(now.month)} ${now.year} Overview',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            Row(
              children: [
                _legendDot(Colors.green.shade300),
                const SizedBox(width: 4),
                const Text('Checked in', style: TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.25,
          children: cells,
        ),
      ],
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}

class _DailyCheckInStreak {
  const _DailyCheckInStreak({
    required this.checkedInToday,
    required this.currentStreak,
    required this.longestStreak,
    required this.checkInDays,
  });

  final bool checkedInToday;
  final int currentStreak;
  final int longestStreak;
  final Set<DateTime> checkInDays;

  static _DailyCheckInStreak fromEvents(List<ActivityEvent> events) {
    final checkInDays = <DateTime>{};
    for (final event in events) {
      if (event.ActEvType == 'daily_check_in') {
        checkInDays.add(
          DateTime(
            event.ActEvTimestamp.year,
            event.ActEvTimestamp.month,
            event.ActEvTimestamp.day,
          ),
        );
      }
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final checkedInToday = checkInDays.contains(today);

    var currentStreak = 0;
    var probe = today;
    while (checkInDays.contains(probe)) {
      currentStreak++;
      probe = probe.subtract(const Duration(days: 1));
    }

    var longestStreak = 0;
    if (checkInDays.isNotEmpty) {
      final sorted = checkInDays.toList()..sort();
      var run = 1;
      longestStreak = 1;
      for (var i = 1; i < sorted.length; i++) {
        if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
          run++;
          if (run > longestStreak) longestStreak = run;
        } else {
          run = 1;
        }
      }
    }

    return _DailyCheckInStreak(
      checkedInToday: checkedInToday,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      checkInDays: checkInDays,
    );
  }
}
