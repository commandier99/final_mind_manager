import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '/shared/features/users/datasources/providers/user_provider.dart';
import '/features/plans/datasources/services/plan_service.dart';
import '/features/tasks/datasources/services/task_services.dart';
import '../datasources/models/mind_set_session_model.dart';
import '../datasources/models/mind_set_session_stats_model.dart';
import '../datasources/services/mind_set_session_service.dart';
import '../widgets/mind_set_details.dart';
import '../widgets/on_the_spot_section.dart';
import '../widgets/follow_through_task_stream.dart';
import '../widgets/go_with_flow_task_stream.dart';
import 'mind_set_create_page.dart';

class MindSetPage extends StatefulWidget {
  const MindSetPage({super.key});

  @override
  State<MindSetPage> createState() => _MindSetPageState();
}

class _MindSetPageState extends State<MindSetPage> {
  final MindSetSessionService _sessionService = MindSetSessionService();
  final PlanService _planService = PlanService();
  final TaskService _taskService = TaskService();

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<UserProvider>().userId;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('Mind:Set'),
        centerTitle: true,
      ),
      body: userId == null
          ? _buildMindsetSelectSection()
          : StreamBuilder<MindSetSession?>(
              stream: _sessionService.streamActiveSession(userId),
              builder: (context, snapshot) {
                final activeSession = snapshot.data;
                if (activeSession != null) {
                  return _buildActiveSessionView(activeSession);
                }
                return _buildMindsetSelectSection();
              },
            ),
    );
  }

  Widget _buildMindsetSelectSection() {
    return Column(
      children: [
        const SizedBox(height: 32),
        const Text(
          'What do you want to do?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Divider(thickness: 1),
        const Spacer(),
        
        // On the Spot Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openCreateSession('on_the_spot'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Column(
                children: const [
                  Text(
                    'On the Spot',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create and complete tasks immediately.',
                    style: TextStyle(
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Go with the Flow Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _handleGoWithFlowSelection(),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Column(
                children: const [
                  Text(
                    'Go with the Flow',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Work on existing unplanned tasks.',
                    style: TextStyle(
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Follow Through Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _openCreateSession('follow_through'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Column(
                children: const [
                  Text(
                    'Follow Through',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Work on tasks from a selected plan.',
                    style: TextStyle(
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Future<void> _openCreateSession(String sessionType) async {
    if (await _hasActiveSession()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End your current session first.')),
      );
      return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (context) => MindSetCreateForm(sessionType: sessionType),
    );

    if (created == true) {
      setState(() {});
    }
  }

  Future<void> _handleGoWithFlowSelection() async {
    if (await _hasActiveSession()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End your current session first.')),
      );
      return;
    }

    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found. Please sign in again.')),
      );
      return;
    }

    final hasUnplanned = await _hasUnplannedTasks(userId);
    if (!hasUnplanned) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unplanned tasks to work on.')),
      );
      return;
    }

    final sessionId = const Uuid().v4();
    final session = MindSetSession(
      sessionId: sessionId,
      sessionUserId: userId,
      sessionType: 'go_with_flow',
      sessionMode: 'Checklist',
      sessionTitle: 'Flow Session',
      sessionPurpose: 'Do What I Can',
      sessionWhy: 'Make Progress In Any Way',
      sessionStatus: 'active',
      sessionCreatedAt: DateTime.now(),
      sessionStartedAt: DateTime.now(),
      sessionStats: const MindSetSessionStats(
        tasksTotalCount: 0,
        tasksDoneCount: 0,
        sessionFocusDurationMinutes: 0,
        sessionFocusDurationSeconds: 0,
        pomodoroCount: 0,
      ),
    );

    await _sessionService.addSession(session);

    if (!mounted) return;
    setState(() {});
  }

  Future<bool> _hasActiveSession() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return false;
    final active = await _sessionService.streamActiveSession(userId).first;
    return active != null;
  }

  Future<bool> _hasUnplannedTasks(String userId) async {
    final tasks = await _taskService.streamTasks(ownerId: userId).first;
    final activeTasks = tasks
        .where((task) => !task.taskIsDone && !task.taskIsDeleted)
        .toList();
    if (activeTasks.isEmpty) return false;

    final plans = await _planService.getUserPlans(userId);
    final plannedTaskIds = <String>{};
    for (final plan in plans) {
      plannedTaskIds.addAll(plan.taskIds);
    }

    return activeTasks.any((task) => !plannedTaskIds.contains(task.taskId));
  }

  Widget _buildActiveSessionView(MindSetSession session) {
    return Column(
      children: [
        MindSetDetails(
          title: session.sessionTitle,
          description: session.sessionPurpose,
          labelText: _getSessionLabel(session.sessionType),
          selectedMode: session.sessionMode,
          onModeChanged: (value) => _updateSessionMode(session, value),
          timerElapsed: _sessionElapsed(session),
          onTimerPersist: (duration) => _updateSessionTimer(session, duration),
          isTimerEnabled: session.sessionStatus == 'active',
        ),
        Expanded(child: _buildSessionBody(session)),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (session.sessionStatus == 'created')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmCancelSession(session.sessionId),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel Session'),
                  ),
                ),
              if (session.sessionStatus == 'created')
                const SizedBox(width: 12),
              if (session.sessionStatus == 'created')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _startSession(session),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Start Session'),
                  ),
                ),
              if (session.sessionStatus == 'active')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmEndSession(session.sessionId),
                    icon: const Icon(Icons.stop_circle),
                    label: const Text('End Session'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionBody(MindSetSession session) {
    switch (session.sessionType) {
      case 'on_the_spot':
        return OnTheSpotSection(
          onCancelSet: () => _confirmEndSession(session.sessionId),
          isSessionActive: session.sessionStatus == 'active',
        );
      case 'go_with_flow':
        return GoWithFlowTaskStream(
          userId: session.sessionUserId,
          mode: session.sessionMode,
        );
      case 'follow_through':
        return FollowThroughTaskStream(
          taskIds: session.sessionTaskIds,
          mode: session.sessionMode,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _updateSessionMode(
    MindSetSession session,
    String newMode,
  ) async {
    await _sessionService.updateSession(
      session.copyWith(sessionMode: newMode),
    );
  }

  Duration _sessionElapsed(MindSetSession session) {
    final minutes = session.sessionStats.sessionFocusDurationMinutes ?? 0;
    final seconds = session.sessionStats.sessionFocusDurationSeconds ?? 0;
    return Duration(minutes: minutes, seconds: seconds);
  }

  Future<void> _updateSessionTimer(
    MindSetSession session,
    Duration duration,
  ) async {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    await _sessionService.updateSession(
      session.copyWith(
        sessionStats: session.sessionStats.copyWith(
          sessionFocusDurationMinutes: minutes,
          sessionFocusDurationSeconds: seconds,
        ),
      ),
    );
  }

  Future<void> _startSession(MindSetSession session) async {
    await _sessionService.startSession(session);
  }

  Future<void> _endSession(String sessionId) async {
    await _sessionService.endSession(sessionId, DateTime.now());
  }

  Future<void> _cancelSession(String sessionId) async {
    await _sessionService.cancelSession(sessionId);
  }

  Future<void> _confirmEndSession(String sessionId) async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this session?'),
        content: const Text(
          'You will return to the Mind:Set selection. You can review this session later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (shouldEnd != true) return;
    await _endSession(sessionId);
  }

  Future<void> _confirmCancelSession(String sessionId) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this session?'),
        content: const Text(
          'This will discard the current session and return to Mind:Set selection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Session'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Session'),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;
    await _cancelSession(sessionId);
  }

  String _getSessionLabel(String sessionType) {
    switch (sessionType) {
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
