import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../features/authentication/datasources/providers/authentication_provider.dart';
import '../../features/users/datasources/providers/user_provider.dart';
import '../../datasources/providers/navigation_provider.dart';

class AppSideMenu extends StatelessWidget {
  final ValueChanged<int>? onSelect;

  const AppSideMenu({super.key, this.onSelect});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).colorScheme.onPrimary,
                  backgroundImage: user?.userProfilePicture != null
                      ? NetworkImage(user!.userProfilePicture!)
                      : null,
                  child: user?.userProfilePicture == null
                      ? Icon(
                          Icons.person,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  user?.userName ?? 'User Name',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user?.userEmail ?? 'user@example.com',
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);
              onSelect?.call(4);
              context.read<NavigationProvider>().selectFromSideMenu(4);
            },
          ),
          ListTile(
            leading: const Icon(Icons.explore),
            title: const Text('Search & Discover'),
            onTap: () {
              Navigator.pop(context);
              onSelect?.call(6);
              context.read<NavigationProvider>().selectFromSideMenu(6);
            },
          ),
          ListTile(
            leading: const Icon(Icons.psychology_outlined),
            title: const Text('Mind:Set'),
            onTap: () {
              Navigator.pop(context);
              onSelect?.call(10);
              context.read<NavigationProvider>().selectFromSideMenu(10);
            },
          ),
          ListTile(
            leading: const Icon(Icons.memory_outlined),
            title: const Text('Memory Bank'),
            onTap: () {
              Navigator.pop(context);
              onSelect?.call(11);
              context.read<NavigationProvider>().openMemoryBank();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              onSelect?.call(7);
              context.read<NavigationProvider>().selectFromSideMenu(7);
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help/FAQ'),
            onTap: () {
              Navigator.pop(context);
              onSelect?.call(8);
              context.read<NavigationProvider>().selectFromSideMenu(8);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);
              onSelect?.call(9);
              context.read<NavigationProvider>().selectFromSideMenu(9);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () async {
              final rootNavigator = Navigator.of(context, rootNavigator: true);
              final authProvider = Provider.of<AuthenticationProvider>(
                context,
                listen: false,
              );
              final userProvider = Provider.of<UserProvider>(
                context,
                listen: false,
              );
              final navigationProvider = Provider.of<NavigationProvider>(
                context,
                listen: false,
              );

              // Close drawer first; use captured references afterwards.
              Navigator.of(context).pop();

              // Sign out and clear user/session state.
              await authProvider.signOut();
              await userProvider.signOut();
              navigationProvider.selectFromBottomNav(0);

              // Navigate to auth screen and remove all previous routes.
              rootNavigator.pushNamedAndRemoveUntil('/auth', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}
