import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/shared/features/users/datasources/providers/user_provider.dart';
import '/features/tasks/datasources/services/task_services.dart';
import '../../../datasources/models/mind_set_session_model.dart';
import '../../../datasources/services/mind_set_session_service.dart';
import '../mind_set_create_form.dart';

class MindSetSelectionView extends StatefulWidget {
  const MindSetSelectionView({super.key});

  @override
  State<MindSetSelectionView> createState() => _MindSetSelectionViewState();
}

class _MindSetSelectionViewState extends State<MindSetSelectionView> {
  final MindSetSessionService _sessionService = MindSetSessionService();
  final TaskService _taskService = TaskService();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 32),
        const Text(
          'What do you want to do?',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Divider(thickness: 1),
        const Spacer(),

        /// ON THE SPOT
        _buildOptionCard(
          icon: Icons.flash_on_rounded,
          iconColor: Colors.blue,
          title: 'On the Spot',
          subtitle: 'Create and complete tasks immediately.',
          onTap: () => _openCreateSession('on_the_spot'),
        ),

        const SizedBox(height: 16),

        /// GO WITH THE FLOW
        _buildOptionCard(
          icon: Icons.waves_rounded,
          iconColor: Colors.deepPurple,
          title: 'Go with the Flow',
          subtitle: 'Work on existing unplanned tasks.',
          onTap: () => _openCreateSession('go_with_flow'),
        ),

        const SizedBox(height: 16),

        /// FOLLOW THROUGH
        _buildOptionCard(
          icon: Icons.track_changes_rounded,
          iconColor: Colors.green,
          title: 'Follow Through',
          subtitle: 'Work on tasks from a selected plan.',
          onTap: () => _openCreateSession('follow_through'),
        ),

        const Spacer(),
      ],
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Icon(icon, size: 32, color: iconColor),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCreateSession(String sessionType) async {
    final messenger = ScaffoldMessenger.of(context);
    if (await _hasActiveSession()) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('End your current session first.')),
      );
      return;
    }
    if (!mounted) return;

    if (sessionType == 'go_with_flow') {
      final userId = context.read<UserProvider>().userId;
      if (userId == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('User not found. Please sign in again.'),
          ),
        );
        return;
      }

      final hasAssignedTasks = await _hasAssignedTasksToWorkOn(userId);
      if (!mounted) return;
      if (!hasAssignedTasks) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'No assigned tasks available for Go with the Flow.',
            ),
          ),
        );
        return;
      }
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
        if (!mounted) return;
        if (session != null && session.sessionStatus == 'created') {
          await _startSession(session);
        }
      }
    }
  }

  Future<bool> _hasActiveSession() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return false;
    final active = await _sessionService.streamActiveSession(userId).first;
    return active != null;
  }

  Future<bool> _hasAssignedTasksToWorkOn(String userId) async {
    final tasks = await _taskService.streamTasksAssignedTo(userId).first;
    return tasks.any((task) => !task.taskIsDone && !task.taskIsDeleted);
  }

  Future<void> _startSession(MindSetSession session) async {
    await _sessionService.startSession(session);
  }
}
