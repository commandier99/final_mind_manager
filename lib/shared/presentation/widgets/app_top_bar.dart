import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../datasources/providers/navigation_provider.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onMenuPressed;
  final VoidCallback? onSearchPressed;
  final String title;
  final bool showNotificationButton;
  final bool isSearchExpanded;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchClear;

  const AppTopBar({
    super.key,
    this.onMenuPressed,
    this.onSearchPressed,
    this.title = 'Mind Manager',
    this.showNotificationButton = true,
    this.isSearchExpanded = false,
    this.searchController,
    this.onSearchChanged,
    this.onSearchClear,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: isSearchExpanded && searchController != null
          ? TextField(
              controller: searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
              onChanged: onSearchChanged,
            )
          : Text(title),
      backgroundColor: Colors.blue[600],
      foregroundColor: Colors.white,
      leading: isSearchExpanded
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onSearchPressed,
              tooltip: 'Back',
            )
          : IconButton(
              icon: const Icon(Icons.menu),
              onPressed: onMenuPressed,
              tooltip: 'Menu',
            ),
      actions: [
        if (isSearchExpanded && searchController != null && searchController!.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: onSearchClear,
            tooltip: 'Clear',
          )
        else if (!isSearchExpanded)
          ..._buildNormalActions(context),
        const SizedBox(width: 8),
      ],
      elevation: 2,
    );
  }

  List<Widget> _buildNormalActions(BuildContext context) {
    return [
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
          onPressed:
              onSearchPressed ??
              () {
                context.read<NavigationProvider>().selectFromSideMenu(6);
              },
          tooltip: 'Search',
        ),
    ];
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
