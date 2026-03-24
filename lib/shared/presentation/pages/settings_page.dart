import 'package:flutter/material.dart';

import '../../services/app_sound_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _soundsEnabled = true;
  bool _loadingSounds = true;

  @override
  void initState() {
    super.initState();
    _loadSoundPreference();
  }

  Future<void> _loadSoundPreference() async {
    final enabled = await AppSoundService.instance.isEnabled();
    if (!mounted) return;
    setState(() {
      _soundsEnabled = enabled;
      _loadingSounds = false;
    });
  }

  Future<void> _toggleSounds(bool enabled) async {
    await AppSoundService.instance.setEnabled(enabled);
    if (!mounted) return;
    setState(() {
      _soundsEnabled = enabled;
    });
    if (enabled) {
      await AppSoundService.instance.playTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _buildSectionHeader('Account'),
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('Profile Settings'),
          subtitle: const Text('Manage your profile information'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
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
        SwitchListTile(
          secondary: const Icon(Icons.volume_up_outlined),
          title: const Text('App Sounds'),
          subtitle: Text(
            _loadingSounds
                ? 'Loading sound preference...'
                : 'Play feedback sounds for session actions and completions',
          ),
          value: _soundsEnabled,
          onChanged: _loadingSounds ? null : _toggleSounds,
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
