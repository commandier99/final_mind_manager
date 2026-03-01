import 'package:flutter/material.dart';

import '../widgets/task_engagement_section.dart';

class TaskEngagementDetailsPage extends StatelessWidget {
  const TaskEngagementDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task Engagement Today')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          TaskEngagementSection(),
        ],
      ),
    );
  }
}
