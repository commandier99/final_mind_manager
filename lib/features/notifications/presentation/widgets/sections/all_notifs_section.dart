import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../boards/datasources/providers/board_request_provider.dart';
import '../../../../boards/datasources/models/board_request_model.dart';
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
  return Consumer2<BoardRequestProvider, InAppNotificationProvider>(
    builder: (context, boardProvider, inAppProvider, child) {
      final recruitments = boardProvider.invitations;
      final sentRecruitments = boardProvider.sentInvitations;
      final applications = boardProvider.joinRequests;
      var inAppNotifs = inAppProvider.notifications;

      final hasActiveFilter = selectedFilters.isNotEmpty;
      if (hasActiveFilter) {
        inAppNotifs = inAppNotifs
            .where((n) => selectedFilters.contains(_inAppFilterType(n)))
            .toList();
      }

      final boardRequestItems = <dynamic>[
        ...recruitments,
        ...sentRecruitments,
        ...applications,
      ];

      final filteredBoardRequestItems = hasActiveFilter
          ? (selectedFilters.contains(notifFilterInvites)
                ? boardRequestItems
                : <dynamic>[])
          : boardRequestItems;

      final displayList = <dynamic>[
        ...filteredBoardRequestItems,
        ...inAppNotifs,
      ];

      final seenBoardRequestIds = <String>{};
      displayList.removeWhere((item) {
        if (item is! BoardRequest) return false;
        if (seenBoardRequestIds.contains(item.boardRequestId)) return true;
        seenBoardRequestIds.add(item.boardRequestId);
        return false;
      });

      displayList.sort((a, b) {
        DateTime dateA = getNotificationDate(a);
        DateTime dateB = getNotificationDate(b);
        return dateB.compareTo(dateA);
      });

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
        itemCount: displayList.length,
        itemBuilder: (context, index) {
          final item = displayList[index];

          if (item is BoardRequest) {
            return NotificationCard(notification: item);
          } else if (item is InAppNotification) {
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
