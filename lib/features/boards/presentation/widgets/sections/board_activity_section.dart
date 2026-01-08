import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../shared/features/users/datasources/models/activity_event_model.dart';
import '../../../../../shared/features/users/datasources/providers/activity_event_provider.dart';

class BoardActivitySection extends StatefulWidget {
  final String boardId;

  const BoardActivitySection({super.key, required this.boardId});

  @override
  State<BoardActivitySection> createState() => _BoardActivitySectionState();
}

class _BoardActivitySectionState extends State<BoardActivitySection> {
  bool _showAllActivities = false;

  @override
  void initState() {
    super.initState();
    // Initialize the activity stream for all board members
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('[DEBUG] BoardActivitySection: Starting activity listener for boardId: ${widget.boardId}');
      context.read<ActivityEventProvider>().listenToBoard(widget.boardId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityEventProvider>(
      builder: (context, activityProvider, _) {
        // All activities are already for this board (no filtering needed)
        final activities = activityProvider.events;

        print(
          '[DEBUG] BoardActivitySection: Total events in provider: ${activityProvider.events.length}',
        );
        print(
          '[DEBUG] BoardActivitySection: Building with ${activities.length} activities for board ${widget.boardId}',
        );
        
        // Log event details for debugging
        for (var event in activityProvider.events.take(3)) {
          print('[DEBUG] BoardActivitySection: Event boardId=${event.ActEvBoardId}, type=${event.ActEvType}');
        }

        if (activities.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                "Board Activity",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildActivityList(activities),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Board Activity",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'No activity yet',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityList(List<ActivityEvent> activities) {
    final displayCount = _showAllActivities ? activities.length : (activities.length > 10 ? 10 : activities.length);
    final hasMore = activities.length > 10;

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayCount,
          separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
          itemBuilder: (context, index) {
            final activity = activities[index];
            return _buildActivityCard(activity);
          },
        ),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _showAllActivities = !_showAllActivities;
                });
              },
              icon: Icon(_showAllActivities ? Icons.expand_less : Icons.expand_more),
              label: Text(
                _showAllActivities
                    ? 'Show Less'
                    : 'Read More (${activities.length - 10} more)',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActivityCard(ActivityEvent activity) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCurrentUser = currentUser?.uid == activity.ActEvUserId;
    final displayName = isCurrentUser ? 'You' : activity.ActEvUserName;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.blue.shade100,
          child: activity.ActEvUserProfilePicture != null && activity.ActEvUserProfilePicture!.isNotEmpty
              ? ClipOval(
                child: Image.network(
                  activity.ActEvUserProfilePicture!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Text('👤', style: TextStyle(fontSize: 18));
                  },
                ),
              )
              : const Text('👤', style: TextStyle(fontSize: 18)),
        ),
        title: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            children: [
              TextSpan(
                text: displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (activity.ActEvDescription != null && activity.ActEvDescription!.isNotEmpty)
                TextSpan(text: ' ${activity.ActEvDescription}'),
            ],
          ),
        ),
        subtitle: Text(
          _getTimeAgo(activity.ActEvTimestamp),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);

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

