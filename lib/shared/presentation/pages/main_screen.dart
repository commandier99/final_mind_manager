import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/task_deadline_reminder_service.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/app_side_menu.dart';
import '../../../features/home/presentation/pages/home_page.dart';
import '../../../features/boards/presentation/pages/boards_page.dart';
import '../../../features/plans/presentation/pages/plans_page.dart';
import '../../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../datasources/providers/navigation_provider.dart';
import '../../features/users/datasources/providers/user_provider.dart';
import '../pages/profile_page.dart';
import '../pages/search_and_discover_page.dart';
import '../pages/settings_page.dart';
import '../pages/help_page.dart';
import '../pages/about_page.dart';
import '../../../features/mind_set/presentation/pages/mind_set_page.dart';
import '../../../features/notifications/datasources/providers/notification_provider.dart';
import '../../../features/notifications/presentation/pages/notifications_page.dart';
import '../../../features/thoughts/presentation/pages/thoughts_page.dart';
import '../../../features/boards/datasources/providers/board_provider.dart';
import '../../../features/boards/datasources/providers/board_stats_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ProfilePageController _profilePageController = ProfilePageController();
  final TaskDeadlineReminderService _taskDeadlineReminderService =
      TaskDeadlineReminderService();
  VoidCallback? _homeSettingsPressed;
  VoidCallback? _boardsSearchToggle;
  VoidCallback? _plansSearchToggle;
  VoidCallback? _boardsFilterPressed;
  VoidCallback? _boardsSortPressed;
  VoidCallback? _plansFilterPressed;
  VoidCallback? _plansSortPressed;

  bool _boardsSearchExpanded = false;
  bool _plansSearchExpanded = false;
  TextEditingController? _boardsSearchController;
  TextEditingController? _plansSearchController;
  ValueChanged<String>? _boardsSearchChanged;
  ValueChanged<String>? _plansSearchChanged;
  VoidCallback? _boardsSearchClear;
  VoidCallback? _plansSearchClear;
  String? _activeUserId;

  List<Widget> get _pages => [
    HomePage(
      key: const ValueKey('home_page'),
      onSettingsPressedReady: (handler) {
        if (!mounted) return;
        if (_homeSettingsPressed == handler) return;
        setState(() {
          _homeSettingsPressed = handler;
        });
      },
    ),
    BoardsPage(
      key: const ValueKey('boards_page'),
      onSearchToggleReady: (toggle) => _boardsSearchToggle = toggle,
      onSearchStateChanged: (expanded, controller, onChanged, onClear) {
        setState(() {
          _boardsSearchExpanded = expanded;
          _boardsSearchController = controller;
          _boardsSearchChanged = onChanged;
          _boardsSearchClear = onClear;
        });
      },
      onFilterPressedReady: (handler) => _boardsFilterPressed = handler,
      onSortPressedReady: (handler) => _boardsSortPressed = handler,
    ),
    PlansPage(
      key: const ValueKey('plans_page'),
      onSearchToggleReady: (toggle) => _plansSearchToggle = toggle,
      onSearchStateChanged: (expanded, controller, onChanged, onClear) {
        setState(() {
          _plansSearchExpanded = expanded;
          _plansSearchController = controller;
          _plansSearchChanged = onChanged;
          _plansSearchClear = onClear;
        });
      },
      onFilterPressedReady: (handler) => _plansFilterPressed = handler,
      onSortPressedReady: (handler) => _plansSortPressed = handler,
    ),
    const DashboardPage(),
    ProfilePage(controller: _profilePageController),
    const SearchAndDiscoverPage(),
    const NotificationsPage(),
    const ThoughtsPage(),
    const SettingsPage(),
    const HelpPage(),
    const AboutPage(),
    const MindSetPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profilePageController.addListener(_handleProfileControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _taskDeadlineReminderService.checkAndCreateReminders();
      _taskDeadlineReminderService.startPeriodicReminders();
      if (!mounted) return;
      context.read<UserProvider>().markUserActive(force: true);
      final userId = context.read<UserProvider>().userId;
      if (userId != null && userId.isNotEmpty) {
        context.read<NotificationProvider>().streamNotificationsForUser(userId);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _taskDeadlineReminderService.stopPeriodicReminders();
    _profilePageController.removeListener(_handleProfileControllerChanged);
    _profilePageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _taskDeadlineReminderService.checkAndCreateReminders();
      context.read<UserProvider>().markUserActive(force: true);
      final userId = context.read<UserProvider>().userId;
      if (userId != null && userId.isNotEmpty) {
        context.read<NotificationProvider>().streamNotificationsForUser(userId);
      }
    }
  }

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _openNotifications() {
    context.read<NavigationProvider>().selectFromSideMenu(6);
  }

  void _handleSearchPressed() {
    final navigation = context.read<NavigationProvider>();
    final selectedIndex = navigation.selectedIndex;

    if (selectedIndex == 1) {
      _boardsSearchToggle?.call();
    } else if (selectedIndex == 2) {
      _plansSearchToggle?.call();
    } else {
      navigation.selectFromSideMenu(5);
    }
  }

  void _handleProfileControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<UserProvider>().userId;
    if (_activeUserId != currentUserId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<BoardProvider>().syncForCurrentUser();
        context.read<BoardStatsProvider>().clear();
      });
      _activeUserId = currentUserId;
    }

    final navigation = context.watch<NavigationProvider>();
    final selectedIndex = navigation.selectedIndex;

    List<Widget>? customActions;
    if (selectedIndex == 0) {
      customActions = [
        Consumer<NotificationProvider>(
          builder: (context, notificationProvider, _) {
            final unreadCount = notificationProvider.unreadCount;
            return IconButton(
              icon: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: _openNotifications,
              tooltip: 'Notifications',
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: _homeSettingsPressed,
          tooltip: 'Home settings',
        ),
      ];
    } else if (selectedIndex == 1 || selectedIndex == 2) {
      final isBoardsPage = selectedIndex == 1;
      final onFilterPressed = isBoardsPage
          ? _boardsFilterPressed
          : _plansFilterPressed;
      final onSortPressed = isBoardsPage
          ? _boardsSortPressed
          : _plansSortPressed;

      customActions = [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: onFilterPressed,
          tooltip: 'Filter',
        ),
        IconButton(
          icon: const Icon(Icons.swap_vert),
          onPressed: onSortPressed,
          tooltip: 'Sort',
        ),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _handleSearchPressed,
          tooltip: 'Search',
        ),
      ];
    } else if (selectedIndex == 4) {
      customActions = [
        PopupMenuButton<String>(
          tooltip: 'Profile options',
          onSelected: (value) {
            if (value == 'edit') {
              _profilePageController.enterEditMode();
            } else if (value == 'cancel') {
              _profilePageController.cancelEditMode();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: _profilePageController.isEditingProfile ? 'cancel' : 'edit',
              child: Text(
                _profilePageController.isEditingProfile
                    ? 'Cancel editing'
                    : 'Edit profile',
              ),
            ),
          ],
        ),
      ];
    }

    final isSearchExpanded = selectedIndex == 1
        ? _boardsSearchExpanded
        : selectedIndex == 2
            ? _plansSearchExpanded
            : false;
    final searchController = selectedIndex == 1
        ? _boardsSearchController
        : selectedIndex == 2
            ? _plansSearchController
            : null;
    final onSearchChanged = selectedIndex == 1
        ? _boardsSearchChanged
        : selectedIndex == 2
            ? _plansSearchChanged
            : null;
    final onSearchClear = selectedIndex == 1
        ? _boardsSearchClear
        : selectedIndex == 2
            ? _plansSearchClear
            : null;

    final floatingActionButton = selectedIndex == 4 &&
            _profilePageController.isEditingProfile
        ? FloatingActionButton.extended(
            onPressed: _profilePageController.isSavingProfile
                ? null
                : () => _profilePageController.saveProfileChanges(),
            icon: _profilePageController.isSavingProfile
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _profilePageController.isSavingProfile ? 'Saving...' : 'Save',
            ),
          )
        : null;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppTopBar(
        onMenuPressed: _openDrawer,
        onBackPressed: () {
          navigation.selectFromBottomNav(0);
        },
        title: navigation.currentTitle,
        showNotificationButton: selectedIndex == 0 || navigation.sideMenuIndex != null,
        showBackButton: false,
        customActions: customActions,
        onSearchPressed: _handleSearchPressed,
        isSearchExpanded: isSearchExpanded,
        searchController: searchController,
        onSearchChanged: onSearchChanged,
        onSearchClear: onSearchClear,
      ),
      drawer: AppSideMenu(
        onSelect: (idx) {
          navigation.selectFromSideMenu(idx);
        },
      ),
      body: IndexedStack(index: selectedIndex, children: _pages),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: navigation.bottomNavIndex ?? 0,
        onTap: (index) {
          navigation.selectFromBottomNav(index);
        },
      ),
    );
  }
}
