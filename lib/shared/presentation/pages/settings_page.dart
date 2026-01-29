import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _pushNotificationsEnabled = false;
  bool _reminderNotificationsEnabled = true;
  bool _inviteNotificationsEnabled = true;
  bool _assignmentNotificationsEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotificationsEnabled = prefs.getBool('pushNotifications') ?? false;
      _reminderNotificationsEnabled = prefs.getBool('reminderNotifications') ?? true;
      _inviteNotificationsEnabled = prefs.getBool('inviteNotifications') ?? true;
      _assignmentNotificationsEnabled = prefs.getBool('assignmentNotifications') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _togglePushNotifications(bool value) async {
    if (value) {
      // First check current status
      final currentStatus = await Permission.notification.status;
      print('[SettingsPage] Current notification permission status: $currentStatus');
      
      PermissionStatus status;
      
      // Only request if not already granted
      if (currentStatus.isDenied) {
        print('[SettingsPage] Permission denied, requesting...');
        status = await Permission.notification.request();
        print('[SettingsPage] Notification permission after request: $status');
      } else {
        status = currentStatus;
      }
      
      if (status.isGranted) {
        print('[SettingsPage] Permission granted! Enabling push notifications...');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pushNotifications', true);
        setState(() {
          _pushNotificationsEnabled = true;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Push notifications enabled'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (status.isPermanentlyDenied) {
        print('[SettingsPage] Permission permanently denied');
        if (mounted) {
          setState(() => _pushNotificationsEnabled = false);
          _showPermissionDialog();
        }
      } else if (status.isDenied) {
        print('[SettingsPage] Permission denied by user');
        if (mounted) {
          setState(() => _pushNotificationsEnabled = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission required to enable push notifications'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pushNotifications', false);
      setState(() {
        _pushNotificationsEnabled = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Push notifications disabled'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleCategoryNotifications(String category, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${category}Notifications', value);
    setState(() {
      if (category == 'reminder') {
        _reminderNotificationsEnabled = value;
      } else if (category == 'invite') {
        _inviteNotificationsEnabled = value;
      } else if (category == 'assignment') {
        _assignmentNotificationsEnabled = value;
      }
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value 
              ? '${_getCategoryLabel(category)} notifications enabled' 
              : '${_getCategoryLabel(category)} notifications disabled'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'reminder':
        return 'Reminder';
      case 'invite':
        return 'Invitation';
      case 'assignment':
        return 'Assignment';
      default:
        return 'Notification';
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Permission'),
        content: const Text(
          'Notification permission has been permanently denied. '
          'Please enable it in your device settings to receive push notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
        children: [
          _buildSectionHeader('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active),
            title: const Text('Push Notifications'),
            subtitle: const Text('Receive push notifications on your device'),
            value: _pushNotificationsEnabled,
            onChanged: _togglePushNotifications,
          ),
          const Divider(),
          _buildSectionHeader('Notification Categories'),
          SwitchListTile(
            secondary: const Icon(Icons.alarm),
            title: const Text('Task Reminders'),
            subtitle: const Text('Notifications for upcoming task deadlines'),
            value: _reminderNotificationsEnabled,
            onChanged: (value) => _toggleCategoryNotifications('reminder', value),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.mail_outline),
            title: const Text('Board Invitations'),
            subtitle: const Text('Notifications for board invitations'),
            value: _inviteNotificationsEnabled,
            onChanged: (value) => _toggleCategoryNotifications('invite', value),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.assignment),
            title: const Text('Task Assignments'),
            subtitle: const Text('Notifications when tasks are assigned to you'),
            value: _assignmentNotificationsEnabled,
            onChanged: (value) => _toggleCategoryNotifications('assignment', value),
          ),
          const Divider(),
          
          _buildSectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile Settings'),
            subtitle: const Text('Manage your profile information'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigate to profile
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile settings coming soon')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Privacy & Security'),
            subtitle: const Text('Manage privacy and security settings'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy settings coming soon')),
              );
            },
          ),
          const Divider(),
          
          _buildSectionHeader('App'),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            subtitle: const Text('Light mode (default)'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Theme settings coming soon')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: const Text('English (default)'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Language settings coming soon')),
              );
            },
          ),
          const Divider(),
          
          _buildSectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Terms of service coming soon')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Privacy policy coming soon')),
              );
            },
          ),
        ],
      );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
