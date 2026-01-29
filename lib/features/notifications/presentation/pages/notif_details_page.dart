import 'package:flutter/material.dart';
import '../../../boards/datasources/models/board_request_model.dart';
import '../../datasources/models/in_app_notif_model.dart';
import '../../datasources/models/push_notif_model.dart';
import '../widgets/sections/board_request_details_section.dart';
import '../widgets/sections/in_app_notif_details_section.dart';
import '../widgets/sections/push_notif_details_section.dart';

class NotificationDetailsPage extends StatefulWidget {
  final dynamic notification; // BoardRequest, InAppNotification, or PushNotification

  const NotificationDetailsPage({
    required this.notification,
    super.key,
  });

  @override
  State<NotificationDetailsPage> createState() => _NotificationDetailsPageState();
}

class _NotificationDetailsPageState extends State<NotificationDetailsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Details'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.notification is BoardRequest) {
      return buildBoardRequestDetailsSection(context, widget.notification as BoardRequest);
    } else if (widget.notification is InAppNotification) {
      return buildInAppNotificationDetailsSection(context, widget.notification as InAppNotification);
    } else if (widget.notification is PushNotification) {
      return buildPushNotificationDetailsSection(context, widget.notification as PushNotification);
    }
    return const SizedBox.shrink();
  }
}
