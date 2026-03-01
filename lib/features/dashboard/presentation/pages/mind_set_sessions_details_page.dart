import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../mind_set/datasources/models/mind_set_session_model.dart';
import '../../../mind_set/datasources/services/mind_set_session_service.dart';

class MindSetSessionsDetailsPage extends StatelessWidget {
  const MindSetSessionsDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<UserProvider>().userId;
    if (userId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mind:Set Sessions')),
        body: const Center(child: Text('Sign in to view Mind:Set analytics')),
      );
    }

    final service = MindSetSessionService();
    return Scaffold(
      appBar: AppBar(title: const Text('Mind:Set Sessions')),
      body: StreamBuilder<List<MindSetSession>>(
        stream: service.streamUserSessions(userId),
        builder: (context, snapshot) {
          final sessions = snapshot.data ?? const <MindSetSession>[];
          final completed = sessions
              .where((s) => s.sessionStatus == 'completed')
              .toList();
          final analytics = _MindSetAnalytics.fromSessions(completed);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _overviewTile(
                      label: 'Completed',
                      value: '${analytics.completedSessions}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _overviewTile(
                      label: 'Tasks Done',
                      value: '${analytics.tasksDoneTotal}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _overviewTile(
                      label: 'Avg Focus',
                      value: '${analytics.averageFocusMinutes}m',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Session Type Usage',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    _bar(
                      'On the Spot',
                      analytics.onTheSpotCount,
                      analytics.maxTypeCount,
                      const Color(0xFF2563EB),
                    ),
                    const SizedBox(height: 8),
                    _bar(
                      'Go with the Flow',
                      analytics.goWithFlowCount,
                      analytics.maxTypeCount,
                      const Color(0xFF059669),
                    ),
                    const SizedBox(height: 8),
                    _bar(
                      'Follow Through',
                      analytics.followThroughCount,
                      analytics.maxTypeCount,
                      const Color(0xFF7C3AED),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mode Effectiveness',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    _effectivenessRow(
                      'On the Spot',
                      analytics.onTheSpotCount,
                      analytics.onTheSpotTasksDone,
                    ),
                    _effectivenessRow(
                      'Go with the Flow',
                      analytics.goWithFlowCount,
                      analytics.goWithFlowTasksDone,
                    ),
                    _effectivenessRow(
                      'Follow Through',
                      analytics.followThroughCount,
                      analytics.followThroughTasksDone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Session Summaries',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    if (completed.isEmpty)
                      Text(
                        'No completed sessions yet.',
                        style: TextStyle(color: Colors.grey.shade600),
                      )
                    else
                      ...(_sortedRecent(completed).take(12).map(_sessionTile)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<MindSetSession> _sortedRecent(List<MindSetSession> sessions) {
    final recent = [...sessions];
    recent.sort((a, b) => b.sessionCreatedAt.compareTo(a.sessionCreatedAt));
    return recent;
  }

  Widget _sessionTile(MindSetSession s) {
    final done = s.sessionStats.tasksDoneCount ?? 0;
    final total = s.sessionStats.tasksTotalCount ?? 0;
    final minutes = s.sessionStats.sessionFocusDurationMinutes ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.sessionTitle.isNotEmpty
                      ? s.sessionTitle
                      : _labelForType(s.sessionType),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _labelForType(s.sessionType),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '$done/$total tasks',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          Text('${minutes}m', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _overviewTile({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _bar(String label, int value, int max, Color color) {
    final ratio = max <= 0 ? 0.0 : value / max;
    return Row(
      children: [
        SizedBox(
          width: 112,
          child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
        Text('$value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _effectivenessRow(String label, int sessions, int tasksDone) {
    final avg = sessions == 0 ? 0.0 : tasksDone / sessions;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$tasksDone tasks in $sessions sessions',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(width: 10),
          Text(
            '${avg.toStringAsFixed(1)} avg',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  String _labelForType(String type) {
    switch (type) {
      case 'on_the_spot':
        return 'On the Spot';
      case 'go_with_flow':
        return 'Go with the Flow';
      case 'follow_through':
        return 'Follow Through';
      default:
        return 'Mind:Set';
    }
  }
}

class _MindSetAnalytics {
  const _MindSetAnalytics({
    required this.completedSessions,
    required this.onTheSpotCount,
    required this.goWithFlowCount,
    required this.followThroughCount,
    required this.tasksDoneTotal,
    required this.averageFocusMinutes,
    required this.onTheSpotTasksDone,
    required this.goWithFlowTasksDone,
    required this.followThroughTasksDone,
  });

  final int completedSessions;
  final int onTheSpotCount;
  final int goWithFlowCount;
  final int followThroughCount;
  final int tasksDoneTotal;
  final int averageFocusMinutes;
  final int onTheSpotTasksDone;
  final int goWithFlowTasksDone;
  final int followThroughTasksDone;

  int get maxTypeCount {
    final maxCount = [onTheSpotCount, goWithFlowCount, followThroughCount].fold(
      0,
      (prev, next) => prev > next ? prev : next,
    );
    return maxCount == 0 ? 1 : maxCount;
  }

  static _MindSetAnalytics fromSessions(List<MindSetSession> sessions) {
    var onTheSpot = 0;
    var goWithFlow = 0;
    var followThrough = 0;
    var tasksDone = 0;
    var totalFocusMinutes = 0;
    var onTheSpotTasks = 0;
    var goWithFlowTasks = 0;
    var followThroughTasks = 0;

    for (final s in sessions) {
      final done = s.sessionStats.tasksDoneCount ?? 0;
      final focus = s.sessionStats.sessionFocusDurationMinutes ?? 0;
      tasksDone += done;
      totalFocusMinutes += focus;
      switch (s.sessionType) {
        case 'on_the_spot':
          onTheSpot++;
          onTheSpotTasks += done;
          break;
        case 'go_with_flow':
          goWithFlow++;
          goWithFlowTasks += done;
          break;
        case 'follow_through':
          followThrough++;
          followThroughTasks += done;
          break;
      }
    }

    final avgFocus = sessions.isEmpty
        ? 0
        : (totalFocusMinutes / sessions.length).round();

    return _MindSetAnalytics(
      completedSessions: sessions.length,
      onTheSpotCount: onTheSpot,
      goWithFlowCount: goWithFlow,
      followThroughCount: followThrough,
      tasksDoneTotal: tasksDone,
      averageFocusMinutes: avgFocus,
      onTheSpotTasksDone: onTheSpotTasks,
      goWithFlowTasksDone: goWithFlowTasks,
      followThroughTasksDone: followThroughTasks,
    );
  }
}
