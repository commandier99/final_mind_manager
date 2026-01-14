import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../../tasks/datasources/models/task_model.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../plans/datasources/models/plans_model.dart';
import '../../../plans/datasources/providers/plan_provider.dart';
import 'home_plan_card.dart';
import 'plan_details_section.dart';
  
class PlansForTodayWidget extends StatelessWidget {
  final void Function(Plan)? onPlanTap;

  const PlansForTodayWidget({super.key, this.onPlanTap});

  bool _isScheduledForToday(Plan plan) {
    if (plan.planScheduledFor == null || plan.planIsDeleted) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final scheduledDate = DateTime(
      plan.planScheduledFor!.year,
      plan.planScheduledFor!.month,
      plan.planScheduledFor!.day,
    );

    return scheduledDate == today;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlanProvider>(
      builder: (context, planProvider, _) {
        final userId = context.read<UserProvider>().userId;

        final plansForToday = planProvider.userPlans
            .where((plan) {
              final isScheduledForToday = _isScheduledForToday(plan);
              final isUserOwner = plan.planOwnerId == userId;
              return isScheduledForToday && isUserOwner;
            })
            .toList();

        if (plansForToday.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Plans for Today',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '0',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    Text(
                      'No plans scheduled for today',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Plans for Today',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${plansForToday.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: plansForToday.length,
              itemBuilder: (context, index) {
                final plan = plansForToday[index];
                return HomePlanCard(
                  plan: plan,
                  onTap: () => onPlanTap?.call(plan),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
