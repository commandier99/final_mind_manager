import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../plans/datasources/models/plans_model.dart';
import '../../../plans/datasources/providers/plan_provider.dart';
import '../../../plans/presentation/widgets/cards/plan_card.dart';

class PlansSection extends StatefulWidget {
  const PlansSection({super.key});

  @override
  State<PlansSection> createState() => _PlansSectionState();
}

class _PlansSectionState extends State<PlansSection> {
  String _selectedTab = 'all'; // 'all', 'active', 'draft', 'completed'

  List<Plan> _filterPlans(List<Plan> plans) {
    switch (_selectedTab) {
      case 'active':
        return plans.where((p) => p.planStatus == 'active').toList();
      case 'draft':
        return plans.where((p) => p.planStatus == 'draft').toList();
      case 'completed':
        return plans.where((p) => p.planStatus == 'completed').toList();
      default: // 'all'
        return plans;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlanProvider>(
      builder: (context, planProvider, _) {
        final userId = context.read<UserProvider>().userId;
        final filteredPlans = _filterPlans(planProvider.userPlans);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and create button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Plans',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _showCreatePlanDialog(context);
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Plan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Filter tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterTab('All', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterTab('Active', 'active'),
                  const SizedBox(width: 8),
                  _buildFilterTab('Draft', 'draft'),
                  const SizedBox(width: 8),
                  _buildFilterTab('Completed', 'completed'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Plans list or empty state
            if (filteredPlans.isEmpty)
              Center(
                child: Padding(
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
                        _getEmptyStateMessage(),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredPlans.length,
                itemBuilder: (context, index) {
                  final plan = filteredPlans[index];
                  return PlanCard(
                    plan: plan,
                    onActivate: () async {
                      final success =
                          await context.read<PlanProvider>().activatePlan(plan.planId);
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
          ],
        );
      },
    );
  }

  Widget _buildFilterTab(String label, String tabId) {
    final isSelected = _selectedTab == tabId;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedTab = tabId;
        });
      },
      backgroundColor: Colors.transparent,
      selectedColor: Colors.blue.shade100,
      side: BorderSide(
        color: isSelected ? Colors.blue.shade500 : Colors.grey.shade300,
        width: isSelected ? 2 : 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue.shade700 : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  String _getEmptyStateMessage() {
    switch (_selectedTab) {
      case 'active':
        return 'No active plans';
      case 'draft':
        return 'No draft plans';
      case 'completed':
        return 'No completed plans';
      default:
        return 'No plans yet';
    }
  }

  void _showCreatePlanDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedTechnique = 'custom';
    DateTime? scheduledDate;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Plan Title',
                    hintText: 'e.g., Monday Study Session',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'What is this plan for?',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedTechnique,
                  decoration: InputDecoration(
                    labelText: 'Technique',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'custom',
                      child: Text('Custom'),
                    ),
                    DropdownMenuItem(
                      value: 'pomodoro',
                      child: Text('Pomodoro'),
                    ),
                    DropdownMenuItem(
                      value: 'timeblocking',
                      child: Text('Time Blocking'),
                    ),
                    DropdownMenuItem(
                      value: 'gtd',
                      child: Text('GTD (Getting Things Done)'),
                    ),
                  ],
                  onChanged: (value) {
                    selectedTechnique = value ?? 'custom';
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      scheduledDate = date;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Scheduled for ${date.day}/${date.month}/${date.year}',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    scheduledDate == null
                        ? 'Schedule Date'
                        : 'Scheduled: ${scheduledDate!.day}/${scheduledDate!.month}',
                  ),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a plan title')),
                  );
                  return;
                }

                final userProvider = context.read<UserProvider>();
                final userId = userProvider.userId;
                final userName = userProvider.currentUser?.userName ?? 'User';

                final plan = await context.read<PlanProvider>().createPlan(
                      userId: userId!,
                      userName: userName,
                      title: titleController.text,
                      description: descriptionController.text,
                      technique: selectedTechnique,
                      scheduledFor: scheduledDate,
                    );

                if (context.mounted) {
                  Navigator.pop(context);
                  if (plan != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Plan "${plan.planTitle}" created!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
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
                      content:
                          const Text('Are you sure you want to delete this plan?'),
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
