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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ActivityEventProvider>().listenToBoard(widget.boardId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActivityEventProvider>(
      builder: (context, activityProvider, _) {
        final activities = activityProvider.events;
        if (activities.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Text(
                'Board Activity',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
            'Board Activity',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
    final displayCount = _showAllActivities
        ? activities.length
        : (activities.length > 5 ? 5 : activities.length);
    final hasMore = activities.length > 5;

    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayCount,
          itemBuilder: (context, index) {
            final activity = activities[index];
            final isLast = index == displayCount - 1;
            return _buildActivityTimelineItem(activity, isLast: isLast);
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
              icon: Icon(
                _showAllActivities ? Icons.expand_less : Icons.expand_more,
              ),
              label: Text(
                _showAllActivities
                    ? 'Show Less'
                    : 'More (${activities.length - 5})',
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

  Widget _buildActivityTimelineItem(
    ActivityEvent activity, {
    required bool isLast,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCurrentUser = currentUser?.uid == activity.ActEvUserId;
    final displayName = isCurrentUser ? 'You' : activity.ActEvUserName;
    final visual = _activityVisual(activity);
    final message = _buildReadableMessage(displayName, activity);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: visual.color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: visual.color.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                  ),
                  child: Icon(visual.icon, size: 15, color: visual.color),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 44,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.grey.shade300,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                      children: [TextSpan(text: message)],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getTimeAgo(activity.ActEvTimestamp),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _ActivityVisual _activityVisual(ActivityEvent activity) {
    final type = (activity.ActEvType ?? '').toLowerCase();
    if (type == 'task_assignment_accepted') {
      return const _ActivityVisual(
        Icons.check_circle_outline,
        Color(0xFF2E7D32),
      );
    }
    if (type == 'task_assignment_declined') {
      return const _ActivityVisual(Icons.cancel_outlined, Color(0xFFC62828));
    }
    if (type == 'task_in_progress') {
      return const _ActivityVisual(
        Icons.play_circle_outline,
        Color(0xFFFB8C00),
      );
    }
    if (type == 'task_status_changed') {
      return const _ActivityVisual(Icons.sync_alt_outlined, Color(0xFF6D4C41));
    }
    if (type == 'file_submitted' || type == 'task_submitted') {
      return const _ActivityVisual(
        Icons.upload_file_outlined,
        Color(0xFF00897B),
      );
    }
    if (type.contains('invitation')) {
      return const _ActivityVisual(Icons.mail_outline, Color(0xFF3949AB));
    }
    if (type.contains('suggestion')) {
      return const _ActivityVisual(Icons.lightbulb_outline, Color(0xFFFFA000));
    }
    if (type.contains('task') && type.contains('assigned')) {
      return const _ActivityVisual(
        Icons.assignment_ind_outlined,
        Color(0xFF1E88E5),
      );
    }
    if (type.contains('task') && type.contains('submitted')) {
      return const _ActivityVisual(
        Icons.upload_file_outlined,
        Color(0xFF00897B),
      );
    }
    if (type.contains('task') &&
        (type.contains('approved') || type.contains('review'))) {
      return const _ActivityVisual(
        Icons.fact_check_outlined,
        Color(0xFF2E7D32),
      );
    }
    if (type.contains('board') && type.contains('created')) {
      return const _ActivityVisual(
        Icons.dashboard_customize_outlined,
        Color(0xFF5E35B1),
      );
    }
    return const _ActivityVisual(Icons.bolt_outlined, Color(0xFF546E7A));
  }

  String _buildReadableMessage(String actorName, ActivityEvent event) {
    final type = (event.ActEvType ?? '').toLowerCase();
    final metadata = event.ActEvMetadata ?? const <String, dynamic>{};
    final taskTitle = _metadataString(metadata, const [
      'taskTitle',
      'stepTitle',
    ]);
    final suggestionTitle = _metadataString(metadata, const [
      'suggestionTitle',
    ]);
    final assigneeName = _metadataString(metadata, const ['assigneeName']);
    final fromStatus = _metadataString(metadata, const ['fromStatus']);
    final toStatus = _metadataString(metadata, const ['toStatus']);

    if (type == 'task_created') {
      return taskTitle != null
          ? '$actorName created task "$taskTitle"'
          : '$actorName created a task';
    }
    if (type == 'task_completed') {
      return taskTitle != null
          ? '$actorName completed task "$taskTitle"'
          : '$actorName completed a task';
    }
    if (type == 'task_assigned') {
      if (taskTitle != null && assigneeName != null) {
        return '$actorName assigned "$taskTitle" to $assigneeName';
      }
      return taskTitle != null
          ? '$actorName assigned task "$taskTitle"'
          : '$actorName assigned a task';
    }
    if (type == 'task_assignment_accepted') {
      return taskTitle != null
          ? '$actorName accepted task "$taskTitle"'
          : '$actorName accepted a task assignment';
    }
    if (type == 'task_assignment_declined') {
      return taskTitle != null
          ? '$actorName declined task "$taskTitle"'
          : '$actorName declined a task assignment';
    }
    if (type == 'task_status_changed') {
      if (taskTitle != null && fromStatus != null && toStatus != null) {
        return '$actorName changed "$taskTitle" from $fromStatus to $toStatus';
      }
      return taskTitle != null
          ? '$actorName changed status of "$taskTitle"'
          : '$actorName changed a task status';
    }
    if (type == 'task_in_progress') {
      return taskTitle != null
          ? '$actorName started "$taskTitle"'
          : '$actorName started working on a task';
    }
    if (type == 'file_submitted' || type == 'task_submitted') {
      return taskTitle != null
          ? '$actorName submitted work for "$taskTitle"'
          : '$actorName submitted task work';
    }
    if (type == 'task_deleted') {
      return taskTitle != null
          ? '$actorName deleted task "$taskTitle"'
          : '$actorName deleted a task';
    }
    if (type == 'step_created') {
      return taskTitle != null
          ? '$actorName created step "$taskTitle"'
          : '$actorName created a step';
    }
    if (type == 'step_completed') {
      return taskTitle != null
          ? '$actorName completed step "$taskTitle"'
          : '$actorName completed a step';
    }
    if (type == 'suggestion_created') {
      return suggestionTitle != null
          ? '$actorName created suggestion "$suggestionTitle"'
          : '$actorName created a suggestion';
    }

    final desc = (event.ActEvDescription ?? '').trim();
    if (desc.isNotEmpty) {
      if (taskTitle != null &&
          !desc.toLowerCase().contains(taskTitle.toLowerCase())) {
        return '$actorName $desc ($taskTitle)';
      }
      return '$actorName $desc';
    }
    return '$actorName did an activity';
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

class _ActivityVisual {
  final IconData icon;
  final Color color;

  const _ActivityVisual(this.icon, this.color);
}
