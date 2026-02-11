import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '/shared/features/users/datasources/providers/user_provider.dart';
import '/features/plans/datasources/models/plans_model.dart';
import '/features/plans/datasources/providers/plan_provider.dart';
import '/features/plans/presentation/widgets/cards/plan_card.dart';
import '../../datasources/models/mind_set_session_model.dart';
import '../../datasources/models/mind_set_session_stats_model.dart';
import '../../datasources/services/mind_set_session_service.dart';

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
  String? _selectedPlanId;
  Plan? _selectedPlan;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onFieldChanged);
    _goalController.addListener(_onFieldChanged);
    _whyController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFieldChanged);
    _goalController.removeListener(_onFieldChanged);
    _whyController.removeListener(_onFieldChanged);
    _titleController.dispose();
    _goalController.dispose();
    _whyController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _isGoWithFlow => widget.sessionType == 'go_with_flow';
  bool get _isFollowThrough => widget.sessionType == 'follow_through';
  bool get _isOnTheSpot => widget.sessionType == 'on_the_spot';

  bool get _areOnTheSpotFieldsFilled {
    return _titleController.text.trim().isNotEmpty &&
        _goalController.text.trim().isNotEmpty &&
        _whyController.text.trim().isNotEmpty;
  }

  bool get _isCreateEnabled {
    if (_isSaving) return false;
    if (_isFollowThrough) return _selectedPlan != null;
    if (_isOnTheSpot) return _areOnTheSpotFieldsFilled;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final sessionLabel = _getSessionLabel(widget.sessionType);
    final sessionPurpose = _getSessionPurpose(widget.sessionType);

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: bottomInset),
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
            if (_isFollowThrough) ...[
              _buildPlanSelector(context),
              const SizedBox(height: 12),
            ],
            if (!_isGoWithFlow && !_isFollowThrough) ...[
              TextField(
                controller: _titleController,
                maxLength: 60,
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
                maxLength: 200,
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
                maxLength: 200,
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
              if (_isOnTheSpot) ...[
                const SizedBox(height: 8),
                Text(
                  'All fields are required to create an On the Spot session.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
            if (!_isFollowThrough) ...[
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
                onPressed: _isCreateEnabled ? _createSession : null,
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
          ],
        ),
      ),
    ));
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
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_note,
                      size: 56,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No plans yet',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Create a plan to use Follow Through mode',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a plan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: plans.length,
                    itemBuilder: (context, index) {
                      final plan = plans[index];
                      final isSelected = _selectedPlanId == plan.planId;
                      
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPlanId = plan.planId;
                            _selectedPlan = plan;
                            _applyPlanToFields(plan);
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected 
                                  ? Theme.of(context).primaryColor
                                  : Colors.transparent,
                              width: isSelected ? 3 : 0,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isSelected 
                                ? [
                                    BoxShadow(
                                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Stack(
                            children: [
                              AbsorbPointer(
                                child: PlanCard(plan: plan),
                              ),
                              if (isSelected)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
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
    const flowSessionTitle = 'Flow';
    const flowSessionGoal = 'Do What I Can';
    const flowSessionBenefit = 'Make Progress In Any Way';

    if (_isFollowThrough && _selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a plan')),
      );
      return;
    }

    if (!_isGoWithFlow && !_isFollowThrough) {
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
      sessionModeHistory: [
        MindSetModeChange(mode: _selectedMode, changedAt: DateTime.now()),
      ],
      sessionTitle: _isGoWithFlow
          ? flowSessionTitle
          : _isFollowThrough
              ? (followThroughPlan?.planTitle ?? _titleController.text.trim())
              : _titleController.text.trim(),
      sessionPurpose: _isGoWithFlow
          ? flowSessionGoal
          : _isFollowThrough
              ? (followThroughPlan?.planDescription ??
                  _goalController.text.trim())
              : _goalController.text.trim(),
      sessionWhy: _isGoWithFlow
          ? flowSessionBenefit
          : _isFollowThrough
              ? (followThroughPlan?.planBenefit ?? _whyController.text.trim())
              : _whyController.text.trim(),
        sessionStatus: 'active',
      sessionCreatedAt: DateTime.now(),
        sessionStartedAt: DateTime.now(),
      sessionTaskIds:
          _isFollowThrough ? (followThroughPlan?.taskIds ?? const []) : const [],
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

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });
    Navigator.pop(context, true);
  }
}
