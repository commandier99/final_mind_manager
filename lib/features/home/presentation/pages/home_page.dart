import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../../plans/datasources/providers/plan_provider.dart';
import '../widgets/main_home_section.dart';
import '../widgets/motivational_quote_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _lastStreamedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;
    
    if (userId != null && _lastStreamedUserId != userId) {
      _lastStreamedUserId = userId;
      print('[DEBUG] HomePage: Starting task stream for userId: $userId');
      context.read<TaskProvider>().streamUserActiveTasks(userId);
      
      // Defer the plan loading to after the current frame to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<PlanProvider>().loadUserPlans(userId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MainHomeSection(),
          const SizedBox(height: 24),
          const MotivationalQuoteSection(),
        ],
      ),
    );
  }
}
