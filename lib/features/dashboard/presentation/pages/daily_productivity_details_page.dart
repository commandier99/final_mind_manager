import 'package:flutter/material.dart';

import '../widgets/daily_activity_line_graph_section.dart';

class DailyProductivityDetailsPage extends StatelessWidget {
  const DailyProductivityDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Productivity')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          DailyActivityLineGraphSection(),
        ],
      ),
    );
  }
}
