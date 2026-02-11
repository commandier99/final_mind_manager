import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../boards/datasources/providers/board_request_provider.dart';
import '../../../boards/datasources/models/board_request_model.dart';
import '../../datasources/providers/in_app_notif_provider.dart';
import '../../datasources/providers/push_notif_provider.dart';
import '../../datasources/models/in_app_notif_model.dart';
import '../../datasources/models/push_notif_model.dart';
import '../widgets/sections/all_notifs_section.dart';
import '../widgets/sections/reminders_section.dart';
import '../widgets/sections/requests_section.dart';
import '../widgets/sections/assignments_section.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String _selectedTab = 'all'; // 'all', 'reminders', 'invites', 'assignments'
  bool _hasInitializedStreams = false;

  @override
  void initState() {
    super.initState();
    _ensureStreamsStarted();
  }

  @override
  Widget build(BuildContext context) {
    _ensureStreamsStarted();
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Row(
              children: [
                _buildTabButton(context, 'All', 'all'),
                _buildTabButton(context, 'Reminders', 'reminders'),
                _buildTabButton(context, 'Invites', 'invites'),
                _buildTabButton(context, 'Assignments', 'assignments'),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refreshNotifications(context),
              child: _buildBody(context),
            ),
          ),
        ],
      ),
    );
  }

  void _ensureStreamsStarted() {
    if (_hasInitializedStreams) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    print('[NotificationsPage] ensureStreams: userId = $userId');

    if (userId == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasInitializedStreams) return;

      _hasInitializedStreams = true;

      // Stream board requests (invitations and join requests)
      print('[NotificationsPage] Streaming board requests...');
      context.read<BoardRequestProvider>().streamInvitationsByUser(userId);
      context.read<BoardRequestProvider>().streamJoinRequestsByUser(userId);

      // Stream in-app notifications
      print('[NotificationsPage] Streaming in-app notifications...');
      context.read<InAppNotificationProvider>().streamNotificationsByUser(userId);

      // Stream push notifications
      print('[NotificationsPage] Streaming push notifications...');
      context.read<PushNotificationProvider>().streamNotificationsByUser(userId);
    });
  }


  Widget _buildBody(BuildContext context) {
    if (_selectedTab == 'all') {
      return buildAllNotificationsSection(
        context,
        () => _refreshNotifications(context),
        _getNotificationDate,
        _buildEmptyState,
      );
    } else if (_selectedTab == 'reminders') {
      return buildRemindersSection(
        context,
        () => _refreshNotifications(context),
        _getNotificationDate,
        _buildEmptyState,
      );
    } else if (_selectedTab == 'invites') {
      return buildRequestsSection(
        context,
        () => _refreshNotifications(context),
        _getNotificationDate,
        _buildEmptyState,
      );
    } else if (_selectedTab == 'assignments') {
      return buildAssignmentsSection(
        context,
        () => _refreshNotifications(context),
        _getNotificationDate,
        _buildEmptyState,
      );
    }
    return const SizedBox.shrink();
  }


  Future<void> _refreshNotifications(BuildContext context) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    context.read<BoardRequestProvider>().streamInvitationsByUser(userId);
    context.read<BoardRequestProvider>().streamJoinRequestsByUser(userId);
    context.read<InAppNotificationProvider>().streamNotificationsByUser(userId);
    context.read<PushNotificationProvider>().streamNotificationsByUser(userId);
  }

  DateTime _getNotificationDate(dynamic notification) {
    if (notification is BoardRequest) {
      return notification.boardReqCreatedAt;
    } else if (notification is InAppNotification) {
      return notification.createdAt;
    } else if (notification is PushNotification) {
      return notification.createdAt;
    }
    return DateTime.now();
  }

  Widget _buildTabButton(BuildContext context, String label, String value) {
    final isSelected = _selectedTab == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = 'No notifications';
    String subtitle = 'You\'re all caught up!';

    if (_selectedTab == 'reminders') {
      message = 'No reminders';
      subtitle = 'No task reminders or due date alerts';
    } else if (_selectedTab == 'invites') {
      message = 'No invites';
      subtitle = 'No sent or received board invitations';
    } else if (_selectedTab == 'assignments') {
      message = 'No assignments';
      subtitle = 'No task assignments or reassignments';
    }

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
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
