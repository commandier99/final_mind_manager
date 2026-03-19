import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/providers/in_app_notif_provider.dart';
import '../../../datasources/models/in_app_notif_model.dart';
import '../cards/notif_card.dart';

const String notifFilterPokes = 'pokes';
const String notifFilterReminders = 'reminders';
const String notifFilterAssignments = 'assignments';
const String notifFilterSubmissions = 'submissions';
const String notifFilterSuggestions = 'suggestions';
const String notifFilterInvites = 'invites';

String _inAppFilterType(InAppNotification notif) {
  final category = (notif.category ?? '').trim();
  final metadata = notif.metadata ?? const <String, dynamic>{};
  final kind = (metadata['kind']?.toString() ?? '').trim().toLowerCase();
  final metadataType =
      (metadata['type']?.toString() ?? '').trim().toLowerCase();

  if (kind == 'poke' || kind == 'poke_reminder') {
    return notifFilterPokes;
  }

  if (metadataType.startsWith('suggestion_') ||
      notif.title.toLowerCase().contains('suggestion')) {
    return notifFilterSuggestions;
  }

  if (category == 'task_assigned') return notifFilterAssignments;
  if (category == 'approval') return notifFilterSubmissions;
  if (category == 'invitation') return notifFilterInvites;
  if (category == 'reminder' || category == 'task_deadline') {
    return notifFilterReminders;
  }

  return 'other';
}

Widget buildAllNotificationsSection(
  BuildContext context,
  Future<void> Function() refreshNotifications,
  DateTime Function(dynamic) getNotificationDate,
  Widget Function() buildEmptyState,
  Set<String> selectedFilters,
) {
  return Consumer<InAppNotificationProvider>(
    builder: (context, inAppProvider, child) {
      var inAppNotifs = inAppProvider.notifications;

      final hasActiveFilter = selectedFilters.isNotEmpty;
      if (hasActiveFilter) {
        inAppNotifs = inAppNotifs
            .where((n) => selectedFilters.contains(_inAppFilterType(n)))
            .toList();
      }

      final displayList = <dynamic>[...inAppNotifs];

      displayList.sort((a, b) {
        DateTime dateA = getNotificationDate(a);
        DateTime dateB = getNotificationDate(b);
        return dateB.compareTo(dateA);
      });

      final groupedItems = <dynamic>[];
      String? lastDayLabel;
      for (final item in displayList) {
        final currentDayLabel = _relativeDayLabel(getNotificationDate(item));
        if (currentDayLabel != lastDayLabel) {
          groupedItems.add(_NotificationDayHeader(currentDayLabel));
          lastDayLabel = currentDayLabel;
        }
        groupedItems.add(item);
      }

      if (displayList.isEmpty) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: buildEmptyState(),
            ),
          ],
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedItems.length,
        itemBuilder: (context, index) {
          final item = groupedItems[index];

          if (item is _NotificationDayHeader) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[700],
                ),
              ),
            );
          }

          if (item is InAppNotification) {
            return NotificationCard(
              notification: item,
              inAppProvider: inAppProvider,
            );
          }

          return const SizedBox.shrink();
        },
      );
    },
  );
}

String _relativeDayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final diff = today.difference(target).inDays;

  if (diff <= 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '$diff Days Ago';
}

class _NotificationDayHeader {
  final String label;
  const _NotificationDayHeader(this.label);
}
