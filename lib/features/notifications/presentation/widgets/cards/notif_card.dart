import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../boards/datasources/models/board_request_model.dart';
import '../../../datasources/models/in_app_notif_model.dart';
import '../../../datasources/models/push_notif_model.dart';
import '../../../datasources/providers/in_app_notif_provider.dart';
import '../../../datasources/providers/push_notif_provider.dart';
import '../sheets/notif_details_sheet.dart';

/// Reusable notification card widget that displays basic info
/// Opens the notification details sheet on tap
class NotificationCard extends StatelessWidget {
  final dynamic notification;
  final InAppNotificationProvider? inAppProvider;
  final PushNotificationProvider? pushProvider;

  const NotificationCard({
    required this.notification,
    this.inAppProvider,
    this.pushProvider,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (notification is BoardRequest) {
      return _buildBoardRequestCard(context, notification as BoardRequest);
    } else if (notification is InAppNotification) {
      return _buildInAppNotifCard(context, notification as InAppNotification);
    } else if (notification is PushNotification) {
      return _buildPushNotifCard(context, notification as PushNotification);
    }
    return const SizedBox.shrink();
  }

  /// Navigate to details sheet and mark as read if applicable
  Future<void> _navigateToDetails(BuildContext context) async {
    // Mark as read when viewing details
    if (notification is InAppNotification) {
      final notif = notification as InAppNotification;
      if (!notif.isRead && inAppProvider != null) {
        await inAppProvider!.markAsRead(notif.notificationId);
      }
    }

    if (context.mounted) {
      // The details sheet handles different notification types.
      _showDetailsPage(context);
    }
  }

  /// Show the details sheet for this notification
  void _showDetailsPage(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return NotificationDetailsSheet(notification: notification);
      },
    );
  }

  // Board Request Card - Basic version
  Widget _buildBoardRequestCard(BuildContext context, BoardRequest request) {
    final isRecruitment = request.boardReqType == 'recruitment';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isRecruitment ? Icons.mail : Icons.send,
                color: isRecruitment ? Colors.blue : Colors.green,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRecruitment ? 'Recruitment' : 'Application',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.boardTitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(request.boardReqCreatedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildStatusChip(request.boardReqStatus),
            ],
          ),
        ),
      ),
    );
  }

  // In-App Notification Card - Basic version
  Widget _buildInAppNotifCard(BuildContext context, InAppNotification notif) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: notif.isRead ? Colors.grey : Colors.blue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notif.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(notif.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: notif.isRead ? Colors.grey[200] : Colors.blue[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  notif.isRead ? 'Read' : 'Unread',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: notif.isRead
                        ? Colors.grey[600]
                        : Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Push Notification Card - Basic version
  Widget _buildPushNotifCard(BuildContext context, PushNotification notif) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.notifications,
                color: notif.isSent ? Colors.green : Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notif.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notif.body,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(notif.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: notif.isSent
                      ? Colors.green[100]
                      : Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  notif.isSent ? 'Sent' : 'Pending',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: notif.isSent
                        ? Colors.green[700]
                        : Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'approved':
        color = Colors.green;
        label = 'Approved';
        break;
      case 'rejected':
        color = Colors.red;
        label = 'Declined';
        break;
      default:
        color = Colors.orange;
        label = 'Pending';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
