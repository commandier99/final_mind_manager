import 'package:flutter/material.dart';
import '../../../../boards/datasources/models/board_request_model.dart';
import '../../../datasources/models/in_app_notif_model.dart';
import '../../../datasources/models/push_notif_model.dart';
import '../sections/board_request_details_section.dart';
import '../sections/in_app_notif_details_section.dart';
import '../sections/push_notif_details_section.dart';

class NotificationDetailsSheet extends StatelessWidget {
  final dynamic notification;

  const NotificationDetailsSheet({
    required this.notification,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          AppBar(
            title: const Text('Notification Details'),
            automaticallyImplyLeading: false,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildContent(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (notification is BoardRequest) {
      return buildBoardRequestDetailsSection(
        context,
        notification as BoardRequest,
      );
    } else if (notification is InAppNotification) {
      return buildInAppNotificationDetailsSection(
        context,
        notification as InAppNotification,
      );
    } else if (notification is PushNotification) {
      return buildPushNotificationDetailsSection(
        context,
        notification as PushNotification,
      );
    }

    return const SizedBox.shrink();
  }
}
