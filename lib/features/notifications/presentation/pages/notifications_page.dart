import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../boards/datasources/providers/board_request_provider.dart';
import '../../../boards/datasources/models/board_request_model.dart';
import '../../datasources/providers/in_app_notif_provider.dart';
import '../../datasources/providers/push_notif_provider.dart';
import '../../datasources/models/in_app_notif_model.dart';
import '../../datasources/models/push_notif_model.dart';
import '../widgets/cards/notif_card.dart';
import '../../../../shared/services/firebase_messaging_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String _selectedTab = 'all'; // 'all', 'reminders', 'invites', 'assignments'

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    print('[NotificationsPage] initState: userId = $userId');
    
    if (userId != null) {
      // Defer stream setup to after build completes to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        
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
  }

  @override
  Widget build(BuildContext context) {
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
            child: _buildBody(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFCMTokenDialog(context),
        icon: const Icon(Icons.notifications_active),
        label: const Text('FCM Token'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showFCMTokenDialog(BuildContext context) async {
    final token = await FirebaseMessagingService().getDeviceToken();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FCM Device Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use this token to send test notifications from Firebase Console:',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                token ?? 'No token available',
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Steps to test:\n'
              '1. Copy the token above\n'
              '2. Go to Firebase Console\n'
              '3. Cloud Messaging → Send test message\n'
              '4. Paste token and send',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (token != null) {
                Clipboard.setData(ClipboardData(text: token));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Token copied to clipboard!')),
                );
              }
            },
            child: const Text('Copy Token'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Consumer3<BoardRequestProvider, InAppNotificationProvider, PushNotificationProvider>(
      builder: (context, boardProvider, inAppProvider, pushProvider, child) {
        // Get all notifications
        final invitations = boardProvider.invitations;
        final joinRequests = boardProvider.joinRequests;
        final inAppNotifs = inAppProvider.notifications;
        final pushNotifs = pushProvider.notifications;

        List<dynamic> displayList = [];

        if (_selectedTab == 'all') {
          displayList = [
            ...invitations,
            ...joinRequests,
            ...inAppNotifs,
            ...pushNotifs,
          ]..sort((a, b) {
            DateTime dateA = _getNotificationDate(a);
            DateTime dateB = _getNotificationDate(b);
            return dateB.compareTo(dateA);
          });
        } else if (_selectedTab == 'reminders') {
          // Filter for reminders and task deadline alerts
          displayList = [
            ...inAppNotifs.where((n) => n.category == 'reminder' || n.category == 'task_deadline'),
            ...pushNotifs.where((n) => n.category == 'reminder' || n.category == 'task_deadline'),
          ]..sort((a, b) {
            DateTime dateA = _getNotificationDate(a);
            DateTime dateB = _getNotificationDate(b);
            return dateB.compareTo(dateA);
          });
        } else if (_selectedTab == 'invites') {
          // Both sent and received invitations
          displayList = [
            ...invitations, // Board invitations received
            ...joinRequests, // Join requests sent
            ...inAppNotifs.where((n) => n.category == 'invitation'),
            ...pushNotifs.where((n) => n.category == 'invitation'),
          ]..sort((a, b) {
            DateTime dateA = _getNotificationDate(a);
            DateTime dateB = _getNotificationDate(b);
            return dateB.compareTo(dateA);
          });
        } else if (_selectedTab == 'assignments') {
          // Task assignments and reassignments
          displayList = [
            ...inAppNotifs.where((n) => n.category == 'task_assigned'),
            ...pushNotifs.where((n) => n.category == 'task_assigned'),
          ]..sort((a, b) {
            DateTime dateA = _getNotificationDate(a);
            DateTime dateB = _getNotificationDate(b);
            return dateB.compareTo(dateA);
          });
        }

        if (displayList.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => _refreshNotifications(context),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: _buildEmptyState(),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => _refreshNotifications(context),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: displayList.length,
            itemBuilder: (context, index) {
              final item = displayList[index];
              
              if (item is BoardRequest) {
                return NotificationCard(
                  notification: item,
                  boardProvider: boardProvider,
                  onAcceptInvite: () =>
                      _handleAcceptInvitation(context, item, boardProvider),
                  onDeclineInvite: () =>
                      _handleDeclineInvitation(context, item, boardProvider),
                );
              } else if (item is InAppNotification) {
                return NotificationCard(
                  notification: item,
                  inAppProvider: inAppProvider,
                );
              } else if (item is PushNotification) {
                return NotificationCard(
                  notification: item,
                  pushProvider: pushProvider,
                );
              }
              
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
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
      return notification.requestCreatedAt;
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

  Future<void> _handleAcceptInvitation(
    BuildContext context,
    BoardRequest request,
    BoardRequestProvider provider,
  ) async {
    try {
      await provider.approveRequest(
        request,
        responseMessage: 'Invitation accepted',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined ${request.boardTitle}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting invitation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDeclineInvitation(
    BuildContext context,
    BoardRequest request,
    BoardRequestProvider provider,
  ) async {
    try {
      await provider.rejectRequest(
        request,
        responseMessage: 'Invitation declined',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation declined'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining invitation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
