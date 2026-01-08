import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/features/users/datasources/models/activity_event_model.dart';

class ActivityCard extends StatelessWidget {
  final ActivityEvent activity;

  const ActivityCard({
    super.key,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    final activityType = activity.ActEvType ?? 'other';
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCurrentUser = currentUser?.uid == activity.ActEvUserId;
    final displayName = isCurrentUser ? 'You' : activity.ActEvUserName;
    
    print('[DEBUG] ActivityCard: Building card');
    print('[DEBUG] ActivityCard: ActEvId = ${activity.ActEvId}');
    print('[DEBUG] ActivityCard: ActEvType = ${activity.ActEvType} (raw)');
    print('[DEBUG] ActivityCard: activityType after coalesce = $activityType');
    print('[DEBUG] ActivityCard: ActEvUserName = ${activity.ActEvUserName}');
    print('[DEBUG] ActivityCard: ActEvDescription = ${activity.ActEvDescription}');
    print('[DEBUG] ActivityCard: isCurrentUser = $isCurrentUser, displayName = $displayName');
    
    final icon = _getActivityIcon(activityType);
    final color = _getActivityColor(activityType);
    
    print('[DEBUG] ActivityCard: Selected icon = $icon, color = $color');

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: color.shade100,
          child: activity.ActEvUserProfilePicture != null && activity.ActEvUserProfilePicture!.isNotEmpty
              ? ClipOval(
                child: Image.network(
                  activity.ActEvUserProfilePicture!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Text(
                      icon,
                      style: const TextStyle(fontSize: 18),
                    );
                  },
                ),
              )
              : Text(
                icon,
                style: const TextStyle(fontSize: 18),
              ),
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
        trailing: _buildMetadataChip(),
      ),
    );
  }

  Widget? _buildMetadataChip() {
    if (activity.ActEvMetadata == null || activity.ActEvMetadata!.isEmpty) {
      return null;
    }

    String? label;
    Color? color;

    if (activity.ActEvMetadata!.containsKey('taskTitle')) {
      label = activity.ActEvMetadata!['taskTitle'] as String?;
      color = Colors.blue.shade50;
    } else if (activity.ActEvMetadata!.containsKey('fileName')) {
      label = activity.ActEvMetadata!['fileName'] as String?;
      color = Colors.purple.shade50;
    } else if (activity.ActEvMetadata!.containsKey('boardName')) {
      label = activity.ActEvMetadata!['boardName'] as String?;
      color = Colors.indigo.shade50;
    }

    if (label == null || label.isEmpty) return null;

    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
      ),
    );
  }

  String _getActivityIcon(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'account_created':
      case 'account_created_google':
        return '🎉';
      case 'login':
      case 'login_google':
        return '🔓';
      case 'task_created':
        return '📝';
      case 'task_assigned':
        return '✋';
      case 'task_completed':
        return '✅';
      case 'task_submitted':
        return '📤';
      case 'task_approved':
        return '👍';
      case 'task_rejected':
        return '❌';
      case 'task_deleted':
        return '🗑️';
      case 'file_submitted':
        return '📎';
      case 'comment_added':
        return '💬';
      case 'volunteer_accepted':
        return '🙋';
      case 'volunteer_requested':
        return '🙋‍♂️';
      case 'member_joined':
        return '👋';
      case 'board_created':
        return '🎯';
      default:
        return '•';
    }
  }

  MaterialColor _getActivityColor(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'account_created':
      case 'account_created_google':
        return Colors.amber;
      case 'login':
      case 'login_google':
        return Colors.cyan;
      case 'task_created':
      case 'task_assigned':
        return Colors.blue;
      case 'task_completed':
      case 'task_approved':
        return Colors.green;
      case 'task_submitted':
        return Colors.purple;
      case 'task_rejected':
      case 'task_deleted':
        return Colors.red;
      case 'file_submitted':
        return Colors.purple;
      case 'comment_added':
        return Colors.orange;
      case 'volunteer_accepted':
        return Colors.green;
      case 'volunteer_requested':
        return Colors.blue;
      case 'member_joined':
        return Colors.teal;
      case 'board_created':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
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
