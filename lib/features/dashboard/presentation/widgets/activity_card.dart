import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/features/users/datasources/models/activity_event_model.dart';

class ActivityCard extends StatelessWidget {
  final ActivityEvent activity;

  const ActivityCard({super.key, required this.activity});

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
    print(
      '[DEBUG] ActivityCard: ActEvDescription = ${activity.ActEvDescription}',
    );
    print(
      '[DEBUG] ActivityCard: isCurrentUser = $isCurrentUser, displayName = $displayName',
    );

    final icon = _getActivityIcon(activityType);
    final color = _getActivityColor(activityType);
    final message = _buildReadableMessage(displayName, activity);

    print('[DEBUG] ActivityCard: Selected icon = $icon, color = $color');

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: color.shade100,
          child:
              activity.ActEvUserProfilePicture != null &&
                  activity.ActEvUserProfilePicture!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    activity.ActEvUserProfilePicture!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Text(icon, style: const TextStyle(fontSize: 18));
                    },
                  ),
                )
              : Text(icon, style: const TextStyle(fontSize: 18)),
        ),
        title: RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black87, fontSize: 14),
            children: [
              TextSpan(
                text: message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
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

  String _buildReadableMessage(String actorName, ActivityEvent event) {
    final type = (event.ActEvType ?? '').toLowerCase();
    final metadata = event.ActEvMetadata ?? const <String, dynamic>{};
    final taskTitle = _metadataString(metadata, const [
      'taskTitle',
      'stepTitle',
    ]);
    final boardTitle = _metadataString(metadata, const [
      'boardTitle',
      'boardName',
    ]);
    final suggestionTitle = _metadataString(metadata, const [
      'suggestionTitle',
    ]);
    final assigneeName = _metadataString(metadata, const ['assigneeName']);
    final fromStatus = _metadataString(metadata, const ['fromStatus']);
    final toStatus = _metadataString(metadata, const ['toStatus']);

    String sentence;
    if (type == 'task_created') {
      sentence = taskTitle != null
          ? '$actorName created task "$taskTitle"'
          : '$actorName created a task';
    } else if (type == 'task_completed') {
      sentence = taskTitle != null
          ? '$actorName completed task "$taskTitle"'
          : '$actorName completed a task';
    } else if (type == 'task_assigned') {
      if (taskTitle != null && assigneeName != null) {
        sentence = '$actorName assigned "$taskTitle" to $assigneeName';
      } else {
        sentence = taskTitle != null
            ? '$actorName assigned task "$taskTitle"'
            : '$actorName assigned a task';
      }
    } else if (type == 'task_assignment_accepted') {
      sentence = taskTitle != null
          ? '$actorName accepted task "$taskTitle"'
          : '$actorName accepted a task assignment';
    } else if (type == 'task_assignment_declined') {
      sentence = taskTitle != null
          ? '$actorName declined task "$taskTitle"'
          : '$actorName declined a task assignment';
    } else if (type == 'task_status_changed') {
      if (taskTitle != null && fromStatus != null && toStatus != null) {
        sentence =
            '$actorName changed "$taskTitle" from $fromStatus to $toStatus';
      } else {
        sentence = taskTitle != null
            ? '$actorName changed status of "$taskTitle"'
            : '$actorName changed a task status';
      }
    } else if (type == 'task_in_progress') {
      sentence = taskTitle != null
          ? '$actorName started "$taskTitle"'
          : '$actorName started working on a task';
    } else if (type == 'file_submitted' || type == 'task_submitted') {
      sentence = taskTitle != null
          ? '$actorName submitted work for "$taskTitle"'
          : '$actorName submitted task work';
    } else if (type == 'task_deleted') {
      sentence = taskTitle != null
          ? '$actorName deleted task "$taskTitle"'
          : '$actorName deleted a task';
    } else if (type == 'step_created') {
      sentence = taskTitle != null
          ? '$actorName created step "$taskTitle"'
          : '$actorName created a step';
    } else if (type == 'step_completed') {
      sentence = taskTitle != null
          ? '$actorName completed step "$taskTitle"'
          : '$actorName completed a step';
    } else if (type == 'suggestion_created') {
      sentence = suggestionTitle != null
          ? '$actorName created suggestion "$suggestionTitle"'
          : '$actorName created a suggestion';
    } else if (type == 'board_created') {
      final board =
          boardTitle ?? _metadataString(metadata, const ['boardName']);
      sentence = board != null
          ? '$actorName created board "$board"'
          : '$actorName created a board';
    } else {
      final desc = (event.ActEvDescription ?? '').trim();
      sentence = desc.isNotEmpty
          ? '$actorName $desc'
          : '$actorName did an activity';
      if (taskTitle != null &&
          !sentence.toLowerCase().contains(taskTitle.toLowerCase())) {
        sentence = '$sentence ($taskTitle)';
      }
    }

    if (boardTitle != null &&
        !sentence.toLowerCase().contains(boardTitle.toLowerCase())) {
      sentence = '$sentence in "$boardTitle"';
    }

    return sentence;
  }

  String? _metadataString(Map<String, dynamic> metadata, List<String> keys) {
    for (final key in keys) {
      final value = metadata[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
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
    } else if (activity.ActEvMetadata!.containsKey('sessionTitle')) {
      label = activity.ActEvMetadata!['sessionTitle'] as String?;
      color = Colors.teal.shade50;
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
      case 'task_assignment_accepted':
        return 'OK';
      case 'task_assignment_declined':
        return 'NO';
      case 'task_status_changed':
        return '~';
      case 'task_in_progress':
        return '>>';
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
      case 'mindset_session_created':
        return '🧠';
      case 'mindset_session_started':
        return '⚡';
      case 'mindset_session_completed':
        return '🏁';
      case 'mindset_session_cancelled':
        return '🛑';
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
      case 'volunteer_requested':
        return Colors.blue;
      case 'task_status_changed':
      case 'task_in_progress':
      case 'comment_added':
        return Colors.orange;
      case 'task_assignment_accepted':
      case 'task_completed':
      case 'task_approved':
      case 'volunteer_accepted':
        return Colors.green;
      case 'task_assignment_declined':
      case 'task_rejected':
      case 'task_deleted':
        return Colors.red;
      case 'task_submitted':
      case 'file_submitted':
        return Colors.purple;
      case 'member_joined':
        return Colors.teal;
      case 'board_created':
        return Colors.indigo;
      case 'mindset_session_created':
      case 'mindset_session_started':
        return Colors.deepPurple;
      case 'mindset_session_completed':
        return Colors.green;
      case 'mindset_session_cancelled':
        return Colors.red;
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
