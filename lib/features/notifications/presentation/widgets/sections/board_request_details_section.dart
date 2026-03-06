import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../boards/datasources/models/board_request_model.dart';
import '../../../../boards/datasources/models/board_roles.dart';
import '../../../../boards/datasources/providers/board_request_provider.dart';

Widget buildBoardRequestDetailsSection(
  BuildContext context,
  BoardRequest request,
) {
  return Consumer<BoardRequestProvider>(
    builder: (context, boardProvider, child) {
      final currentRequest = _findLatestRequest(boardProvider, request);
      final isRecruitment =
          BoardRequest.normalizeType(currentRequest.boardReqType) ==
          BoardRequest.typeRecruitment;
      final isPending = currentRequest.boardReqStatus == 'pending';
      final isProcessing = boardProvider.isLoading;
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final isSender =
          currentUserId.isNotEmpty &&
          currentUserId == currentRequest.boardManagerId;
      final isReceiver =
          currentUserId.isNotEmpty && currentUserId == currentRequest.userId;
      final canApproveReject =
          isPending &&
          ((isRecruitment && isReceiver) || (!isRecruitment && isSender));
      final canCancel =
          isPending &&
          ((isRecruitment && isSender) || (!isRecruitment && !isSender));
      final headerTitle = isRecruitment
          ? (isSender ? 'Board Invite Sent' : 'Board Invite Received')
          : (isSender ? 'Join Request Received' : 'Join Request Sent');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with type and status
          Row(
            children: [
              Icon(
                isSender ? Icons.outgoing_mail : Icons.mail,
                color: isRecruitment ? Colors.blue : Colors.green,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headerTitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      currentRequest.boardTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(currentRequest.boardReqStatus),
            ],
          ),
          const SizedBox(height: 24),

          // From/To information
          _buildInfoSection(
            label: isRecruitment
                ? (isSender ? 'Invited User' : 'From Manager')
                : (isSender ? 'Requester' : 'To Board'),
            value: isRecruitment
                ? (isSender
                      ? currentRequest.userName
                      : currentRequest.boardManagerName)
                : (isSender
                      ? currentRequest.userName
                      : currentRequest.boardTitle),
            icon: Icons.person,
          ),
          if (isRecruitment) ...[
            const SizedBox(height: 16),
            _buildInfoSection(
              label: 'Role on Join',
              value: _roleLabel(currentRequest.boardReqRequestedRole),
              icon: Icons.badge_outlined,
            ),
          ],
          const SizedBox(height: 16),

          // Message section
          if (currentRequest.boardReqMessage != null &&
              currentRequest.boardReqMessage!.isNotEmpty) ...[
            const Text(
              'Message',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                currentRequest.boardReqMessage!,
                style: TextStyle(color: Colors.grey[800], fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Timeline
          _buildTimeline(currentRequest),
          const SizedBox(height: 24),

          // Action buttons based on sender/receiver role
          if (canApproveReject) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isProcessing
                        ? null
                        : () => _handleAccept(
                            context,
                            currentRequest,
                            boardProvider,
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      isProcessing
                          ? 'Processing...'
                          : (isRecruitment ? 'Accept' : 'Approve'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing
                        ? null
                        : () => _handleDecline(
                            context,
                            currentRequest,
                            boardProvider,
                          ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      isProcessing
                          ? 'Processing...'
                          : (isRecruitment ? 'Decline' : 'Reject'),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (canCancel) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isProcessing
                    ? null
                    : () => _handleCancelRequest(
                        context,
                        currentRequest,
                        boardProvider,
                      ),
                icon: const Icon(Icons.cancel_outlined),
                label: Text(isProcessing ? 'Processing...' : 'Cancel Request'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],

          // Response state for non-pending requests
          if (!isPending) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: currentRequest.boardReqStatus == 'approved'
                    ? Colors.green[50]
                    : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: currentRequest.boardReqStatus == 'approved'
                      ? Colors.green[200]!
                      : Colors.red[200]!,
                ),
              ),
              child: Text(
                _buildResolvedStateMessage(
                  currentRequest: currentRequest,
                  isSender: isSender,
                  isRecruitment: isRecruitment,
                ),
                style: TextStyle(
                  color: currentRequest.boardReqStatus == 'approved'
                      ? Colors.green[800]
                      : Colors.red[800],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          // Response message if declined/approved
          if (currentRequest.boardReqResponseMessage != null &&
              currentRequest.boardReqResponseMessage!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Response Message',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: currentRequest.boardReqStatus == 'approved'
                    ? Colors.green[50]
                    : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: currentRequest.boardReqStatus == 'approved'
                      ? Colors.green[300]!
                      : Colors.red[300]!,
                ),
              ),
              child: Text(
                currentRequest.boardReqResponseMessage!,
                style: TextStyle(
                  color: currentRequest.boardReqStatus == 'approved'
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

BoardRequest _findLatestRequest(
  BoardRequestProvider provider,
  BoardRequest fallback,
) {
  final allRequests = <BoardRequest>[
    ...provider.invitations,
    ...provider.sentInvitations,
    ...provider.joinRequests,
    ...provider.pendingRequests,
    ...provider.userRequests,
  ];

  for (final request in allRequests) {
    if (request.boardRequestId == fallback.boardRequestId) {
      return request;
    }
  }

  return fallback;
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildTimeline(BoardRequest request) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Timeline',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
          color: request.boardReqStatus == 'approved'
              ? Colors.green
              : Colors.red,
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

String _buildResolvedStateMessage({
  required BoardRequest currentRequest,
  required bool isSender,
  required bool isRecruitment,
}) {
  final approved = currentRequest.boardReqStatus == 'approved';
  if (approved) {
    if (isRecruitment) {
      return isSender
          ? '${currentRequest.userName} accepted your invite.'
          : 'You accepted this invite.';
    }
    return isSender
        ? 'You approved this join request.'
        : 'Your join request was approved.';
  }

  if (isRecruitment) {
    return isSender
        ? '${currentRequest.userName} declined your invite.'
        : 'You declined this invite.';
  }
  return isSender
      ? 'You declined this join request.'
      : 'Your join request was declined.';
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
    child: Container(width: 2, height: 20, color: Colors.grey[300]),
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
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
}

String _roleLabel(String role) {
  final normalizedRole = BoardRoles.normalize(role);
  if (normalizedRole == BoardRoles.supervisor) {
    return 'Supervisor';
  }
  return 'Member';
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

    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          'Joined ${request.boardTitle} as ${_roleLabel(request.boardReqRequestedRole)}!',
        ),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('Error accepting: $e'),
        backgroundColor: Colors.red,
      ),
    );
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

              if (!context.mounted) return;
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(
                  content: Text('Recruitment declined'),
                  backgroundColor: Colors.red,
                ),
              );
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text('Error declining: $e'),
                  backgroundColor: Colors.red,
                ),
              );
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

Future<void> _handleCancelRequest(
  BuildContext context,
  BoardRequest request,
  BoardRequestProvider provider,
) async {
  try {
    await provider.cancelRequest(request.boardRequestId);
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Request cancelled'),
        backgroundColor: Colors.red,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('Error cancelling request: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
