import 'package:flutter/material.dart';
import '../../datasources/models/task_model.dart';
import '../../../../shared/presentation/widgets/app_top_bar.dart';
import '../../../../shared/presentation/widgets/app_bottom_navigation.dart';
import '../../../../shared/presentation/widgets/app_side_menu.dart';
import '../../../../shared/datasources/providers/navigation_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/sections/task_details_section.dart';
import '../widgets/sections/task_subtasks_list.dart';
import '../widgets/sections/task_file_submissions_section.dart';
import '../../../subtasks/datasources/providers/subtask_provider.dart';

class TaskDetailsPage extends StatelessWidget {
  final Task task;

  const TaskDetailsPage({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    print('[DEBUG] TaskDetailsPage: build called for taskId = ${task.taskId}');
    final navigation = context.watch<NavigationProvider>();

    return Scaffold(
      appBar: AppTopBar(title: 'Task Details'),
      drawer: AppSideMenu(
        onSelect: (sideMenuIndex) {
          print(
            '[DEBUG] TaskDetailsPage: SideMenu selected index = $sideMenuIndex',
          );
          navigation.selectFromSideMenu(sideMenuIndex + 4);
          Navigator.pop(context);
        },
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            TaskDetailsSection(taskId: task.taskId),
            const SizedBox(height: 1),
            // Only show file submissions for board tasks
            if (task.taskBoardId.isNotEmpty) ...[
              TaskFileSubmissionsSection(task: task),
              const SizedBox(height: 1),
            ],
            ChangeNotifierProvider(
              create: (_) => SubtaskProvider(),
              child: TaskSubtasksList(
                parentTaskId: task.taskId,
                boardId: task.taskBoardId.isNotEmpty ? task.taskBoardId : null,
                task: task,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: navigation.bottomNavIndex ?? 0,
        onTap: (index) {
          print('[DEBUG] TaskDetailsPage: BottomNav tapped index = $index');
          // Pop back to main screen first, then navigate
          Navigator.of(context).popUntil((route) => route.isFirst);
          navigation.selectFromBottomNav(index);
        },
      ),
    );
  }
}
