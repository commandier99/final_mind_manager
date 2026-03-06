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
  final ValueChanged<VoidCallback>? onFilterPressedReady;

  const NotificationsPage({
    super.key,
    this.onFilterPressedReady,
  });

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onFilterPressedReady?.call(_openFilterSheet);
    });
  }

  @override
  Widget build(BuildContext context) {
    _ensureStreamsStarted();
    return Column(
      children: [
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
    );
  }

  Future<void> _openFilterSheet() async {
    final tempSelection = Set<String>.from(_selectedFilters);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Notifications',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._filterLabels.entries.map((entry) {
                      final checked = tempSelection.contains(entry.key);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(entry.value),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (_) {
                          setModalState(() {
                            if (checked) {
                              tempSelection.remove(entry.key);
                            } else {
                              tempSelection.add(entry.key);
                            }
                          });
                        },
                      );
                    }),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(tempSelection.clear);
                          },
                          child: const Text('Clear All'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            if (!mounted) return;
                            setState(() {
                              _selectedFilters
                                ..clear()
                                ..addAll(tempSelection);
                            });
                            Navigator.of(sheetContext).pop();
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _ensureStreamsStarted() {
    if (_hasInitializedStreams) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('[NotificationsPage] ensureStreams: userId = $userId');

    if (userId == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasInitializedStreams) return;

      _hasInitializedStreams = true;

      // Stream board requests (invitations and join requests)
      debugPrint('[NotificationsPage] Streaming board requests...');
      context.read<BoardRequestProvider>().streamInvitationsByUser(userId);
      context.read<BoardRequestProvider>().streamInvitationsSentByManager(
        userId,
      );
      context.read<BoardRequestProvider>().streamJoinRequestsByUser(userId);

      // Stream in-app notifications
      debugPrint('[NotificationsPage] Streaming in-app notifications...');
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
