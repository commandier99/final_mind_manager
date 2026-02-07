import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '/shared/features/users/datasources/providers/user_provider.dart';
import '/features/plans/datasources/models/plans_model.dart';
import '/features/plans/datasources/providers/plan_provider.dart';
import '../datasources/models/mind_set_session_model.dart';
import '../datasources/models/mind_set_session_stats_model.dart';
import '../datasources/services/mind_set_session_service.dart';

class MindSetCreatePage extends StatelessWidget {
  final String sessionType; // on_the_spot, go_with_flow, follow_through

  const MindSetCreatePage({
    super.key,
    required this.sessionType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Mind:Set'),
      ),
      body: MindSetCreateForm(sessionType: sessionType),
    );
  }
}

class MindSetCreateForm extends StatefulWidget {
  final String sessionType; // on_the_spot, go_with_flow, follow_through

  const MindSetCreateForm({
    super.key,
    required this.sessionType,
  });

  @override
  State<MindSetCreateForm> createState() => _MindSetCreateFormState();
}

class _MindSetCreateFormState extends State<MindSetCreateForm> {
  final _titleController = TextEditingController();
  final _goalController = TextEditingController();
  final _whyController = TextEditingController();
  final MindSetSessionService _sessionService = MindSetSessionService();

  String _selectedMode = 'Checklist';
  bool _isSaving = false;
  bool _hasCreatedSession = false;
  String? _createdSessionId;
  DateTime? _createdSessionAt;
  String? _selectedPlanId;
  Plan? _selectedPlan;

  @override
  void dispose() {
    _titleController.dispose();
    _goalController.dispose();
    _whyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionLabel = _getSessionLabel(widget.sessionType);
    final sessionPurpose = _getSessionPurpose(widget.sessionType);
    final isGoWithFlow = widget.sessionType == 'go_with_flow';
    final isFollowThrough = widget.sessionType == 'follow_through';
    final isOnTheSpot = widget.sessionType == 'on_the_spot';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Text(
              sessionLabel,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              sessionPurpose,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (isFollowThrough) ...[
              _buildPlanSelector(context),
              const SizedBox(height: 12),
            ],
            if (!isGoWithFlow && !isFollowThrough) ...[
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Session Title',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  hintText: 'Ex. Study for Exam',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _goalController,
                decoration: InputDecoration(
                  labelText: 'Goal',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  hintText:
                      'Ex. Refresh knowledge on core object-oriented programming concepts',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _whyController,
                decoration: InputDecoration(
                  labelText: 'Benefit',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  hintText:
                      'Write how finishing this session helps you stay motivated',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
            ],
            if (!isFollowThrough) ...[
              DropdownButtonFormField<String>(
                value: _selectedMode,
                decoration: InputDecoration(
                  labelText: 'Mode (can be changed later)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Checklist',
                    child: Text('Checklist'),
                  ),
                  DropdownMenuItem(
                    value: 'Pomodoro',
                    child: Text('Pomodoro'),
                  ),
                  DropdownMenuItem(
                    value: 'Eat the Frog',
                    child: Text('Eat the Frog'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedMode = value ?? 'Checklist';
                  });
                },
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving || (isFollowThrough && _selectedPlan == null)
                    ? null
                    : _createSession,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Creating...' : 'Create Session'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _hasCreatedSession &&
                        (!isFollowThrough || _selectedPlan != null)
                    ? _startSession
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Session'),
              ),
            ),
          ],
        ),
      ),
    );
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

  String _getSessionPurpose(String sessionType) {
    switch (sessionType) {
      case 'on_the_spot':
        return 'Create and complete tasks immediately.';
      case 'go_with_flow':
        return 'Work on existing unplanned tasks.';
      case 'follow_through':
        return 'Work on tasks from a selected plan.';
      default:
        return '';
    }
  }

  Widget _buildPlanSelector(BuildContext context) {
    final userId = context.watch<UserProvider>().userId;
    if (userId == null) {
      return const Text('Sign in to select a plan.');
    }

    return Consumer<PlanProvider>(
      builder: (context, planProvider, _) {
        return StreamBuilder<List<Plan>>(
          stream: planProvider.streamUserPlans(userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text('Error loading plans: ${snapshot.error}');
            }

            final plans = snapshot.data ?? [];
            if (plans.isEmpty) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('No plans yet. Create a plan in '),
                  Icon(Icons.event_note, size: 18),
                ],
              );
            }

            final selectedPlan = _selectedPlanId == null
                ? null
                : plans.firstWhere(
                    (plan) => plan.planId == _selectedPlanId,
                    orElse: () => plans.first,
                  );

            if (_selectedPlanId != null && selectedPlan != null) {
              _selectedPlan = selectedPlan;
            }

            return DropdownButtonFormField<String>(
              value: selectedPlan?.planId,
              decoration: InputDecoration(
                labelText: 'Select a plan',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: plans
                  .map(
                    (plan) => DropdownMenuItem(
                      value: plan.planId,
                      child: Text(plan.planTitle),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                final plan = plans.firstWhere(
                  (plan) => plan.planId == value,
                );
                setState(() {
                  _selectedPlanId = value;
                  _selectedPlan = plan;
                  _applyPlanToFields(plan);
                });
              },
            );
          },
        );
      },
    );
  }

  void _applyPlanToFields(Plan plan) {
    _titleController.text = plan.planTitle;
    _goalController.text = plan.planDescription;
    _whyController.text = plan.planBenefit;
    _selectedMode = _mapPlanStyleToMode(plan.planStyle);
  }

  String _mapPlanStyleToMode(String style) {
    switch (style) {
      case 'pomodoro':
      case 'Pomodoro':
        return 'Pomodoro';
      case 'eat_the_frog':
      case 'Eat the Frog':
        return 'Eat the Frog';
      case 'quick_todo':
      case 'Checklist':
        return 'Checklist';
      default:
        return _selectedMode;
    }
  }

  Future<void> _createSession() async {
    final isGoWithFlow = widget.sessionType == 'go_with_flow';
    final isFollowThrough = widget.sessionType == 'follow_through';
    final isOnTheSpot = widget.sessionType == 'on_the_spot';
    const flowSessionTitle = 'Flow';
    const flowSessionGoal = 'Do What I Can';
    const flowSessionBenefit = 'Make Progress In Any Way';

    if (isFollowThrough && _selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a plan')),
      );
      return;
    }

    if (!isGoWithFlow && !isFollowThrough) {
      if (_titleController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a session title')),
        );
        return;
      }

      if (_goalController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a goal')),
        );
        return;
      }

      if (_whyController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a reason (why)')),
        );
        return;
      }
    }

    final followThroughPlan = _selectedPlan;

    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found. Please sign in again.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final sessionId = const Uuid().v4();
    final session = MindSetSession(
      sessionId: sessionId,
      sessionUserId: userId,
      sessionType: widget.sessionType,
      sessionMode: _selectedMode,
      sessionTitle: isGoWithFlow
          ? flowSessionTitle
          : isFollowThrough
              ? (followThroughPlan?.planTitle ?? _titleController.text.trim())
              : _titleController.text.trim(),
      sessionPurpose: isGoWithFlow
          ? flowSessionGoal
          : isFollowThrough
              ? (followThroughPlan?.planDescription ?? _goalController.text.trim())
              : _goalController.text.trim(),
      sessionWhy: isGoWithFlow
          ? flowSessionBenefit
          : isFollowThrough
              ? (followThroughPlan?.planBenefit ?? _whyController.text.trim())
              : _whyController.text.trim(),
        sessionStatus: 'created',
      sessionCreatedAt: DateTime.now(),
        sessionStartedAt: null,
      sessionTaskIds: isFollowThrough
          ? (followThroughPlan?.taskIds ?? const [])
          : const [],
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

    if (isOnTheSpot) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _isSaving = false;
      _hasCreatedSession = true;
      _createdSessionId = sessionId;
      _createdSessionAt = session.sessionCreatedAt;
    });
  }

  Future<void> _startSession() async {
    if (_createdSessionId == null || _createdSessionAt == null) return;
    final isGoWithFlow = widget.sessionType == 'go_with_flow';
    final isFollowThrough = widget.sessionType == 'follow_through';
    const flowSessionTitle = 'Flow Session';
    const flowSessionGoal = 'Do What I Can';
    const flowSessionBenefit = 'Make Progress In Any Way';

    final followThroughPlan = _selectedPlan;

    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found. Please sign in again.')),
      );
      return;
    }

    await _sessionService.startSession(
      MindSetSession(
        sessionId: _createdSessionId!,
        sessionUserId: userId,
        sessionType: widget.sessionType,
        sessionMode: _selectedMode,
        sessionTitle: isGoWithFlow
            ? flowSessionTitle
            : isFollowThrough
                ? (followThroughPlan?.planTitle ?? _titleController.text.trim())
                : _titleController.text.trim(),
        sessionPurpose: isGoWithFlow
            ? flowSessionGoal
            : isFollowThrough
                ? (followThroughPlan?.planDescription ?? _goalController.text.trim())
                : _goalController.text.trim(),
        sessionWhy: isGoWithFlow
            ? flowSessionBenefit
            : isFollowThrough
                ? (followThroughPlan?.planBenefit ?? _whyController.text.trim())
                : _whyController.text.trim(),
        sessionStatus: 'active',
        sessionCreatedAt: _createdSessionAt!,
        sessionStartedAt: DateTime.now(),
        sessionTaskIds: isFollowThrough
            ? (followThroughPlan?.taskIds ?? const [])
            : const [],
        sessionStats: const MindSetSessionStats(
          tasksTotalCount: 0,
          tasksDoneCount: 0,
          sessionFocusDurationMinutes: 0,
          sessionFocusDurationSeconds: 0,
          pomodoroCount: 0,
        ),
      ),
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }
}
