import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../boards/datasources/providers/board_request_provider.dart';
import '../../../../boards/datasources/models/board_request_model.dart';
import '../cards/notif_card.dart';

Widget buildRequestsSection(
  BuildContext context,
  Future<void> Function() refreshNotifications,
  DateTime Function(dynamic) getNotificationDate,
  Widget Function() buildEmptyState,
) {
  return Consumer<BoardRequestProvider>(
    builder: (context, boardProvider, child) {
      final recruitments = boardProvider.invitations;
      final sentRecruitments = boardProvider.sentInvitations;
      final applications = boardProvider.joinRequests;

      final displayList = <dynamic>[
        ...recruitments,
        ...sentRecruitments,
        ...applications,
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
          }

          return const SizedBox.shrink();
        },
      );
    },
  );
}
