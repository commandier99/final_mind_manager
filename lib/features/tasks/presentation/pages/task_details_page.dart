import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../datasources/models/task_model.dart';
import '../../../../shared/presentation/widgets/app_top_bar.dart';
import '../../../../shared/presentation/widgets/app_bottom_navigation.dart';
import '../../../../shared/presentation/widgets/app_side_menu.dart';
import '../../../../shared/datasources/providers/navigation_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/sections/task_details_section.dart';
import '../widgets/sections/task_applications_section.dart';
import '../widgets/sections/task_steps_list.dart';
import '../widgets/sections/task_file_submissions_section.dart';
import '../widgets/sections/task_stats_section.dart';
import '../../../steps/datasources/providers/step_provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
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
  static const String _lastVisitedTaskIdKey = 'home_last_visited_task_id';
  static const String _lastVisitedTaskTitleKey = 'home_last_visited_task_title';
  static const String _lastVisitedTaskBoardTitleKey =
      'home_last_visited_task_board_title';
  static const String _lastVisitedTaskAtKey = 'home_last_visited_task_at';

  static const String _tabSteps = 'steps';
  static const String _tabSubmissions = 'submissions';
  static const String _tabStats = 'stats';
  static const String _tabApplications = 'applications';

  bool _isDetailsPanelExpanded = true;
  bool _isSearchExpanded = false;
  String _selectedTab = _tabSteps;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _persistLastVisitedTask();
  }

  Future<void> _persistLastVisitedTask() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null || userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_lastVisitedTaskIdKey}_$userId', widget.task.taskId);
    await prefs.setString(
      '${_lastVisitedTaskTitleKey}_$userId',
      widget.task.taskTitle,
    );
    await prefs.setString(
      '${_lastVisitedTaskBoardTitleKey}_$userId',
      (widget.task.taskBoardTitle ?? '').trim(),
    );
    await prefs.setInt(
      '${_lastVisitedTaskAtKey}_$userId',
      DateTime.now().millisecondsSinceEpoch,
    );
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

  Future<void> _duplicateTask() async {
    try {
      final duplicatedTask = await context.read<TaskProvider>().duplicateTask(
        widget.task,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task duplicated: ${duplicatedTask.taskTitle}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to duplicate task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[DEBUG] TaskDetailsPage: build called for taskId = ${widget.task.taskId}',
    );
    final navigation = context.watch<NavigationProvider>();
    final currentUserId = context.watch<UserProvider>().userId;
    final boardProvider = context.watch<BoardProvider>();
    final board = widget.task.taskBoardId.isNotEmpty
        ? boardProvider.getBoardById(widget.task.taskBoardId)
        : null;
    final canEditTaskDetails = widget.task.taskBoardId.isNotEmpty
        ? (board?.isManager(currentUserId) == true ||
              board?.isSupervisor(currentUserId) == true)
        : currentUserId == widget.task.taskOwnerId;

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
              itemBuilder: (menuContext) => [
                if (canEditTaskDetails)
                  PopupMenuItem(
                    child: const Text('Edit'),
                    onTap: () {
                      // Show edit task dialog after menu closes
                      Future.delayed(Duration.zero, () {
                        if (!mounted) return;
                        showDialog(
                          context: this.context,
                          builder: (context) =>
                              EditTaskDialog(task: widget.task),
                        );
                      });
                    },
                  ),
                if (canEditTaskDetails)
                  PopupMenuItem(
                    child: const Text('Duplicate'),
                    onTap: () {
                      Future.delayed(Duration.zero, _duplicateTask);
                    },
                  ),
                PopupMenuItem(
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    // TODO: Implement task deletion
                    debugPrint(
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
          debugPrint(
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
            final canManageTask = _canManageTask(currentTask);
            final showApplicationsTab =
                isUnassigned && _canViewApplications(currentTask);
            final showWorkTabs =
                canManageTask ||
                (!isUnassigned && isAcceptedOrNoAcceptanceNeeded);
            final showSubmissionsTab =
                showWorkTabs && currentTask.taskAllowsSubmissions;

            if (showApplicationsTab && _selectedTab != _tabApplications) {
              _selectedTab = _tabApplications;
            }
            if (!showApplicationsTab && _selectedTab == _tabApplications) {
              _selectedTab = _tabSteps;
            }
            if (!showSubmissionsTab && _selectedTab == _tabSubmissions) {
              _selectedTab = _tabSteps;
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
                if (showApplicationsTab || showWorkTabs)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Row(
                      children: [
                        if (showWorkTabs)
                          Expanded(
                            child: _buildViewTab(
                              label: 'Steps',
                              selected: _selectedTab == _tabSteps,
                              onTap: () =>
                                  setState(() => _selectedTab = _tabSteps),
                            ),
                          ),
                        if (showWorkTabs && showSubmissionsTab) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildViewTab(
                              label: 'Uploads',
                              selected: _selectedTab == _tabSubmissions,
                              onTap: () => setState(
                                () => _selectedTab = _tabSubmissions,
                              ),
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
                        if (showApplicationsTab)
                          Expanded(
                            child: _buildViewTab(
                              label: 'Applications',
                              selected: _selectedTab == _tabApplications,
                              onTap: () => setState(
                                () => _selectedTab = _tabApplications,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (showWorkTabs && _selectedTab == _tabSteps)
                  ChangeNotifierProvider(
                    create: (_) => StepProvider(),
                    child: TaskStepsList(
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
                else if (showApplicationsTab &&
                    _selectedTab == _tabApplications)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: TaskApplicationsSection(taskId: currentTask.taskId),
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
          debugPrint('[DEBUG] TaskDetailsPage: BottomNav tapped index = $index');
          // Pop back to main screen first, then navigate
          Navigator.of(context).popUntil((route) => route.isFirst);
          navigation.selectFromBottomNav(index);
        },
      ),
    );
  }

  bool _canViewApplications(Task task) {
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

  bool _canManageTask(Task task) {
    final currentUserId = context.read<UserProvider>().userId;
    if (currentUserId == null || currentUserId.isEmpty) return false;
    if (task.taskOwnerId == currentUserId) return true;
    if (task.taskBoardId.isEmpty) return false;
    final board = context.read<BoardProvider>().getBoardById(task.taskBoardId);
    if (board == null) return false;
    return board.isManager(currentUserId) || board.isSupervisor(currentUserId);
  }

  bool _isTaskFocusedStatus(String status) {
    final normalized = status.toUpperCase().replaceAll(' ', '_');
    return normalized == 'IN_PROGRESS' || normalized == 'FOCUSED';
  }

  bool _isTaskUnassigned(Task task) {
    return task.taskAssignedTo.isEmpty || task.taskAssignedTo == 'None';
  }

  bool _isAcceptedOrNoAcceptanceNeeded(Task task) {
    return task.taskAssignmentStatus == null ||
        task.taskAssignmentStatus == 'accepted';
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

