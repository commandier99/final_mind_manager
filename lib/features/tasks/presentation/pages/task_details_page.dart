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
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../../shared/features/users/datasources/providers/activity_event_provider.dart';

class TaskDetailsPage extends StatefulWidget {
  final Task task;

  const TaskDetailsPage({super.key, required this.task});

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  bool _showFileSubmissions = false;
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Log task_opened activity
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = context.read<UserProvider>();
      final activityProvider = context.read<ActivityEventProvider>();
      
      if (userProvider.userId != null && userProvider.currentUser != null) {
        activityProvider.logEvent(
          userId: userProvider.userId!,
          userName: userProvider.currentUser!.userName,
          activityType: 'task_opened',
          userProfilePicture: userProvider.currentUser!.userProfilePicture,
          taskId: widget.task.taskId,
          boardId: widget.task.taskBoardId.isNotEmpty ? widget.task.taskBoardId : null,
          description: 'Opened task: ${widget.task.taskTitle}',
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (!_isSearchExpanded) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print('[DEBUG] TaskDetailsPage: build called for taskId = ${widget.task.taskId}');
    final navigation = context.watch<NavigationProvider>();

    return Scaffold(
        appBar: AppTopBar(
          title: 'Task Details',
          showBackButton: true,
          onBackPressed: () => Navigator.pop(context),
          showNotificationButton: false,
          isSearchExpanded: _isSearchExpanded,
          searchController: _searchController,
          onSearchPressed: _toggleSearch,
          onSearchChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          onSearchClear: () {
            setState(() {
              _searchController.clear();
              _searchQuery = '';
            });
          },
          customActions: [
            if (!_isSearchExpanded) ...[
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _toggleSearch,
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: const Text('Edit'),
                    onTap: () {
                      // TODO: Navigate to edit task page
                      print('[DEBUG] TaskDetailsPage: Edit tapped for taskId = ${widget.task.taskId}');
                    },
                  ),
                  PopupMenuItem(
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    onTap: () {
                      // TODO: Implement task deletion
                      print('[DEBUG] TaskDetailsPage: Delete tapped for taskId = ${widget.task.taskId}');
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
        drawer: AppSideMenu(
          onSelect: (sideMenuIndex) {
            print(
              '[DEBUG] TaskDetailsPage: SideMenu selected index = $sideMenuIndex',
            );
            navigation.selectFromSideMenu(sideMenuIndex + 4);
          },
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              TaskDetailsSection(
              taskId: widget.task.taskId,
              onFileUploadPressed: () {
                setState(() {
                  _showFileSubmissions = !_showFileSubmissions;
                });
              },
              showFileSubmissions: _showFileSubmissions,
            ),
            const SizedBox(height: 1),
            // Only show file submissions for board tasks when toggled
            if (widget.task.taskBoardId.isNotEmpty && _showFileSubmissions) ...[
              TaskFileSubmissionsSection(
                task: widget.task,
              ),
              const SizedBox(height: 1),
            ],
            // Only show subtasks when file submissions are not visible
            if (!_showFileSubmissions)
              ChangeNotifierProvider(
                create: (_) => SubtaskProvider(),
                child: TaskSubtasksList(
                  parentTaskId: widget.task.taskId,
                  boardId: widget.task.taskBoardId.isNotEmpty ? widget.task.taskBoardId : null,
                  task: widget.task,
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
