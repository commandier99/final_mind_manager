import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/features/users/datasources/models/activity_event_model.dart';
import '../../../../shared/features/users/datasources/providers/activity_event_provider.dart';
import 'activity_card.dart';

class MindSetActivitySection extends StatefulWidget {
  const MindSetActivitySection({super.key});

  @override
  State<MindSetActivitySection> createState() => _MindSetActivitySectionState();
}

class _MindSetActivitySectionState extends State<MindSetActivitySection> {
  bool _showAll = false;

  List<ActivityEvent> _filterMindSetEvents(List<ActivityEvent> events) {
    return events.where((event) {
      final type = event.ActEvType?.toLowerCase();
      return type == 'mindset_session_created' ||
          type == 'mindset_session_started' ||
          type == 'mindset_session_completed' ||
          type == 'mindset_session_cancelled';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityEventProvider>(
      builder: (context, activityProvider, _) {
        final sessionEvents = _filterMindSetEvents(activityProvider.events);
        final displayCount = _showAll
            ? sessionEvents.length
            : (sessionEvents.length > 5 ? 5 : sessionEvents.length);
        final hasMore = sessionEvents.length > 5;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Mind:Set Sessions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (sessionEvents.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${sessionEvents.length}',
                          style: TextStyle(
                            color: Colors.deepPurple.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (sessionEvents.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.psychology,
                            size: 40,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No Mind:Set sessions yet',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayCount,
                    separatorBuilder: (context, index) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final activity = sessionEvents[index];
                      return ActivityCard(activity: activity);
                    },
                  ),
                if (hasMore)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _showAll = !_showAll;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_showAll ? 'Show less' : 'See more'),
                          const SizedBox(width: 4),
                          Icon(
                            _showAll
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
