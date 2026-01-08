import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/features/users/datasources/models/activity_event_model.dart';
import '../../../../shared/features/users/datasources/providers/activity_event_provider.dart';
import 'activity_card.dart';

class ActivityLogSection extends StatefulWidget {
  const ActivityLogSection({super.key});

  @override
  State<ActivityLogSection> createState() => _ActivityLogSectionState();
}

class _ActivityLogSectionState extends State<ActivityLogSection> {
  bool _isExpanded = false;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    print('[DEBUG] RecentActivitySection: initState called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('[DEBUG] RecentActivitySection: Starting activity stream');
      // Stream will be started by the provider when needed
    });
  }

  @override
  void dispose() {
    print('[DEBUG] RecentActivitySection: dispose called');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityEventProvider>(
      builder: (context, activityProvider, _) {
        final activities = activityProvider.events;
        print(
          '[DEBUG] RecentActivitySection: Building with ${activities.length} activities',
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: InkWell(
                onTap: () {
                  print('[DEBUG] RecentActivitySection: Toggling expansion - was $_isExpanded');
                  setState(() {
                    _isExpanded = !_isExpanded;
                    print('[DEBUG] RecentActivitySection: Expansion toggled - now $_isExpanded');
                  });
                },
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Activity Log",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (activities.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${activities.length}',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Activity list
            if (_isExpanded)
              activities.isEmpty
                  ? _buildEmptyState()
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildActivityList(activities),
                    ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No recent activity',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Your activity will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityList(List<ActivityEvent> activities) {
    final displayCount =
        _showAll ? activities.length : (activities.length > 10 ? 10 : activities.length);
    final hasMore = activities.length > 10;

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayCount,
          separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
          itemBuilder: (context, index) {
            final activity = activities[index];
            return ActivityCard(activity: activity);
          },
        ),
        if (hasMore && !_showAll)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: () {
                print('[DEBUG] RecentActivitySection: "See more" clicked - showing all ${activities.length} activities');
                setState(() {
                  _showAll = true;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('See more'),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_downward, size: 16),
                ],
              ),
            ),
          ),
        if (_showAll && hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: () {
                print('[DEBUG] RecentActivitySection: "Show less" clicked - collapsing to 10 activities');
                setState(() {
                  _showAll = false;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Show less'),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_upward, size: 16),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
