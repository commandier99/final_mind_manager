import 'package:flutter/material.dart';

import '../../../datasources/models/notification_model.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    this.onOpen,
  });

  final AppNotification notification;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: notification.isRead
          ? theme.colorScheme.surface
          : theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: notification.isRead
              ? theme.colorScheme.outlineVariant
              : theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        _iconForType(notification.type),
                        size: 34,
                        color: theme.colorScheme.primary,
                      ),
                      if (!notification.isRead)
                        Positioned(
                          top: -1,
                          right: -1,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: notification.isRead
                                ? FontWeight.w700
                                : FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.message,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _formatTimestamp(notification.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!notification.isRead)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.chevron_right, size: 22),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime value) {
    final now = DateTime.now();
    final difference = now.difference(value);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${value.month}/${value.day}/${value.year}';
  }

  IconData _iconForType(String type) {
    switch (type.trim().toLowerCase()) {
      case 'thought_board_invite_sent':
      case 'thought_board_invite_received':
      case 'thought_board_invite_accepted':
      case 'thought_board_invite_declined':
        return Icons.group_add_outlined;
      case 'thought_board_request_sent':
      case 'thought_board_request_received':
      case 'thought_board_request_accepted':
      case 'thought_board_request_declined':
        return Icons.meeting_room_outlined;
      case 'thought_task_assignment_sent':
      case 'thought_task_assignment_received':
        return Icons.assignment_ind_outlined;
      case 'thought_task_request_sent':
      case 'thought_task_request_received':
      case 'thought_deadline_extension_request_sent':
      case 'thought_deadline_extension_request_received':
        return Icons.schedule_outlined;
      case 'thought_submission_sent':
      case 'thought_submission_received':
      case 'thought_submission_reviewed_approved':
      case 'thought_submission_reviewed_rejected':
        return Icons.upload_file_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}
