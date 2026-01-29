import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../boards/datasources/models/board_request_model.dart';
import '../../../datasources/models/in_app_notif_model.dart';
import '../../../datasources/models/push_notif_model.dart';
import '../../../datasources/providers/in_app_notif_provider.dart';
import '../../../datasources/providers/push_notif_provider.dart';
import '../../../../boards/datasources/providers/board_request_provider.dart';

/// Reusable notification card widget that handles all notification types
class NotificationCard extends StatefulWidget {
  final dynamic notification;
  final InAppNotificationProvider? inAppProvider;
  final PushNotificationProvider? pushProvider;
  final BoardRequestProvider? boardProvider;
  final VoidCallback? onAcceptInvite;
  final VoidCallback? onDeclineInvite;

  const NotificationCard({
    required this.notification,
    this.inAppProvider,
    this.pushProvider,
    this.boardProvider,
    this.onAcceptInvite,
    this.onDeclineInvite,
    super.key,
  });

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.notification is BoardRequest) {
      return _buildBoardRequestCard(context, widget.notification as BoardRequest);
    } else if (widget.notification is InAppNotification) {
      return _buildInAppNotifCard(context, widget.notification as InAppNotification);
    } else if (widget.notification is PushNotification) {
      return _buildPushNotifCard(context, widget.notification as PushNotification);
    }
    return const SizedBox.shrink();
  }

  // Board Request Card - Expandable version
  Widget _buildBoardRequestCard(BuildContext context, BoardRequest request) {
    final isInvitation = request.requestType == 'invitation';
    final isPending = request.requestStatus == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: isPending ? () => setState(() => _isExpanded = !_isExpanded) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row - Always visible
              Row(
                children: [
                  Icon(
                    isInvitation ? Icons.mail : Icons.send,
                    color: isInvitation ? Colors.blue : Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isInvitation ? 'Board Invitation' : 'Join Request',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          request.boardTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(request.requestStatus),
                  if (isPending) ...[
                    const SizedBox(width: 8),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey[600],
                    ),
                  ],
                ],
              ),

              // Expanded Content
              if (_isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                
                // From/Requester info
                if (isInvitation)
                  Text(
                    'From: ${request.boardManagerName}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                
                // Message
                if (request.requestMessage != null &&
                    request.requestMessage!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      request.requestMessage!,
                      style: TextStyle(color: Colors.grey[800], fontSize: 14),
                    ),
                  ),
                ],

                // Timestamp
                const SizedBox(height: 12),
                Text(
                  timeago.format(request.requestCreatedAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),

                // Action Buttons
                if (isPending && isInvitation) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: widget.onAcceptInvite,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Accept'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showDeclineDialog(context, request),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Decline'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Show dialog to get decline reason
  void _showDeclineDialog(BuildContext context, BoardRequest request) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Decline Invitation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to decline the invitation to ${request.boardTitle}?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Optional: Tell them why you\'re declining',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'E.g., "Too busy right now" or "Not interested in this project"',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _submitDecline(context, request, reasonController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  /// Submit the decline with reason
  Future<void> _submitDecline(
    BuildContext context,
    BoardRequest request,
    String reason,
  ) async {
    try {
      final boardProvider = widget.boardProvider;
      if (boardProvider == null) return;

      await boardProvider.rejectRequest(
        request,
        responseMessage: reason.isNotEmpty ? reason : 'Declined without reason',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation declined'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isExpanded = false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining invitation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // In-App Notification Card
  Widget _buildInAppNotifCard(BuildContext context, InAppNotification notif) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications_active,
                  color: notif.isRead ? Colors.grey : Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notif.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
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
            const SizedBox(height: 12),
            Text(
              notif.message,
              style: TextStyle(color: Colors.grey[800], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              timeago.format(notif.createdAt),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            if (!notif.isRead && widget.inAppProvider != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () =>
                    widget.inAppProvider!.markAsRead(notif.notificationId),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Mark as Read'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Push Notification Card
  Widget _buildPushNotifCard(BuildContext context, PushNotification notif) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications,
                  color: notif.isSent ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notif.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
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
            const SizedBox(height: 12),
            Text(
              notif.body,
              style: TextStyle(color: Colors.grey[800], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              timeago.format(notif.createdAt),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            if (notif.lastError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  'Error: ${notif.lastError}',
                  style: TextStyle(color: Colors.red[700], fontSize: 12),
                ),
              ),
            ],
          ],
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
