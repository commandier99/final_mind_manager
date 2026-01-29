import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../boards/datasources/providers/board_request_provider.dart';
import '../../../../boards/datasources/models/board_request_model.dart';
import '../../../datasources/providers/in_app_notif_provider.dart';
import '../../../datasources/providers/push_notif_provider.dart';
import '../../../datasources/models/in_app_notif_model.dart';
import '../../../datasources/models/push_notif_model.dart';
import '../cards/notif_card.dart';

Widget buildRequestsSection(
  BuildContext context,
  Future<void> Function() refreshNotifications,
  DateTime Function(dynamic) getNotificationDate,
  Widget Function() buildEmptyState,
) {
  return Consumer3<BoardRequestProvider, InAppNotificationProvider, PushNotificationProvider>(
    builder: (context, boardProvider, inAppProvider, pushProvider, child) {
      final recruitments = boardProvider.invitations;
      final applications = boardProvider.joinRequests;
      final inAppNotifs = inAppProvider.notifications;
      final pushNotifs = pushProvider.notifications;

      final displayList = [
        ...recruitments,
        ...applications,
        ...inAppNotifs.where((n) => n.category == 'invitation'),
        ...pushNotifs.where((n) => n.category == 'invitation'),
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
            
            if (item is BoardRequest) {
              return NotificationCard(
                notification: item,
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
