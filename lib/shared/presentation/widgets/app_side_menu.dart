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
                    color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
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
              Navigator.pop(context);
              
              final authProvider = Provider.of<AuthenticationProvider>(
                context,
                listen: false,
              );
              
              // Sign out and clear all user data
              await authProvider.signOut();
              
              if (context.mounted) {
                // Navigate to auth screen and remove all previous routes
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/auth',
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
