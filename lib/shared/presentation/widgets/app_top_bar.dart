import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../datasources/providers/navigation_provider.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onMenuPressed;
  final String title;
  final bool showNotificationButton;

  const AppTopBar({
    super.key,
    this.onMenuPressed,
    this.title = 'Mind Manager',
    this.showNotificationButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      backgroundColor: Colors.blue[600],
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: onMenuPressed,
        tooltip: 'Menu',
      ),
      actions: [
        if (showNotificationButton)
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              context.read<NavigationProvider>().selectFromSideMenu(5);
            },
            tooltip: 'Notifications',
          )
        else
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              context.read<NavigationProvider>().selectFromSideMenu(6);
            },
            tooltip: 'Search',
          ),
        const SizedBox(width: 8),
      ],
      elevation: 2,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
