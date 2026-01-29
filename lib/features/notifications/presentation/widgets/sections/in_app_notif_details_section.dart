import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../datasources/models/in_app_notif_model.dart';
import '../../../datasources/providers/in_app_notif_provider.dart';

Widget buildInAppNotificationDetailsSection(
  BuildContext context,
  InAppNotification notif,
) {
  return Consumer<InAppNotificationProvider>(
    builder: (context, provider, child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: notif.isRead ? Colors.grey : Colors.blue,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      notif.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: notif.isRead ? Colors.grey[200] : Colors.blue[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  notif.isRead ? 'Read' : 'Unread',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color:
                        notif.isRead ? Colors.grey[600] : Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Message
          const Text(
            'Message',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              notif.message,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Category and Date
          _buildInfoRow(
            icon: Icons.label,
            label: 'Category',
            value: (notif.category ?? 'general').toUpperCase(),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.access_time,
            label: 'Sent',
            value: timeago.format(notif.createdAt),
          ),
          const SizedBox(height: 24),

          // Actions
          Column(
            children: [
              if (notif.isRead)
                ElevatedButton.icon(
                  onPressed: () => _handleMarkAsUnread(context, notif, provider),
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Mark as Unread'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => _handleMarkAsRead(context, notif, provider),
                  icon: const Icon(Icons.mark_email_read),
                  label: const Text('Mark as Read'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}

Widget _buildInfoRow({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Row(
    children: [
      Icon(icon, size: 20, color: Colors.grey[600]),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ],
  );
}

Future<void> _handleMarkAsRead(
  BuildContext context,
  InAppNotification notif,
  InAppNotificationProvider provider,
) async {
  try {
    await provider.markAsRead(notif.notificationId);
    // Log activity: mark as read
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marked as read'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _handleMarkAsUnread(
  BuildContext context,
  InAppNotification notif,
  InAppNotificationProvider provider,
) async {
  try {
    // TODO: Implement markAsUnread in provider
    // For now, we'll show a message that this action will be available
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mark as unread will be available soon'),
        backgroundColor: Colors.orange,
      ),
    );
    // Log activity: mark as unread
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
