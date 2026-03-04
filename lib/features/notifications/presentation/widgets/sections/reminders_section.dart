import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/providers/in_app_notif_provider.dart';
import '../cards/notif_card.dart';

Widget buildRemindersSection(
  BuildContext context,
  Future<void> Function() refreshNotifications,
  DateTime Function(dynamic) getNotificationDate,
  Widget Function() buildEmptyState,
) {
  return Consumer<InAppNotificationProvider>(
    builder: (context, inAppProvider, child) {
      final inAppNotifs = inAppProvider.notifications;

      final displayList = [
        ...inAppNotifs.where((n) => n.category == 'reminder' || n.category == 'task_deadline'),
      ]..sort((a, b) {
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
          return NotificationCard(
            notification: item,
            inAppProvider: inAppProvider,
          );
        },
      );
    },
  );
}
