import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../boards/datasources/models/board_request_model.dart';
import '../../../../boards/datasources/providers/board_request_provider.dart';

Widget buildBoardRequestDetailsSection(
  BuildContext context,
  BoardRequest request,
) {
  final isRecruitment = request.boardReqType == 'recruitment';
  final isPending = request.boardReqStatus == 'pending';

  return Consumer<BoardRequestProvider>(
    builder: (context, boardProvider, child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with type and status
          Row(
            children: [
              Icon(
                isRecruitment ? Icons.mail : Icons.send,
                color: isRecruitment ? Colors.blue : Colors.green,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRecruitment ? 'Recruitment Request' : 'Application Request',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      request.boardTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(request.boardReqStatus),
            ],
          ),
          const SizedBox(height: 24),

          // From/To information
          _buildInfoSection(
            label: isRecruitment ? 'From Manager' : 'To Board',
            value: isRecruitment ? request.boardManagerName : request.boardTitle,
            icon: Icons.person,
          ),
          const SizedBox(height: 16),

          // Message section
          if (request.boardReqMessage != null &&
              request.boardReqMessage!.isNotEmpty) ...[
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
                request.boardReqMessage!,
                style: TextStyle(color: Colors.grey[800], fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Timeline
          _buildTimeline(request, isRecruitment),
          const SizedBox(height: 24),

          // Action buttons for pending recruitment
          if (isPending && isRecruitment) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleAccept(context, request, boardProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleDecline(context, request, boardProvider),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
          ],

          // Response message if declined/approved
          if (request.boardReqResponseMessage != null &&
              request.boardReqResponseMessage!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Response Message',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: request.boardReqStatus == 'approved'
                    ? Colors.green[50]
                    : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: request.boardReqStatus == 'approved'
                      ? Colors.green[300]!
                      : Colors.red[300]!,
                ),
              ),
              child: Text(
                request.boardReqResponseMessage!,
                style: TextStyle(
                  color: request.boardReqStatus == 'approved'
                      ? Colors.green[800]
                      : Colors.red[800],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}

Widget _buildInfoSection({
  required String label,
  required String value,
  required IconData icon,
}) {
  return Row(
    children: [
      Icon(icon, size: 20, color: Colors.grey[600]),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
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
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildTimeline(BoardRequest request, bool isRecruitment) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Timeline',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 12),
      _buildTimelineItem(
        label: 'Sent',
        date: request.boardReqCreatedAt,
        isCompleted: true,
      ),
      if (request.boardReqRespondedAt != null) ...[
        _buildTimelineConnector(),
        _buildTimelineItem(
          label: request.boardReqStatus == 'approved' ? 'Accepted' : 'Declined',
          date: request.boardReqRespondedAt!,
          isCompleted: true,
          color: request.boardReqStatus == 'approved' ? Colors.green : Colors.red,
        ),
      ] else ...[
        _buildTimelineConnector(),
        _buildTimelineItem(
          label: 'Awaiting Response',
          date: null,
          isCompleted: false,
        ),
      ],
    ],
  );
}

Widget _buildTimelineItem({
  required String label,
  required DateTime? date,
  required bool isCompleted,
  Color? color,
}) {
  color ??= isCompleted ? Colors.blue : Colors.orange;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 2),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (date != null)
              Text(
                timeago.format(date),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildTimelineConnector() {
  return Padding(
    padding: const EdgeInsets.only(left: 5, top: 4, bottom: 4),
    child: Container(
      width: 2,
      height: 20,
      color: Colors.grey[300],
    ),
  );
}

Widget _buildStatusChip(String status) {
  Color color;
  String label;

  switch (status) {
    case 'approved':
      color = Colors.green;
      label = 'Accepted';
      break;
    case 'rejected':
      color = Colors.red;
      label = 'Declined';
      break;
    default:
      color = Colors.orange;
      label = 'Pending';
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Future<void> _handleAccept(
  BuildContext context,
  BoardRequest request,
  BoardRequestProvider provider,
) async {
  try {
    await provider.approveRequest(
      request,
      responseMessage: 'Recruitment accepted',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined ${request.boardTitle}!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _handleDecline(
  BuildContext context,
  BoardRequest request,
  BoardRequestProvider provider,
) async {
  final reasonController = TextEditingController();

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Decline Recruitment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to decline the recruitment for ${request.boardTitle}?',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Text(
            'Optional: Tell them why you\'re declining',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: reasonController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'E.g., "Too busy right now" or "Not interested"',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            try {
              await provider.rejectRequest(
                request,
                responseMessage: reasonController.text.isNotEmpty
                    ? reasonController.text
                    : 'Recruitment declined',
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Recruitment declined'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error declining: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Decline'),
        ),
      ],
    ),
  );
}
