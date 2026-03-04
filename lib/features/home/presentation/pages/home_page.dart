import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/datasources/providers/navigation_provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../../tasks/datasources/services/task_services.dart';
import '../../../tasks/presentation/widgets/dialogs/add_task_dialog.dart';
import '../../../plans/datasources/providers/plan_provider.dart';
import '../../../plans/datasources/services/plan_service.dart';
import '../widgets/feature_card_widget.dart';
import '../widgets/greeting_section.dart';
import '../../../mind_set/presentation/pages/mind_set_page.dart';
import '../../../mind_set/presentation/widgets/mind_set_create_form.dart';
import '../../../mind_set/datasources/services/mind_set_session_service.dart';
import '../widgets/motivational_quote_card.dart';
import '../../../boards/presentation/widgets/dialogs/add_board_dialog.dart';
import '../../../plans/presentation/pages/create_plan_page.dart';
import '../../../subtasks/datasources/providers/subtask_provider.dart';
import '../../../subtasks/presentation/widgets/dialogs/add_subtask_dialog.dart';
import '../../../../shared/features/poke/presentation/pages/poke_page.dart';

class HomePage extends StatefulWidget {
  final void Function(VoidCallback)? onSettingsPressedReady;

  const HomePage({super.key, this.onSettingsPressedReady});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _showFeaturesKey = 'home_show_instructional_features';
  static const String _showQuoteKey = 'home_show_motivational_quote';
  static const String _showQuickLaunchKey = 'home_show_quick_launch';
  static const String _quickActionsKey = 'home_quick_launch_actions';

  static const String _actionCreateBoard = 'boards_create_board';
  static const String _actionCreateTask = 'boards_create_task';
  static const String _actionCreateSubtask = 'boards_create_subtask';
  static const String _actionCreatePlan = 'plans_create_plan';
  static const String _actionMindSet = 'mindset_home';
  static const String _actionOnTheSpot = 'mindset_on_the_spot';
  static const String _actionGoWithFlow = 'mindset_go_with_flow';
  static const String _actionFollowThrough = 'mindset_follow_through';
  static const String _actionPoke = 'poke_view';
  static const Set<String> _pinnedPrimaryActions = {
    _actionMindSet,
    _actionPoke,
  };

  final List<_QuickLaunchAction> _allQuickActions = const [
    _QuickLaunchAction(
      id: _actionMindSet,
      feature: 'Mind:Set',
      label: 'Mind:Set',
      icon: Icons.psychology,
    ),
    _QuickLaunchAction(
      id: _actionPoke,
      feature: 'Poke',
      label: 'Poke',
      icon: Icons.ads_click,
    ),
    _QuickLaunchAction(
      id: _actionCreateBoard,
      feature: 'Boards',
      label: 'Create Board',
      icon: Icons.add_box_outlined,
    ),
    _QuickLaunchAction(
      id: _actionCreateTask,
      feature: 'Boards',
      label: 'Create Task',
      icon: Icons.playlist_add_outlined,
    ),
    _QuickLaunchAction(
      id: _actionCreateSubtask,
      feature: 'Boards',
      label: 'Create Subtask',
      icon: Icons.subdirectory_arrow_right,
    ),
    _QuickLaunchAction(
      id: _actionCreatePlan,
      feature: 'Plans',
      label: 'Create Plan',
      icon: Icons.post_add,
    ),
    _QuickLaunchAction(
      id: _actionOnTheSpot,
      feature: 'Mind:Set',
      label: 'On the Spot',
      icon: Icons.flash_on_rounded,
    ),
    _QuickLaunchAction(
      id: _actionGoWithFlow,
      feature: 'Mind:Set',
      label: 'Go with the Flow',
      icon: Icons.auto_awesome_rounded,
    ),
    _QuickLaunchAction(
      id: _actionFollowThrough,
      feature: 'Mind:Set',
      label: 'Follow Through',
      icon: Icons.track_changes_rounded,
    ),
  ];

  final MindSetSessionService _mindSetSessionService = MindSetSessionService();
  final TaskService _taskService = TaskService();
  final PlanService _planService = PlanService();
  final SubtaskProvider _subtaskProvider = SubtaskProvider();

  String? _lastStreamedUserId;
  final PageController _featurePageController = PageController();
  int _featurePageIndex = 0;

  bool _showFeatureCarousel = true;
  bool _showMotivationalQuote = true;
  bool _showQuickLaunch = true;
  Set<String> _includedQuickActions = {
    _actionMindSet,
    _actionPoke,
  };

  @override
  void initState() {
    super.initState();
    _loadHomePreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onSettingsPressedReady?.call(_openHomeSettingsSheet);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;

    if (userId != null && _lastStreamedUserId != userId) {
      _lastStreamedUserId = userId;
      debugPrint('[DEBUG] HomePage: Starting task stream for userId: $userId');
      context.read<TaskProvider>().streamUserActiveTasks(userId);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<PlanProvider>().loadUserPlans(userId);
      });
    }
  }

  @override
  void dispose() {
    _featurePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GreetingSection(),
              if (_showFeatureCarousel) ...[
                const SizedBox(height: 20),
                _featureCarouselSection(context),
              ],
              if (_showQuickLaunch) ...[
                const SizedBox(height: 20),
                _quickLaunchSection(context),
              ],
              if (_showMotivationalQuote) ...[
                const SizedBox(height: 24),
                const MotivationalQuoteSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureCarouselSection(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        final userId = context.read<UserProvider>().userId;
        final activeTaskCount = taskProvider.tasks.where((task) {
          final isUserTask =
              task.taskAssignedTo == userId || task.taskOwnerId == userId;
          return isUserTask && !task.taskIsDone;
        }).length;
        final canStartMindSet = activeTaskCount > 0;

        final features = [
          FeatureCard(
            icon: Icons.dashboard_outlined,
            title: 'Set Up Work',
            description: 'Create boards and tasks first.',
            onTap: () {
              context.read<NavigationProvider>().selectFromBottomNav(1);
            },
          ),
          FeatureCard(
            icon: Icons.event_note_outlined,
            title: 'Plan Your Week',
            description: 'Organize timelines and priorities.',
            onTap: () {
              context.read<NavigationProvider>().selectFromBottomNav(2);
            },
          ),
          FeatureCard(
            icon: Icons.psychology,
            title: 'Focus with Mind:Set',
            description: 'Set your mind to be productive.',
            onTap: canStartMindSet
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MindSetPage()),
                    );
                  }
                : null,
          ),
          FeatureCard(
            icon: Icons.analytics_outlined,
            title: 'Track Progress',
            description: 'Review overdue, due today, and completed tasks.',
            onTap: () {
              context.read<NavigationProvider>().selectFromBottomNav(3);
            },
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Core Features',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                Container(width: 1, height: 24, color: Colors.grey.shade400),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Swipe to see what to do next.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 170,
              child: PageView.builder(
                controller: _featurePageController,
                itemCount: features.length,
                onPageChanged: (index) {
                  setState(() {
                    _featurePageIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FeatureCardWidget(feature: features[index]),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                features.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _featurePageIndex == index ? 16 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: _featurePageIndex == index
                        ? Colors.blue.shade700
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              canStartMindSet
                  ? '$activeTaskCount active task(s) ready for focus.'
                  : 'No active tasks yet. Create one in Boards or Plans first.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        );
      },
    );
  }

  Widget _quickLaunchSection(BuildContext context) {
    final includedActions = _allQuickActions
        .where((action) => _includedQuickActions.contains(action.id))
        .toList()
      ..sort((a, b) => _quickActionPriority(a.id).compareTo(_quickActionPriority(b.id)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Quick Launch',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 22, color: Colors.grey.shade400),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Run your selected actions quickly.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (includedActions.isEmpty)
          Text(
            'No actions included. Open Home settings to include actions.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const crossAxisCount = 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: includedActions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 3,
                ),
                itemBuilder: (context, index) {
                  final action = includedActions[index];
                  return _quickLaunchButton(context, action);
                },
              );
            },
          ),
      ],
    );
  }

  Widget _quickLaunchButton(BuildContext context, _QuickLaunchAction action) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleQuickAction(action.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                action.icon,
                color: colorScheme.primary,
                size: 18,
              ),
              const SizedBox(height: 4),
              Text(
                action.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2F3440),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleQuickAction(String actionId) async {
    switch (actionId) {
      case _actionCreateBoard:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AddBoardFormPage()),
        );
        return;
      case _actionCreateTask:
        final userId = context.read<UserProvider>().userId;
        if (userId == null) {
          _showSnack('User not found. Please sign in again.');
          return;
        }
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => AddTaskDialog(userId: userId),
        );
        return;
      case _actionCreateSubtask:
        await _openCreateSubtaskPicker();
        return;
      case _actionCreatePlan:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const CreatePlanPage()),
        );
        return;
      case _actionMindSet:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const MindSetPage()),
        );
        return;
      case _actionOnTheSpot:
        await _openMindSetCreateShortcut('on_the_spot');
        return;
      case _actionGoWithFlow:
        await _openMindSetCreateShortcut('go_with_flow');
        return;
      case _actionFollowThrough:
        await _openMindSetCreateShortcut('follow_through');
        return;
      case _actionPoke:
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => const PokePage(composeOnly: true),
        );
        return;
      default:
        return;
    }
  }

  Future<void> _openCreateSubtaskPicker() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      _showSnack('User not found. Please sign in again.');
      return;
    }

    final tasks = context.read<TaskProvider>().tasks.where((task) {
      final userTask = task.taskAssignedTo == userId || task.taskOwnerId == userId;
      return userTask && !task.taskIsDeleted;
    }).toList();

    if (tasks.isEmpty) {
      _showSnack('No tasks available. Create a task first.');
      return;
    }

    final selectedTask = await showModalBottomSheet<dynamic>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Select a Task',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return ListTile(
                      title: Text(task.taskTitle),
                      subtitle: Text(task.taskBoardTitle ?? 'No board'),
                      onTap: () => Navigator.pop(context, task),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedTask == null || !mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AddSubtaskDialog(
        parentTaskId: selectedTask.taskId,
        subtaskBoardId: selectedTask.taskBoardId,
        subtaskProvider: _subtaskProvider,
      ),
    );
  }

  Future<void> _openMindSetCreateShortcut(String sessionType) async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      _showSnack('User not found. Please sign in again.');
      return;
    }

    final activeSession = await _mindSetSessionService.streamActiveSession(userId).first;
    if (activeSession != null) {
      _showSnack('End your current Mind:Set session first.');
      return;
    }

    if (sessionType == 'go_with_flow') {
      final hasUnplanned = await _hasUnplannedTasks(userId);
      if (!mounted) return;
      if (!hasUnplanned) {
        _showSnack('No unplanned tasks available for Go with the Flow.');
        return;
      }
    }

    if (!mounted) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (context) {
        final height = (MediaQuery.of(context).size.height * 0.82).clamp(
          420.0,
          680.0,
        );
        return SizedBox(
          height: height,
          child: MindSetCreateForm(sessionType: sessionType),
        );
      },
    );
  }

  Future<bool> _hasUnplannedTasks(String userId) async {
    final tasks = await _taskService.streamTasks(ownerId: userId).first;
    final activeTasks = tasks
        .where((task) => !task.taskIsDone && !task.taskIsDeleted)
        .toList();
    if (activeTasks.isEmpty) return false;

    final plans = await _planService.getUserPlans(userId);
    final plannedTaskIds = <String>{};
    for (final plan in plans) {
      plannedTaskIds.addAll(plan.taskIds);
    }

    return activeTasks.any((task) => !plannedTaskIds.contains(task.taskId));
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadHomePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final savedActionIds = prefs.getStringList(_quickActionsKey);
    final validIds = _allQuickActions.map((action) => action.id).toSet();
    final loadedActions = savedActionIds == null
        ? <String>{_actionMindSet, _actionPoke}
        : savedActionIds.where(validIds.contains).toSet();

    setState(() {
      _showFeatureCarousel = prefs.getBool(_showFeaturesKey) ?? true;
      _showMotivationalQuote = prefs.getBool(_showQuoteKey) ?? true;
      _showQuickLaunch = prefs.getBool(_showQuickLaunchKey) ?? true;
      _includedQuickActions = {
        ...loadedActions,
        ..._pinnedPrimaryActions,
      };
    });
  }

  Future<void> _setBoolPref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveQuickActions() async {
    final prefs = await SharedPreferences.getInstance();
    final merged = {
      ..._includedQuickActions,
      ..._pinnedPrimaryActions,
    };
    await prefs.setStringList(_quickActionsKey, merged.toList());
  }

  void _openHomeSettingsSheet() {
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final sheetHeight = (MediaQuery.of(context).size.height * 0.78).clamp(
          420.0,
          640.0,
        );
        return SafeArea(
          child: SizedBox(
            height: sheetHeight,
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                Future<void> toggleAction(String id) async {
                  if (_pinnedPrimaryActions.contains(id)) {
                    return;
                  }
                  setState(() {
                    if (_includedQuickActions.contains(id)) {
                      _includedQuickActions.remove(id);
                    } else {
                      _includedQuickActions.add(id);
                    }
                  });
                  setSheetState(() {});
                  await _saveQuickActions();
                }

                final included = _allQuickActions
                    .where((action) => _includedQuickActions.contains(action.id))
                    .toList();
                final excluded = _allQuickActions
                    .where((action) => !_includedQuickActions.contains(action.id))
                    .toList();

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Home Page Settings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Greeting section is always visible.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Show instructional feature carousel',
                                ),
                                value: _showFeatureCarousel,
                                onChanged: (value) async {
                                  setState(() => _showFeatureCarousel = value);
                                  setSheetState(() {});
                                  await _setBoolPref(_showFeaturesKey, value);
                                },
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Show motivational quotes'),
                                value: _showMotivationalQuote,
                                onChanged: (value) async {
                                  setState(() => _showMotivationalQuote = value);
                                  setSheetState(() {});
                                  await _setBoolPref(_showQuoteKey, value);
                                },
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Show Quick Launch section'),
                                value: _showQuickLaunch,
                                onChanged: (value) async {
                                  setState(() => _showQuickLaunch = value);
                                  setSheetState(() {});
                                  await _setBoolPref(_showQuickLaunchKey, value);
                                },
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Quick Launch Actions',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _actionBucket(
                                title: 'Included',
                                actions: included,
                                emptyText: 'No included actions.',
                                onToggle: _showQuickLaunch ? toggleAction : null,
                                includeStyle: true,
                              ),
                              const SizedBox(height: 10),
                              _actionBucket(
                                title: 'Excluded',
                                actions: excluded,
                                emptyText: 'No excluded actions.',
                                onToggle: _showQuickLaunch ? toggleAction : null,
                                includeStyle: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _actionBucket({
    required String title,
    required List<_QuickLaunchAction> actions,
    required String emptyText,
    required Future<void> Function(String id)? onToggle,
    required bool includeStyle,
  }) {
    final grouped = <String, List<_QuickLaunchAction>>{};
    for (final action in actions) {
      grouped.putIfAbsent(action.feature, () => []).add(action);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: includeStyle
            ? Colors.blue.shade50.withValues(alpha: 0.45)
            : Colors.grey.shade50,
        border: Border.all(
          color: includeStyle ? Colors.blue.shade200 : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                includeStyle ? Icons.check_circle_outline : Icons.remove_circle_outline,
                size: 18,
                color: includeStyle ? Colors.blue.shade700 : Colors.grey.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (actions.isEmpty)
            Text(
              emptyText,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            )
          else
            Column(
              children: grouped.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...entry.value.map(
                        (action) => _quickLaunchSelectorTile(
                          action: action,
                          includeStyle: includeStyle,
                          onToggle: onToggle,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _quickLaunchSelectorTile({
    required _QuickLaunchAction action,
    required bool includeStyle,
    required Future<void> Function(String id)? onToggle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: Icon(action.icon, size: 18, color: Colors.blueGrey.shade700),
        title: Text(
          action.label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        trailing: IconButton(
          iconSize: 18,
          tooltip: includeStyle ? 'Exclude' : 'Include',
          onPressed: onToggle == null || _pinnedPrimaryActions.contains(action.id)
              ? null
              : () => onToggle(action.id),
          icon: Icon(
            includeStyle ? Icons.remove_circle_outline : Icons.add_circle_outline,
            color: _pinnedPrimaryActions.contains(action.id)
                ? Colors.grey.shade400
                : includeStyle
                    ? Colors.red.shade400
                    : Colors.green.shade600,
          ),
        ),
      ),
    );
  }

  int _quickActionPriority(String id) {
    switch (id) {
      case _actionMindSet:
        return 0;
      case _actionPoke:
        return 1;
      default:
        return 10;
    }
  }

}

class _QuickLaunchAction {
  final String id;
  final String feature;
  final String label;
  final IconData icon;

  const _QuickLaunchAction({
    required this.id,
    required this.feature,
    required this.label,
    required this.icon,
  });
}
