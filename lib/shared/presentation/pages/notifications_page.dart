import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/notifications/datasources/providers/notification_provider.dart';
import '../../features/notifications/datasources/models/notification_model.dart';
import '../../features/users/datasources/providers/user_provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<UserProvider>().userId;
      if (userId != null) {
        context.read<NotificationProvider>().loadNotifications(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<UserProvider>().userId;
    
    return Consumer<NotificationProvider>(
      builder: (context, notifProvider, _) {
        if (notifProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (notifProvider.notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No notifications yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You\'ll see updates about your tasks here',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            if (userId != null) {
              await notifProvider.loadNotifications(userId);
            }
          },
          child: ListView.separated(
            itemCount: notifProvider.notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifProvider.notifications[index];
              return _buildNotificationTile(notification, userId);
            },
          ),
        );
      },
    );
  }

  Widget _buildNotificationTile(AppNotification notification, String? userId) {
    final notifProvider = context.read<NotificationProvider>();
    
    return Dismissible(
      key: Key(notification.notifId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) async {
        if (userId != null) {
          await notifProvider.deleteNotification(notification.notifId, userId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Notification deleted'),
                action: SnackBarAction(
                  label: 'Undo',
                  onPressed: () {
                    // Could implement undo functionality
                  },
                ),
              ),
            );
          }
        }
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.notifIsRead 
              ? Colors.grey[300] 
              : _getNotificationColor(notification.notifType),
          child: Icon(
            _getNotificationIcon(notification.notifType),
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          notification.notifTitle,
          style: TextStyle(
            fontWeight: notification.notifIsRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.notifMessage),
            const SizedBox(height: 4),
            Text(
              timeago.format(notification.notifCreatedAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            if (notification.notifBoardTitle != null) ...[
              const SizedBox(height: 4),
              Text(
                'Board: ${notification.notifBoardTitle}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        trailing: notification.notifIsRead 
            ? null 
            : Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () async {
          if (!notification.notifIsRead && userId != null) {
            await notifProvider.markAsRead(notification.notifId, userId);
          }
          
          // Handle notification tap based on type
          if (notification.notifTaskId != null) {
            // Could navigate to task details
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Navigate to task: ${notification.notifTaskId}')),
              );
            }
          }
        },
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'due_today':
        return Icons.today;
      case 'overdue':
        return Icons.warning;
      case 'assigned':
      case 'task_request':
        return Icons.assignment;
      case 'general':
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'due_today':
        return Colors.orange;
      case 'overdue':
        return Colors.red;
      case 'assigned':
      case 'task_request':
        return Colors.blue;
      case 'general':
      default:
        return Colors.grey;
    }
  }
}
