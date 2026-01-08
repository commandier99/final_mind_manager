import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/shared/features/users/datasources/providers/user_provider.dart';
import '../../datasources/models/plans_model.dart';
import '../../datasources/providers/plan_provider.dart';
import '../widgets/cards/plan_card.dart';
import 'create_plan_page.dart';

class PlansPage extends StatefulWidget {
  const PlansPage({super.key});

  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  String? _userId;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<UserProvider>().userId;
    if (userId != null && !_initialized) {
      _userId = userId;
      _initialized = true;
      Provider.of<PlanProvider>(context, listen: false).loadUserPlans(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final template = await _showTemplateDialog(context);
          if (template == null) return;

          final createdPlan = await Navigator.push<Plan?>(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePlanPage(initialTechnique: template),
            ),
          );

          if (createdPlan != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Plan "${createdPlan.planTitle}" has been made successfully!',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Plan'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _userId == null
            ? const Center(child: CircularProgressIndicator())
            : Consumer<PlanProvider>(
                builder: (context, planProvider, _) {
                  final plans = planProvider.userPlans;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      const SizedBox(height: 16),

                      Expanded(
                        child: planProvider.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : plans.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 32),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
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
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    itemCount: plans.length,
                                    itemBuilder: (context, index) {
                                      final plan = plans[index];
                                      return PlanCard(
                                        plan: plan,
                                        onActivate: () async {
                                          final success = await context
                                              .read<PlanProvider>()
                                              .activatePlan(plan.planId);
                                          if (success && context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Plan "${plan.planTitle}" activated!'),
                                                duration: const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        },
                                        onTap: () {
                                          _showPlanDetailsDialog(context, plan);
                                        },
                                      );
                                    },
                                  ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Future<String?> _showTemplateDialog(BuildContext context) {
    final templates = [
      (
        'custom',
        'Custom',
        'Pick any tasks and structure the plan however you like.',
      ),
      (
        'gtd',
        'Get Things Done',
        'Capture tasks, clarify what they are, and order them to execute.',
      ),
      (
        'pomodoro',
        'Pomodoro',
        'Work in focused intervals with short breaks to finish your tasks.',
      ),
      (
        'eat_the_frog',
        'Eat the Frog',
        'Identify the hardest tasks and tackle them first.',
      ),
      (
        'timeblocking',
        'Time Blocking',
        'Lay tasks on a timeline to decide when you will do each one.',
      ),
    ];

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose a template'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (value, title, desc) in templates)
                  ListTile(
                    title: Text(title),
                    subtitle: Text(desc),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, value),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showPlanDetailsDialog(BuildContext context, Plan plan) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(plan.planTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(plan.planDescription),
                const SizedBox(height: 16),
                Text(
                  'Status',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(plan.planStatus).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    plan.planStatus.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(plan.planStatus),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Technique: ${plan.planTechnique}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tasks: ${plan.completedTasks}/${plan.totalTasks}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Focus Sessions: ${plan.actualFocusSessionsCompleted}/${plan.plannedFocusIntervals}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (plan.planStatus == 'draft')
              ElevatedButton.icon(
                onPressed: () async {
                  final success =
                      await context.read<PlanProvider>().activatePlan(plan.planId);
                  if (context.mounted) {
                    Navigator.pop(context);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Plan "${plan.planTitle}" activated!'),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.play_circle, size: 18),
                label: const Text('Activate'),
              ),
            if (plan.planStatus != 'completed')
              ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Plan'),
                      content: const Text('Are you sure you want to delete this plan?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    await context.read<PlanProvider>().deletePlan(plan.planId);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Plan deleted')),
                    );
                  }
                },
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Delete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                ),
              ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return Colors.grey;
      case 'active':
        return Colors.blue;
      case 'paused':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
