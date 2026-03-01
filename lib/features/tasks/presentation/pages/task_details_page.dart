import 'package:flutter/material.dart';
import '../../datasources/models/task_model.dart';
import '../../../../shared/presentation/widgets/app_top_bar.dart';
import '../../../../shared/presentation/widgets/app_bottom_navigation.dart';
import '../../../../shared/presentation/widgets/app_side_menu.dart';
import '../../../../shared/datasources/providers/navigation_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/sections/task_details_section.dart';
import '../widgets/sections/task_appeals_section.dart';
import '../widgets/sections/task_subtasks_list.dart';
import '../widgets/sections/task_file_submissions_section.dart';
import '../widgets/sections/task_stats_section.dart';
import '../../../subtasks/datasources/providers/subtask_provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../../shared/features/users/datasources/providers/activity_event_provider.dart';
import '../widgets/dialogs/edit_task_dialog.dart';
import '../../datasources/providers/task_provider.dart';
import '../../../boards/datasources/providers/board_provider.dart';

class TaskDetailsPage extends StatefulWidget {
  final Task task;

  const TaskDetailsPage({super.key, required this.task});

  @override
  State<TaskDetailsPage> createState() => _TaskDetailsPageState();
}

class _TaskDetailsPageState extends State<TaskDetailsPage> {
  static const String _tabSubtasks = 'subtasks';
  static const String _tabSubmissions = 'submissions';
  static const String _tabStats = 'stats';
  static const String _tabAppeals = 'appeals';

  bool _isDetailsPanelExpanded = true;
  bool _isSearchExpanded = false;
  String _selectedTab = _tabSubtasks;
  final TextEditingController _searchController = TextEditingController();

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
          boardId: widget.task.taskBoardId.isNotEmpty
              ? widget.task.taskBoardId
              : null,
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
      }
    });
  }

  void _toggleDetailsPanel() {
    setState(() {
      _isDetailsPanelExpanded = !_isDetailsPanelExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    print(
      '[DEBUG] TaskDetailsPage: build called for taskId = ${widget.task.taskId}',
    );
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
          setState(() {});
        },
        onSearchClear: () {
          setState(() {
            _searchController.clear();
          });
        },
        customActions: [
          if (!_isSearchExpanded) ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _toggleSearch,
            ),
            IconButton(
              icon: Icon(
                _isDetailsPanelExpanded ? Icons.expand_less : Icons.expand_more,
              ),
              tooltip: _isDetailsPanelExpanded
                  ? 'Hide task details'
                  : 'Show task details',
              onPressed: _toggleDetailsPanel,
            ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Text('Edit'),
                  onTap: () {
                    // Show edit task dialog after menu closes
                    Future.delayed(Duration.zero, () {
                      showDialog(
                        context: context,
                        builder: (context) => EditTaskDialog(task: widget.task),
                      );
                    });
                  },
                ),
                PopupMenuItem(
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    // TODO: Implement task deletion
                    print(
                      '[DEBUG] TaskDetailsPage: Delete tapped for taskId = ${widget.task.taskId}',
                    );
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
          navigation.selectFromSideMenu(sideMenuIndex);
        },
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Consumer<TaskProvider>(
          builder: (context, taskProvider, _) {
            late final Task currentTask;
            try {
              currentTask = taskProvider.tasks.firstWhere(
                (t) => t.taskId == widget.task.taskId,
              );
            } catch (_) {
              currentTask = widget.task;
            }

            final isUnassigned = _isTaskUnassigned(currentTask);
            final isAcceptedOrNoAcceptanceNeeded =
                _isAcceptedOrNoAcceptanceNeeded(currentTask);
            final showAppealsTab = isUnassigned && _canViewAppeals(currentTask);
            final showWorkTabs =
                !isUnassigned && isAcceptedOrNoAcceptanceNeeded;
            final showSubmissionsTab =
                showWorkTabs && currentTask.taskAllowsSubmissions;

            if (showAppealsTab && _selectedTab != _tabAppeals) {
              _selectedTab = _tabAppeals;
            }
            if (!showAppealsTab && _selectedTab == _tabAppeals) {
              _selectedTab = _tabSubtasks;
            }
            if (!showSubmissionsTab && _selectedTab == _tabSubmissions) {
              _selectedTab = _tabSubtasks;
            }

            return Column(
              children: [
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: _isDetailsPanelExpanded
                            ? TaskDetailsSection(taskId: currentTask.taskId)
                            : const SizedBox.shrink(),
                      ),
                      GestureDetector(
                        onTap: _toggleDetailsPanel,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 2,
                            horizontal: 16,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Colors.grey[300],
                                ),
                              ),
                              const SizedBox(width: 8),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Icon(
                                  _isDetailsPanelExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  key: ValueKey(_isDetailsPanelExpanded),
                                  color: Colors.grey[600],
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Colors.grey[300],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (showAppealsTab || showWorkTabs)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Row(
                      children: [
                        if (showWorkTabs)
                          Expanded(
                            child: _buildViewTab(
                              label: 'Subtasks',
                              selected: _selectedTab == _tabSubtasks,
                              onTap: () =>
                                  setState(() => _selectedTab = _tabSubtasks),
                            ),
                          ),
                        if (showWorkTabs && showSubmissionsTab) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildViewTab(
                              label: 'Submissions',
                              selected: _selectedTab == _tabSubmissions,
                              onTap: () =>
                                  setState(() => _selectedTab = _tabSubmissions),
                            ),
                          ),
                        ],
                        if (showWorkTabs) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildViewTab(
                              label: 'Stats',
                              selected: _selectedTab == _tabStats,
                              onTap: () =>
                                  setState(() => _selectedTab = _tabStats),
                            ),
                          ),
                        ],
                        if (showAppealsTab)
                          Expanded(
                            child: _buildViewTab(
                              label: 'Appeals',
                              selected: _selectedTab == _tabAppeals,
                              onTap: () =>
                                  setState(() => _selectedTab = _tabAppeals),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (showWorkTabs && _selectedTab == _tabSubtasks)
                  ChangeNotifierProvider(
                    create: (_) => SubtaskProvider(),
                    child: TaskSubtasksList(
                      parentTaskId: currentTask.taskId,
                      boardId: currentTask.taskBoardId.isNotEmpty
                          ? currentTask.taskBoardId
                          : null,
                      task: currentTask,
                      allowCompletionToggle: _isTaskFocusedStatus(
                        currentTask.taskStatus,
                      ),
                    ),
                  )
                else if (showWorkTabs && _selectedTab == _tabSubmissions)
                  TaskFileSubmissionsSection(task: currentTask)
                else if (showWorkTabs && _selectedTab == _tabStats)
                  TaskStatsSection(task: currentTask)
                else if (showAppealsTab && _selectedTab == _tabAppeals)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: TaskAppealsSection(taskId: currentTask.taskId),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Task details tabs will appear after assignment is accepted.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
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

  bool _canViewAppeals(Task task) {
    final currentUserId = context.read<UserProvider>().userId;
    if (currentUserId == null) return false;

    final isUnassigned =
        task.taskAssignedTo.isEmpty || task.taskAssignedTo == 'None';
    if (!isUnassigned) return false;

    if (task.taskOwnerId == currentUserId) return true;

    if (task.taskBoardId.isNotEmpty) {
      final board = context.read<BoardProvider>().getBoardById(
        task.taskBoardId,
      );
      if (board?.boardManagerId == currentUserId) {
        return true;
      }
    }
    return false;
  }

  bool _isTaskFocusedStatus(String status) {
    final normalized = status.toUpperCase().replaceAll(' ', '_');
    return normalized == 'IN_PROGRESS' || normalized == 'FOCUSED';
  }

  bool _isTaskUnassigned(Task task) {
    return task.taskAssignedTo.isEmpty || task.taskAssignedTo == 'None';
  }

  bool _isAcceptedOrNoAcceptanceNeeded(Task task) {
    return task.taskAcceptanceStatus == null ||
        task.taskAcceptanceStatus == 'accepted';
  }

  Widget _buildViewTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? Colors.blue : Colors.grey[300]!,
              width: selected ? 2 : 1,
            ),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.blue[700] : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}
