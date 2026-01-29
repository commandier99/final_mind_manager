import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/providers/in_app_notif_provider.dart';
import '../../../datasources/providers/push_notif_provider.dart';
import '../../../datasources/models/in_app_notif_model.dart';
import '../../../datasources/models/push_notif_model.dart';
import '../cards/notif_card.dart';

Widget buildRemindersSection(
  BuildContext context,
  Future<void> Function() refreshNotifications,
  DateTime Function(dynamic) getNotificationDate,
  Widget Function() buildEmptyState,
) {
  return Consumer2<InAppNotificationProvider, PushNotificationProvider>(
    builder: (context, inAppProvider, pushProvider, child) {
      final inAppNotifs = inAppProvider.notifications;
      final pushNotifs = pushProvider.notifications;

      final displayList = [
        ...inAppNotifs.where((n) => n.category == 'reminder' || n.category == 'task_deadline'),
        ...pushNotifs.where((n) => n.category == 'reminder' || n.category == 'task_deadline'),
      ]..sort((a, b) {
        DateTime dateA = getNotificationDate(a);
        DateTime dateB = getNotificationDate(b);
        return dateB.compareTo(dateA);
      });

      if (displayList.isEmpty) {
        return RefreshIndicator(
          onRefresh: refreshNotifications,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: buildEmptyState(),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: refreshNotifications,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: displayList.length,
          itemBuilder: (context, index) {
            final item = displayList[index];
            
            if (item is InAppNotification) {
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
