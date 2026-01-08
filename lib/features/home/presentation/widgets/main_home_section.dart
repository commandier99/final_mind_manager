import 'package:flutter/material.dart';

import 'greeting_section.dart';
import 'tasks_overdue_widget.dart';
import 'tasks_due_today_widget.dart';
import 'plans_for_today_widget.dart';

class MainHomeSection extends StatelessWidget {
  const MainHomeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        GreetingSection(),
        SizedBox(height: 6),
        TasksOverdueWidget(),
        SizedBox(height: 24),
        TasksDueTodayWidget(),
        SizedBox(height: 24),
        PlansForTodayWidget(),
      ],
    );
  }
}
