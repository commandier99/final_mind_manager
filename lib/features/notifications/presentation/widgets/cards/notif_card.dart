import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../boards/datasources/models/board_request_model.dart';
import '../../../datasources/models/in_app_notif_model.dart';
import '../../../datasources/models/push_notif_model.dart';
import '../../../datasources/providers/in_app_notif_provider.dart';
import '../../../datasources/providers/push_notif_provider.dart';

/// Reusable notification card widget that displays basic info
/// Navigates to NotificationDetailsPage on tap where full details and actions are available
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

  /// Navigate to details page and mark as read if applicable
  Future<void> _navigateToDetails(BuildContext context) async {
    // Mark as read when viewing details
    if (notification is InAppNotification) {
      final notif = notification as InAppNotification;
      if (!notif.isRead && inAppProvider != null) {
        await inAppProvider!.markAsRead(notif.notificationId);
      }
    }

    if (context.mounted) {
      // Use the page route to avoid import issues at top level
      // The NotificationDetailsPage will handle different notification types
      _showDetailsPage(context);
    }
  }

  /// Show the details page for this notification
  void _showDetailsPage(BuildContext context) {
    // Create a custom route that loads the details page on demand
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return _buildDetailsContent(sheetContext);
      },
    );
  }

  /// Build details content based on notification type
  /// This will be expanded later as a full page
  Widget _buildDetailsContent(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          AppBar(
            title: const Text('Notification Details'),
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildNotificationDetails(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the specific notification details
  Widget _buildNotificationDetails() {
    if (notification is BoardRequest) {
      return _buildBoardRequestDetails(notification as BoardRequest);
    } else if (notification is InAppNotification) {
      return _buildInAppNotificationDetails(notification as InAppNotification);
    } else if (notification is PushNotification) {
      return _buildPushNotificationDetails(notification as PushNotification);
    }
    return const SizedBox.shrink();
  }

  /// TODO: Implement board request details view
  Widget _buildBoardRequestDetails(BoardRequest request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          request.boardTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          'Status: ${request.boardReqStatus}',
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 8),
        Text(
          'Message: ${request.boardReqMessage ?? 'No message'}',
          style: const TextStyle(fontSize: 14),
        ),
        // More details to be implemented
      ],
    );
  }

  /// TODO: Implement in-app notification details view
  Widget _buildInAppNotificationDetails(InAppNotification notif) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notif.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          notif.message,
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 16),
        // TODO: Implement mark as unread and log activity
        ElevatedButton.icon(
          onPressed: () {
            // Mark as unread action and log as user activity
          },
          icon: const Icon(Icons.mail_outline),
          label: const Text('Mark as Unread'),
        ),
        // More details to be implemented
      ],
    );
  }

  /// TODO: Implement push notification details view
  Widget _buildPushNotificationDetails(PushNotification notif) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          notif.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          notif.body,
          style: const TextStyle(fontSize: 14),
        ),
        // More details to be implemented
      ],
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
