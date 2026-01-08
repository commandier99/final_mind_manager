import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../../shared/features/users/datasources/providers/user_stats_provider.dart';
import '../../../../shared/features/users/datasources/providers/activity_event_provider.dart';
import '../../../../shared/features/users/datasources/models/user_stats_model.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../../boards/datasources/providers/board_join_request_provider.dart';
import '../widgets/stat_card_widget.dart';
import '../widgets/todays_overview_section.dart';
import '../widgets/user_stats_section.dart';
import '../widgets/activity_log_section.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();

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
            // Recent Activity Section
            const ActivityLogSection(),
            const SizedBox(height: 32),

            // Calendar Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calendar',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCalendar(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Today's Overview Section
            const TodaysOverviewSection(),
            const SizedBox(height: 24),
            
            // User Stats Section
            const UserStatsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    final daysInMonth =
        DateTime(_focusedDate.year, _focusedDate.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final startingWeekday = firstDayOfMonth.weekday % 7;

    return Column(
      children: [
        // Month/Year Header with navigation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                print('[DEBUG] DashboardPage: Previous month clicked - navigating from ${_focusedDate.month}/${_focusedDate.year}');
                setState(() {
                  _focusedDate = DateTime(
                    _focusedDate.year,
                    _focusedDate.month - 1,
                  );
                  print('[DEBUG] DashboardPage: Calendar now showing ${_focusedDate.month}/${_focusedDate.year}');
                });
              },
            ),
            Text(
              '${_getMonthName(_focusedDate.month)} ${_focusedDate.year}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                print('[DEBUG] DashboardPage: Next month clicked - navigating from ${_focusedDate.month}/${_focusedDate.year}');
                setState(() {
                  _focusedDate = DateTime(
                    _focusedDate.year,
                    _focusedDate.month + 1,
                  );
                  print('[DEBUG] DashboardPage: Calendar now showing ${_focusedDate.month}/${_focusedDate.year}');
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children:
              ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                  .map(
                    (day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 8),

        // Calendar grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: 42,
          itemBuilder: (context, index) {
            final dayNumber = index - startingWeekday + 1;

            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const SizedBox.shrink();
            }

            final date = DateTime(
              _focusedDate.year,
              _focusedDate.month,
              dayNumber,
            );
            final isSelected =
                _selectedDate.year == date.year &&
                _selectedDate.month == date.month &&
                _selectedDate.day == date.day;
            final isToday =
                DateTime.now().year == date.year &&
                DateTime.now().month == date.month &&
                DateTime.now().day == date.day;

            return GestureDetector(
              onTap: () {
                print('[DEBUG] DashboardPage: Date selected - ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
                setState(() {
                  _selectedDate = date;
                  print('[DEBUG] DashboardPage: Selection confirmed for ${_selectedDate.toString()}');
                });
              },
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? Colors.blue
                          : isToday
                          ? Colors.blue.withOpacity(0.2)
                          : null,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      isToday && !isSelected
                          ? Border.all(color: Colors.blue, width: 2)
                          : null,
                ),
                child: Center(
                  child: Text(
                    '$dayNumber',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _getMonthName(int month) {
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
