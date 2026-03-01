import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../mind_set/datasources/models/mind_set_session_model.dart';
import '../../../mind_set/datasources/services/mind_set_session_service.dart';
import '../pages/mind_set_sessions_details_page.dart';

class MindSetActivitySection extends StatefulWidget {
  const MindSetActivitySection({super.key});

  @override
  State<MindSetActivitySection> createState() => _MindSetActivitySectionState();
}

class _MindSetActivitySectionState extends State<MindSetActivitySection> {
  final MindSetSessionService _sessionService = MindSetSessionService();

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<UserProvider>().userId;
    if (userId == null) {
      return _shell(
        const Center(child: Text('Sign in to view Mind:Set analytics')),
      );
    }

    return StreamBuilder<List<MindSetSession>>(
      stream: _sessionService.streamUserSessions(userId),
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const <MindSetSession>[];
        final completed = sessions
            .where((s) => s.sessionStatus == 'completed')
            .toList();
        final analytics = _MindSetAnalytics.fromSessions(completed);

        return Card(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MindSetSessionsDetailsPage(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Mind:Set Sessions',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _pill(
                        '${analytics.completedSessions} completed',
                        Colors.deepPurple,
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    analytics.summaryText,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  _buildUsagePreview(analytics),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to view full session analytics and summaries',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _shell(Widget child) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(height: 120, child: child),
      ),
    );
  }

  Widget _buildUsagePreview(_MindSetAnalytics analytics) {
    final maxCount = [
      analytics.onTheSpotCount,
      analytics.goWithFlowCount,
      analytics.followThroughCount,
      1,
    ].reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bar(
          'On the Spot',
          analytics.onTheSpotCount,
          maxCount,
          const Color(0xFF2563EB),
        ),
        const SizedBox(height: 8),
        _bar(
          'Go with the Flow',
          analytics.goWithFlowCount,
          maxCount,
          const Color(0xFF059669),
        ),
        const SizedBox(height: 8),
        _bar(
          'Follow Through',
          analytics.followThroughCount,
          maxCount,
          const Color(0xFF7C3AED),
        ),
        const SizedBox(height: 8),
        Text(
          'Tasks completed in sessions: ${analytics.tasksDoneTotal}',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _bar(String label, int value, int max, Color color) {
    final ratio = max == 0 ? 0.0 : value / max;
    return Row(
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$value',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MindSetAnalytics {
  const _MindSetAnalytics({
    required this.completedSessions,
    required this.onTheSpotCount,
    required this.goWithFlowCount,
    required this.followThroughCount,
    required this.tasksDoneTotal,
    required this.summaryText,
  });

  final int completedSessions;
  final int onTheSpotCount;
  final int goWithFlowCount;
  final int followThroughCount;
  final int tasksDoneTotal;
  final String summaryText;

  static _MindSetAnalytics fromSessions(List<MindSetSession> sessions) {
    var onTheSpot = 0;
    var goWithFlow = 0;
    var followThrough = 0;
    var tasksDone = 0;

    for (final s in sessions) {
      switch (s.sessionType) {
        case 'on_the_spot':
          onTheSpot++;
          break;
        case 'go_with_flow':
          goWithFlow++;
          break;
        case 'follow_through':
          followThrough++;
          break;
      }
      tasksDone += s.sessionStats.tasksDoneCount ?? 0;
    }

    final bestType = () {
      final entries = {
        'On the Spot': onTheSpot,
        'Go with the Flow': goWithFlow,
        'Follow Through': followThrough,
      }.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      if (entries.isEmpty || entries.first.value == 0) {
        return 'No dominant mode yet';
      }
      return 'Most used: ${entries.first.key}';
    }();

    return _MindSetAnalytics(
      completedSessions: sessions.length,
      onTheSpotCount: onTheSpot,
      goWithFlowCount: goWithFlow,
      followThroughCount: followThrough,
      tasksDoneTotal: tasksDone,
      summaryText: '$bestType | $tasksDone tasks completed in sessions',
    );
  }
}
