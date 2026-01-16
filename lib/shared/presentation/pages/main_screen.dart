import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/app_side_menu.dart';
import '../../../features/home/presentation/pages/home_page.dart';
import '../../../features/boards/presentation/pages/boards_page.dart';
import '../../../features/plans/presentation/pages/plans_page.dart';
import '../../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../datasources/providers/navigation_provider.dart';
import '../pages/notifications_page.dart';
import '../pages/profile_page.dart';
import '../pages/search_discover_page.dart';
import '../pages/settings_page.dart';
import '../pages/help_page.dart';
import '../pages/about_page.dart';
import '../../features/notifications/datasources/providers/notification_provider.dart';
import '../../features/users/datasources/providers/user_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  VoidCallback? _boardsSearchToggle;
  VoidCallback? _plansSearchToggle;
  
  // Search state
  bool _boardsSearchExpanded = false;
  bool _plansSearchExpanded = false;
  TextEditingController? _boardsSearchController;
  TextEditingController? _plansSearchController;
  ValueChanged<String>? _boardsSearchChanged;
  ValueChanged<String>? _plansSearchChanged;
  VoidCallback? _boardsSearchClear;
  VoidCallback? _plansSearchClear;

  // Pages aligned with NavigationProvider.titles indexes
  List<Widget> get _pages => [
        const HomePage(),
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
        ),
        const DashboardPage(),
        const ProfilePage(),
        const NotificationsPage(),
        const SearchDiscoverPage(),
        const SettingsPage(),
        const HelpPage(),
        const AboutPage(),
      ];

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _handleSearchPressed() {
    final navigation = context.read<NavigationProvider>();
    final selectedIndex = navigation.selectedIndex;

    // Trigger search in current page
    if (selectedIndex == 1) {
      // Boards page
      _boardsSearchToggle?.call();
    } else if (selectedIndex == 2) {
      // Plans page
      _plansSearchToggle?.call();
    } else {
      // Navigate to Search & Discover page for other pages
      navigation.selectFromSideMenu(6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<NavigationProvider>();
    final selectedIndex = navigation.selectedIndex;
    final isNotificationsPage = selectedIndex == 5;
    final showNotificationButton =
      !isNotificationsPage && (selectedIndex == 0 || navigation.sideMenuIndex != null);

    // Custom actions for notifications page (3-dot menu)
    List<Widget>? customActions;
    if (isNotificationsPage) {
      customActions = [
        Consumer<NotificationProvider>(
          builder: (context, notifProvider, _) {
            if (notifProvider.notifications.isEmpty) {
              return const SizedBox.shrink();
            }
            final userId = context.read<UserProvider>().userId;
            return PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) async {
                if (value == 'mark_all_read' && userId != null) {
                  await notifProvider.markAllAsRead(userId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All notifications marked as read')),
                    );
                  }
                } else if (value == 'clear_all' && userId != null) {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear All Notifications'),
                      content: const Text('Are you sure you want to delete all notifications?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await notifProvider.clearUserNotifications(userId);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All notifications cleared')),
                      );
                    }
                  }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'mark_all_read',
                  child: Row(
                    children: [
                      Icon(Icons.done_all, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Mark all as read'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Clear all'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ];
    }
    
    // Determine search state based on current page
    final isSearchExpanded = selectedIndex == 1 ? _boardsSearchExpanded 
        : selectedIndex == 2 ? _plansSearchExpanded 
        : false;
    final searchController = selectedIndex == 1 ? _boardsSearchController
        : selectedIndex == 2 ? _plansSearchController
        : null;
    final onSearchChanged = selectedIndex == 1 ? _boardsSearchChanged
        : selectedIndex == 2 ? _plansSearchChanged
        : null;
    final onSearchClear = selectedIndex == 1 ? _boardsSearchClear
        : selectedIndex == 2 ? _plansSearchClear
        : null;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppTopBar(
        onMenuPressed: _openDrawer,
        onBackPressed: () {
          navigation.selectFromBottomNav(0);
        },
        title: navigation.currentTitle,
        showNotificationButton: showNotificationButton,
        showBackButton: isNotificationsPage,
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
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: navigation.bottomNavIndex ?? 0,
        onTap: (index) {
          navigation.selectFromBottomNav(index);
        },
      ),
    );
  }
}
