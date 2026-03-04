import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../boards/datasources/providers/board_request_provider.dart';
import '../../../boards/datasources/models/board_request_model.dart';
import '../../datasources/providers/in_app_notif_provider.dart';
import '../../datasources/models/in_app_notif_model.dart';
import '../../datasources/models/push_notif_model.dart';
import '../widgets/sections/all_notifs_section.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final Set<String> _selectedFilters = <String>{};
  bool _hasInitializedStreams = false;
  static const Map<String, String> _filterLabels = {
    notifFilterPokes: 'Pokes',
    notifFilterReminders: 'Reminders',
    notifFilterAssignments: 'Assignments',
    notifFilterSubmissions: 'Submissions',
    notifFilterSuggestions: 'Suggestions',
    notifFilterInvites: 'Invites',
  };

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
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'All Notifications',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Filter notifications',
                  onSelected: (value) {
                    setState(() {
                      if (_selectedFilters.contains(value)) {
                        _selectedFilters.remove(value);
                      } else {
                        _selectedFilters.add(value);
                      }
                    });
                  },
                  itemBuilder: (context) => _filterLabels.entries
                      .map(
                        (entry) => CheckedPopupMenuItem<String>(
                          value: entry.key,
                          checked: _selectedFilters.contains(entry.key),
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  child: _buildHeaderIcon(
                    icon: Icons.filter_list,
                    label: _selectedFilters.isEmpty
                        ? 'Filter'
                        : 'Filter (${_selectedFilters.length})',
                  ),
                ),
                if (_selectedFilters.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(_selectedFilters.clear),
                    borderRadius: BorderRadius.circular(8),
                    child: _buildHeaderIcon(
                      icon: Icons.clear_all,
                      label: 'Clear',
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_selectedFilters.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: _selectedFilters
                    .map(
                      (key) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InputChip(
                          label: Text(_filterLabels[key] ?? key),
                          onDeleted: () {
                            setState(() {
                              _selectedFilters.remove(key);
                            });
                          },
                        ),
                      ),
                    )
                    .toList(),
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
      context.read<BoardRequestProvider>().streamInvitationsSentByManager(
        userId,
      );
      context.read<BoardRequestProvider>().streamJoinRequestsByUser(userId);

      // Stream in-app notifications
      print('[NotificationsPage] Streaming in-app notifications...');
      context.read<InAppNotificationProvider>().streamNotificationsByUser(
        userId,
      );
    });
  }

  Widget _buildBody(BuildContext context) {
    return buildAllNotificationsSection(
      context,
      () => _refreshNotifications(context),
      _getNotificationDate,
      _buildEmptyState,
      _selectedFilters,
    );
  }

  Future<void> _refreshNotifications(BuildContext context) async {
    _ensureStreamsStarted();
    await Future<void>.delayed(const Duration(milliseconds: 350));
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

  Widget _buildHeaderIcon({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _selectedFilters.isNotEmpty;
    final selectedNames = _selectedFilters
        .map((key) => _filterLabels[key] ?? key)
        .toList();
    final subtitle = isFiltered
        ? 'No items for: ${selectedNames.join(', ')}'
        : 'You\'re all caught up!';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            isFiltered ? 'No matching notifications' : 'No notifications',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
