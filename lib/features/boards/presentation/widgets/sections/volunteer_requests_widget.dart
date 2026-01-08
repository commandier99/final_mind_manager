import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';

class VolunteerRequestsWidget extends StatelessWidget {
  final String boardId;
  final bool isManager;

  const VolunteerRequestsWidget({
    super.key,
    required this.boardId,
    required this.isManager,
  });

  @override
  Widget build(BuildContext context) {
    if (!isManager) return const SizedBox.shrink();

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: taskProvider.streamVolunteerRequests(boardId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final requests = snapshot.data!;

        return Card(
          margin: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.volunteer_activism, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Volunteer Requests (${requests.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: requests.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final request = requests[index];
                  return _VolunteerRequestItem(
                    request: request,
                    onAccept:
                        () => _handleAccept(context, request['requestId']),
                    onDecline:
                        () => _handleDecline(context, request['requestId']),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleAccept(BuildContext context, String requestId) async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    try {
      await taskProvider.acceptVolunteerRequest(requestId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Volunteer request accepted!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDecline(BuildContext context, String requestId) async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    try {
      await taskProvider.declineVolunteerRequest(requestId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Volunteer request declined'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _VolunteerRequestItem extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _VolunteerRequestItem({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final userName = request['userName'] ?? 'Unknown User';
    final createdAt = request['createdAt']?.toDate() ?? DateTime.now();
    final timeAgo = _getTimeAgo(createdAt);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(child: Text(userName[0].toUpperCase())),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'wants to volunteer for this task',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filled(
            onPressed: onAccept,
            icon: const Icon(Icons.check, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            tooltip: 'Accept',
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: onDecline,
            icon: const Icon(Icons.close, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red[50],
              foregroundColor: Colors.red[700],
            ),
            tooltip: 'Decline',
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }
}
