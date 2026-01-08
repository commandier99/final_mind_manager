import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../../plans/datasources/providers/plan_provider.dart';
import '../widgets/main_home_section.dart';
import '../widgets/motivational_quote_card.dart';
import '../widgets/plans_for_today_widget.dart';
import '../widgets/plans_section.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _lastStreamedUserId;
  bool _showPlansSection = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;
    
    if (userId != null && _lastStreamedUserId != userId) {
      _lastStreamedUserId = userId;
      print('[DEBUG] HomePage: Starting task stream for userId: $userId');
      context.read<TaskProvider>().streamUserActiveTasks(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActivePlan = context.watch<PlanProvider>().hasActivePlan;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showPlansSection) ...[
              const PlansSection(),
            ] else ...[
              const MainHomeSection(),
              const SizedBox(height: 24),
              const PlansForTodayWidget(),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showPlansSection = !_showPlansSection;
                  });
                },
                icon: Icon(
                  _showPlansSection ? Icons.home_filled : Icons.event_note,
                  color: Colors.white,
                ),
                label: Text(
                  _showPlansSection ? 'Back to Home' : 'View All Plans',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _showPlansSection ? Colors.blue.shade600 : Colors.blue.shade500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const MotivationalQuoteSection(),
          ],
        ),
      ),
    );
  }
}
