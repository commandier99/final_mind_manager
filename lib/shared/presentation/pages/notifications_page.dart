import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: ListView(
        children: [
          // TODO: Add actual notifications
          ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.notifications),
            ),
            title: const Text('Welcome to Mind Manager!'),
            subtitle: const Text('Start organizing your tasks and plans.'),
            trailing: const Text('Just now'),
            onTap: () {
              // TODO: Handle notification tap
            },
          ),
          const Divider(),
        ],
      ),
    );
  }
}
