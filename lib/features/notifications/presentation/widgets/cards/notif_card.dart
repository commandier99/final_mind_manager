import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  _NotifVisual _inAppVisual(InAppNotification notif) {
    final category = (notif.category ?? '').trim().toLowerCase();
    final metadata = notif.metadata ?? const <String, dynamic>{};
    final kind = (metadata['kind']?.toString() ?? '').trim().toLowerCase();
    final type = (metadata['type']?.toString() ?? '').trim().toLowerCase();
    final title = notif.title.toLowerCase();

    if (kind == 'poke' || kind == 'poke_reminder') {
      return const _NotifVisual(
        icon: Icons.markunread_mailbox_outlined,
        color: Color(0xFF8E24AA),
      );
    }
    if (type.startsWith('suggestion_') || title.contains('suggestion')) {
      return const _NotifVisual(
        icon: Icons.lightbulb_outline,
        color: Color(0xFFFFA000),
      );
    }
    if (category == 'task_assigned') {
      return const _NotifVisual(
        icon: Icons.assignment_ind_outlined,
        color: Color(0xFF1E88E5),
      );
    }
    if (category == 'approval') {
      return const _NotifVisual(
        icon: Icons.fact_check_outlined,
        color: Color(0xFF00897B),
      );
    }
    if (category == 'invitation') {
      return const _NotifVisual(
        icon: Icons.mail_outline,
        color: Color(0xFF3949AB),
      );
    }
    if (category == 'task_deadline') {
      return const _NotifVisual(
        icon: Icons.schedule_outlined,
        color: Color(0xFFE53935),
      );
    }
    if (category == 'reminder') {
      return const _NotifVisual(
        icon: Icons.notifications_active_outlined,
        color: Color(0xFFF4511E),
      );
    }
    return const _NotifVisual(
      icon: Icons.notifications_none_outlined,
      color: Color(0xFF546E7A),
    );
  }

  _NotifVisual _pushVisual(PushNotification notif) {
    final category = (notif.category ?? '').trim().toLowerCase();
    if (category == 'invitation') {
      return const _NotifVisual(
        icon: Icons.campaign_outlined,
        color: Color(0xFF3949AB),
      );
    }
    if (category == 'approval') {
      return const _NotifVisual(
        icon: Icons.verified_outlined,
        color: Color(0xFF00897B),
      );
    }
    if (category == 'task_assigned') {
      return const _NotifVisual(
        icon: Icons.assignment_late_outlined,
        color: Color(0xFF1E88E5),
      );
    }
    if (category == 'task_deadline') {
      return const _NotifVisual(
        icon: Icons.alarm_outlined,
        color: Color(0xFFE53935),
      );
    }
    return const _NotifVisual(
      icon: Icons.notifications_outlined,
      color: Color(0xFF546E7A),
    );
  }

  // Board Request Card - Basic version
  Widget _buildBoardRequestCard(BuildContext context, BoardRequest request) {
    final isRecruitment =
        BoardRequest.normalizeType(request.boardReqType) ==
        BoardRequest.typeRecruitment;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isSender =
        currentUserId.isNotEmpty && currentUserId == request.boardManagerId;
    final requestLabel = isRecruitment
        ? (isSender ? 'Invite Sent' : 'Invite Received')
        : (isSender ? 'Application Received' : 'Application Sent');
    final secondaryLine = isRecruitment
        ? (isSender
              ? 'To ${request.userName}'
              : 'From ${request.boardManagerName}')
        : (isSender ? 'From ${request.userName}' : 'To ${request.boardTitle}');
    final icon = isRecruitment
        ? (isSender ? Icons.outgoing_mail : Icons.mark_email_unread_outlined)
        : (isSender ? Icons.person_add_alt_1 : Icons.inbox_outlined);
    final iconColor = isRecruitment
        ? (isSender ? const Color(0xFF5E35B1) : const Color(0xFF3949AB))
        : (isSender ? const Color(0xFF00897B) : const Color(0xFF1E88E5));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requestLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      secondaryLine,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(request.boardReqCreatedAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
    final visual = _inAppVisual(notif);
    final iconColor = notif.isRead
        ? Colors.grey.shade500
        : visual.color;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (notif.isRead
                          ? Colors.grey.shade300
                          : visual.color.withValues(alpha: 0.12)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  visual.icon,
                  color: iconColor,
                  size: 20,
                ),
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
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(notif.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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
                    color: notif.isRead ? Colors.grey[600] : Colors.blue[700],
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
    final visual = _pushVisual(notif);
    final iconColor = notif.isSent ? visual.color : Colors.orange.shade700;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: notif.isSent
                      ? visual.color.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  visual.icon,
                  color: iconColor,
                  size: 20,
                ),
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
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(notif.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: notif.isSent ? Colors.green[100] : Colors.orange[100],
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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

class _NotifVisual {
  final IconData icon;
  final Color color;

  const _NotifVisual({
    required this.icon,
    required this.color,
  });
}
