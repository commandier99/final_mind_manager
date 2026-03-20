import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/datasources/providers/navigation_provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../datasources/models/notification_model.dart';
import '../../datasources/providers/notification_provider.dart';
import '../widgets/cards/notification_card.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isAutoMarkingRead = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId = context.read<UserProvider>().userId;
      if (userId != null && userId.isNotEmpty) {
        context.read<NotificationProvider>().streamNotificationsForUser(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isActivePage = context.watch<NavigationProvider>().selectedIndex == 6;

    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        if (isActivePage) {
          _autoMarkVisibleNotificationsAsRead(provider);
        }
        final visibleNotifications = provider.notifications;
        final listItems = _buildListItems(visibleNotifications);

        if (provider.isLoading && provider.notifications.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.notifications.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                provider.error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: visibleNotifications.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No notifications yet.',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: listItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = listItems[index];
                        if (item.header != null) {
                          return _DaySeparator(label: item.header!);
                        }
                        final notification = item.notification!;
                        return NotificationCard(
                          notification: notification,
                          onOpen: () => _openNotification(notification),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _autoMarkVisibleNotificationsAsRead(NotificationProvider provider) {
    if (_isAutoMarkingRead || provider.unreadCount == 0) return;
    _isAutoMarkingRead = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (!mounted) return;
        await context.read<NotificationProvider>().markAllAsRead();
      } finally {
        _isAutoMarkingRead = false;
      }
    });
  }

  List<_NotificationListItem> _buildListItems(
    List<AppNotification> notifications,
  ) {
    final items = <_NotificationListItem>[];
    String? previousBucket;

    for (final notification in notifications) {
      final bucket = _dayBucket(notification.createdAt);
      if (bucket != previousBucket) {
        previousBucket = bucket;
        items.add(_NotificationListItem.header(_dayLabel(notification.createdAt)));
      }
      items.add(_NotificationListItem.notification(notification));
    }

    return items;
  }

  String _dayBucket(DateTime value) =>
      '${value.year}-${value.month}-${value.day}';

  String _dayLabel(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(value.year, value.month, value.day);
    final difference = today.difference(target).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    return '${value.month}/${value.day}/${value.year}';
  }

  void _openNotification(AppNotification notification) {
    final thoughtId = (notification.thoughtId ?? '').trim();
    if (thoughtId.isNotEmpty) {
      context.read<NavigationProvider>().openThoughts(
        thoughtId: thoughtId,
        thoughtType: _thoughtTypeForNotification(notification.type),
      );
      return;
    }
  }

  String? _thoughtTypeForNotification(String type) {
    final normalized = type.trim().toLowerCase();
    if (normalized.startsWith('thought_board_')) return 'board_request';
    if (normalized.startsWith('thought_task_assignment_') ||
        normalized.startsWith('thought_task_request_')) {
      return 'task_assignment';
    }
    if (normalized.startsWith('thought_deadline_extension_request_')) {
      return 'task_request';
    }
    if (normalized.startsWith('thought_submission_')) {
      return 'submission_feedback';
    }
    return null;
  }
}

class _NotificationListItem {
  const _NotificationListItem._({this.header, this.notification});

  const _NotificationListItem.header(String value)
    : this._(header: value);

  const _NotificationListItem.notification(AppNotification value)
    : this._(notification: value);

  final String? header;
  final AppNotification? notification;
}

class _DaySeparator extends StatelessWidget {
  const _DaySeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Divider(color: theme.colorScheme.outlineVariant),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: theme.colorScheme.outlineVariant),
        ),
      ],
    );
  }
}
