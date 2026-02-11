import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '/shared/features/users/datasources/providers/user_provider.dart';
import '/features/plans/datasources/services/plan_service.dart';
import '/features/tasks/datasources/services/task_services.dart';
import '../../../datasources/models/mind_set_session_model.dart';
import '../../../datasources/models/mind_set_session_stats_model.dart';
import '../../../datasources/services/mind_set_session_service.dart';
import '../mind_set_create_form.dart';

class MindSetSelectionView extends StatefulWidget {
  const MindSetSelectionView({super.key});

  @override
  State<MindSetSelectionView> createState() => _MindSetSelectionViewState();
}

class _MindSetSelectionViewState extends State<MindSetSelectionView> {
  final MindSetSessionService _sessionService = MindSetSessionService();
  final PlanService _planService = PlanService();
  final TaskService _taskService = TaskService();

  @override
  Widget build(BuildContext context) {
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
      if (!mounted) return;
      final userId = context.read<UserProvider>().userId;
      if (userId != null) {
        final session = await _sessionService.streamActiveSession(userId).first;
        if (session != null && session.sessionStatus == 'created') {
          await _startSession(session);
        }
      }
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
      sessionModeHistory: [
        MindSetModeChange(mode: 'Checklist', changedAt: DateTime.now()),
      ],
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
        pomodoroTargetCount: 4,
        pomodoroBreakMinutes: 5,
        pomodoroLongBreakMinutes: 60,
        pomodoroIsRunning: false,
        pomodoroIsOnBreak: false,
        pomodoroIsLongBreak: false,
        pomodoroMotivation: 'focused',
      ),
    );

    await _sessionService.addSession(session);
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

  Future<void> _startSession(MindSetSession session) async {
    await _sessionService.startSession(session);
  }
}
