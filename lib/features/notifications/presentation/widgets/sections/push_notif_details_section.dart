import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../datasources/models/push_notif_model.dart';
import '../../../datasources/providers/push_notif_provider.dart';

Widget buildPushNotificationDetailsSection(
  BuildContext context,
  PushNotification notif,
) {
  return Consumer<PushNotificationProvider>(
    builder: (context, provider, child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.notifications,
                color: notif.isSent ? Colors.green : Colors.orange,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Push Notification',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      notif.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: notif.isSent ? Colors.green[100] : Colors.orange[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  notif.isSent ? 'Sent' : 'Pending',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: notif.isSent ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Body/Message
          const Text(
            'Message',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              notif.body,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Details
          _buildInfoRow(
            icon: Icons.access_time,
            label: 'Created',
            value: timeago.format(notif.createdAt),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            icon: Icons.info,
            label: 'Status',
            value: notif.isSent ? 'Successfully Sent' : 'Pending Delivery',
          ),
          if (notif.category != null && notif.category!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.label,
              label: 'Category',
              value: notif.category!.toUpperCase(),
            ),
          ],
          if (notif.attempts != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.repeat,
              label: 'Delivery Attempts',
              value: '${notif.attempts}',
            ),
          ],

          // Error information
          if (notif.lastError != null && notif.lastError!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Error Details',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[300]!),
              ),
              child: Text(
                notif.lastError!,
                style: TextStyle(
                  color: Colors.red[800],
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _handleRetry(context, notif, provider),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ],
      );
    },
  );
}

Widget _buildInfoRow({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Row(
    children: [
      Icon(icon, size: 20, color: Colors.grey[600]),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ],
  );
}

Future<void> _handleRetry(
  BuildContext context,
  PushNotification notif,
  PushNotificationProvider provider,
) async {
  try {
    // TODO: Implement retry logic in provider
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Retrying notification delivery...'),
        backgroundColor: Colors.blue,
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
