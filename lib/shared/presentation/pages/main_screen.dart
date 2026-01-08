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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Pages aligned with NavigationProvider.titles indexes
  final List<Widget> _pages = const [
    HomePage(),
    BoardsPage(),
    PlansPage(),
    DashboardPage(),
    ProfilePage(),
    NotificationsPage(),
    SearchDiscoverPage(),
    SettingsPage(),
    HelpPage(),
    AboutPage(),
  ];

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<NavigationProvider>();
    final selectedIndex = navigation.selectedIndex;
    final showNotificationButton = selectedIndex == 0 || navigation.sideMenuIndex != null;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppTopBar(
        onMenuPressed: _openDrawer,
        title: navigation.currentTitle,
        showNotificationButton: showNotificationButton,
      ),
      drawer: AppSideMenu(
        onSelect: (idx) {
          navigation.selectFromSideMenu(idx);
          Navigator.pop(context);
        },
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: navigation.bottomNavIndex ?? 0,
        onTap: (index) {
          navigation.selectFromBottomNav(index);
        },
      ),
    );
  }
}
