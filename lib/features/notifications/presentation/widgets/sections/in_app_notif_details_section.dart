import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../datasources/models/in_app_notif_model.dart';
import '../../../datasources/providers/in_app_notif_provider.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';

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

          // Task assignment action buttons
          if (_isTaskAssignmentNotification(notif)) ...[
            _buildTaskAssignmentActions(context, notif),
            const SizedBox(height: 24),
          ] else ...[
            _buildDebugInfo(notif),
          ],

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

Widget _buildTaskAssignmentActions(
  BuildContext context,
  InAppNotification notif,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Assignment Action',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () =>
                  _handleAcceptTask(context, notif.relatedId!),
              icon: const Icon(Icons.check),
              label: const Text('Accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () =>
                  _handleDeclineTask(context, notif.relatedId!),
              icon: const Icon(Icons.close),
              label: const Text('Decline'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

Future<void> _handleAcceptTask(BuildContext context, String taskId) async {
  final taskProvider = Provider.of<TaskProvider>(context, listen: false);
  try {
    await taskProvider.acceptTask(taskId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Task accepted!'),
          backgroundColor: Colors.green,
        ),
      );
      // Close the details sheet
      Navigator.pop(context);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _handleDeclineTask(BuildContext context, String taskId) async {
  final taskProvider = Provider.of<TaskProvider>(context, listen: false);
  try {
    await taskProvider.declineTask(taskId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Task declined'),
          backgroundColor: Colors.orange,
        ),
      );
      // Close the details sheet
      Navigator.pop(context);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error declining task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

bool _isTaskAssignmentNotification(InAppNotification notif) {
  final isTaskAssigned = notif.category == 'task_assigned';
  final hasTaskId = notif.relatedId != null && notif.relatedId!.isNotEmpty;
  print('[DEBUG] _isTaskAssignmentNotification: category="${notif.category}", relatedId="${notif.relatedId}", isTaskAssigned=$isTaskAssigned, hasTaskId=$hasTaskId');
  return isTaskAssigned && hasTaskId;
}

Widget _buildDebugInfo(InAppNotification notif) {
  print('[DEBUG] Notification debug: category="${notif.category}", relatedId="${notif.relatedId}", title="${notif.title}"');
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.amber[50],
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.amber),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Debug Info:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text('Category: ${notif.category}'),
        Text('RelatedId: ${notif.relatedId ?? "null"}'),
        Text('Is Task Assignment: ${notif.category == "task_assigned"}'),
      ],
    ),
  );
}
