import 'package:flutter/material.dart';
import '../../datasources/models/notification_model.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const NotificationCard({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: notification.notifIsRead ? 1 : 3,
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
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: onTap,
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
