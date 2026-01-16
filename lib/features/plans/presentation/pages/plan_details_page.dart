import 'package:flutter/material.dart';
import '../../datasources/models/plans_model.dart';
import '../../../../shared/presentation/widgets/app_top_bar.dart';
import '../../../../shared/presentation/widgets/app_bottom_navigation.dart';
import '../../../../shared/presentation/widgets/app_side_menu.dart';
import '../../../../shared/datasources/providers/navigation_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/sections/plan_details_section.dart';
import '../widgets/sections/plan_tasks_section.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../datasources/providers/plan_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlanDetailsPage extends StatefulWidget {
  final Plan plan;

  const PlanDetailsPage({super.key, required this.plan});

  @override
  State<PlanDetailsPage> createState() => _PlanDetailsPageState();
}

class _PlanDetailsPageState extends State<PlanDetailsPage> {
  @override
  void initState() {
    super.initState();
    print(
      '[DEBUG] PlanDetailsPage: initState called for planId = ${widget.plan.planId}',
    );

    // Initialize streams after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Start streaming tasks for this plan
      if (widget.plan.taskIds.isNotEmpty) {
        context.read<TaskProvider>().streamTasksByIds(widget.plan.taskIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print(
      '[DEBUG] PlanDetailsPage: build called for planId = ${widget.plan.planId}',
    );
    final navigation = context.watch<NavigationProvider>();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isOwner = widget.plan.planOwnerId == currentUserId;

    return Scaffold(
      appBar: AppTopBar(
        title: 'Plan Details',
        showBackButton: true,
        onBackPressed: () => Navigator.pop(context),
        showNotificationButton: false,
      ),
      drawer: AppSideMenu(
        onSelect: (sideMenuIndex) {
          print(
            '[DEBUG] PlanDetailsPage: SideMenu selected index = $sideMenuIndex',
          );
          navigation.selectFromSideMenu(sideMenuIndex + 4);
        },
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Plan Details Section
            PlanDetailsSection(
              plan: widget.plan,
              isOwner: isOwner,
            ),

            // Plan Tasks Section
            PlanTasksSection(
              plan: widget.plan,
              isOwner: isOwner,
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: navigation.bottomNavIndex ?? 0,
        onTap: (index) {
          print('[DEBUG] PlanDetailsPage: BottomNav tapped index = $index');
          // Pop back to main screen first, then navigate
          Navigator.of(context).popUntil((route) => route.isFirst);
          navigation.selectFromBottomNav(index);
        },
      ),
    );
  }
}
