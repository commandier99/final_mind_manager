import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../datasources/models/in_app_notif_model.dart';
import '../../../datasources/providers/in_app_notif_provider.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';

Widget buildInAppNotificationDetailsSection(
  BuildContext context,
  InAppNotification notif,
) {
  return Consumer<InAppNotificationProvider>(
    builder: (context, provider, child) {
      final current = _resolveCurrentNotification(provider, notif);
      final isTaskAssignment = _isTaskAssignmentNotification(current);
      final isPoke = _isPokeNotification(current);
      final isPokeReminder = _isPokeReminderNotification(current);
      final isTaskReminder = (current.category ?? '').trim() == 'task_deadline';
      final accent = _categoryColor(current.category, isRead: current.isRead);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.18),
                  accent.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notifications_active, color: accent, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeago.format(current.createdAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                _buildStatusPill(current.isRead),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  current.message,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow(
            icon: Icons.access_time,
            label: 'Sent',
            value: timeago.format(current.createdAt),
          ),
          const SizedBox(height: 16),
          if (isPoke) ...[
            _buildPokeSummarySection(current, accent),
            const SizedBox(height: 16),
          ],
          if (isPokeReminder) ...[
            _buildReminderSummarySection(current, accent),
            const SizedBox(height: 16),
          ],
          if (!isPoke && !isPokeReminder) _buildTaskSnapshotSection(current, accent),
          if (isTaskAssignment) ...[
            const SizedBox(height: 16),
            _buildTaskAssignmentActions(context, current),
          ],
          if (!isPoke &&
              !isPokeReminder &&
              !isTaskReminder &&
              current.metadata != null &&
              current.metadata!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildMetadataSection(current.metadata!, accent),
          ],
        ],
      );
    },
  );
}

InAppNotification _resolveCurrentNotification(
  InAppNotificationProvider provider,
  InAppNotification fallback,
) {
  for (final item in provider.notifications) {
    if (item.notificationId == fallback.notificationId) {
      return item;
    }
  }
  return fallback;
}

Color _categoryColor(String? category, {required bool isRead}) {
  if (isRead) return Colors.grey;
  switch ((category ?? '').trim()) {
    case 'task_deadline':
    case 'reminder':
      return Colors.deepOrange;
    case 'task_assigned':
      return Colors.teal;
    case 'approval':
      return Colors.green;
    case 'invitation':
      return Colors.indigo;
    default:
      return Colors.blue;
  }
}

Widget _buildStatusPill(bool isRead) {
  final color = isRead ? Colors.grey : Colors.blue;
  final label = isRead ? 'Read' : 'Unread';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    ),
  );
}

String _formatCategory(String? category) {
  if (category == null || category.trim().isEmpty) return 'General';
  return category
      .trim()
      .split('_')
      .map(
        (part) =>
            part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
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

Widget _buildTaskSnapshotSection(InAppNotification notif, Color accent) {
  final metadata = notif.metadata ?? const <String, dynamic>{};
  final taskId = ((metadata['taskId'] ?? notif.relatedId) as String? ?? '').trim();

  if (taskId.isEmpty && metadata['taskTitle'] == null && metadata['taskSummary'] == null) {
    return const SizedBox.shrink();
  }

  return FutureBuilder<Map<String, dynamic>?>(
    future: _loadTaskData(taskId),
    builder: (context, snapshot) {
      final data = _mergeTaskData(metadata, snapshot.data);
      final taskTitle = (data['taskTitle'] as String? ?? '').trim();
      final description = (data['taskDescription'] as String? ?? '').trim();
      final priority = (data['taskPriorityLevel'] as String? ?? '').trim();
      final deadlineIso = (data['deadline'] as String? ?? '').trim();
      final deadline = _parseDeadline(deadlineIso);

      if (taskTitle.isEmpty && description.isEmpty && priority.isEmpty && deadline == null) {
        return const SizedBox.shrink();
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Summary',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            const SizedBox(height: 8),
            if (taskTitle.isNotEmpty)
              Text(
                taskTitle,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(fontSize: 13, height: 1.35, color: Colors.grey[800]),
              ),
            ],
            if (deadline != null) ...[
              const SizedBox(height: 8),
              Text(
                'Due: ${_formatDateTime(deadline)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
            if (priority.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Priority: $priority',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _priorityColor(priority),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

Future<Map<String, dynamic>?> _loadTaskData(String taskId) async {
  if (taskId.trim().isEmpty) return null;
  try {
    final doc = await FirebaseFirestore.instance.collection('tasks').doc(taskId).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    final deadline = data['taskDeadline'] as Timestamp?;
    return {
      'taskTitle': data['taskTitle']?.toString(),
      'taskDescription': data['taskDescription']?.toString(),
      'taskPriorityLevel': data['taskPriorityLevel']?.toString(),
      'deadline': deadline?.toDate().toIso8601String(),
    };
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _mergeTaskData(
  Map<String, dynamic> metadata,
  Map<String, dynamic>? taskData,
) {
  final summary = (metadata['taskSummary'] as String? ?? '').trim();
  final mapped = <String, dynamic>{
    'taskTitle': metadata['taskTitle']?.toString(),
    'taskDescription': summary,
    'taskPriorityLevel': metadata['taskPriorityLevel']?.toString(),
    'deadline': metadata['deadline']?.toString(),
  };

  if (taskData == null) return mapped;

  return {
    'taskTitle': (taskData['taskTitle']?.toString().trim().isNotEmpty ?? false)
        ? taskData['taskTitle']
        : mapped['taskTitle'],
    'taskDescription': (taskData['taskDescription']?.toString().trim().isNotEmpty ?? false)
        ? taskData['taskDescription']
        : mapped['taskDescription'],
    'taskPriorityLevel': (taskData['taskPriorityLevel']?.toString().trim().isNotEmpty ?? false)
        ? taskData['taskPriorityLevel']
        : mapped['taskPriorityLevel'],
    'deadline': (taskData['deadline']?.toString().trim().isNotEmpty ?? false)
        ? taskData['deadline']
        : mapped['deadline'],
  };
}

DateTime? _parseDeadline(String raw) {
  if (raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw.trim());
}

String _formatDateTime(DateTime dateTime) {
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final year = dateTime.year;
  final hour = dateTime.hour;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final normalizedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return '$month/$day/$year $normalizedHour:$minute $suffix';
}

Color _priorityColor(String priority) {
  switch (priority.trim().toLowerCase()) {
    case 'high':
      return Colors.red.shade700;
    case 'medium':
      return Colors.orange.shade700;
    case 'low':
      return Colors.green.shade700;
    default:
      return Colors.blueGrey.shade700;
  }
}

Widget _buildMetadataSection(Map<String, dynamic> metadata, Color accent) {
  final rows = _publicMetadataEntries(metadata);
  if (rows.isEmpty) return const SizedBox.shrink();

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: accent.withValues(alpha: 0.28)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Details',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${_formatCategory(row.key)}: ${row.value}',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            ),
          ),
      ],
    ),
  );
}

List<MapEntry<String, dynamic>> _publicMetadataEntries(
  Map<String, dynamic> metadata,
) {
  const hiddenKeys = <String>{
    'taskId',
    'boardId',
    'type',
    'notificationId',
    'inAppNotificationId',
    'relatedId',
    'boardTitle',
    'taskTitle',
    'boardManagerName',
    'deadline',
    'taskSummary',
    'taskPriorityLevel',
    'assignedBy',
    'assignedById',
    'assignedByName',
    'assignmentDecision',
    'assignmentRespondedAt',
    'kind',
    'pokeId',
    'pokeMessage',
    'createdByUserId',
    'createdByUserName',
    'pokeTiming',
    'scheduledAt',
  };

  return metadata.entries.where((entry) {
    final key = entry.key.trim();
    final value = entry.value;
    if (hiddenKeys.contains(key)) return false;
    if (value == null) return false;
    final valueText = value.toString().trim();
    return valueText.isNotEmpty;
  }).take(5).toList();
}

Widget _buildTaskAssignmentActions(
  BuildContext context,
  InAppNotification notif,
) {
  final decision = _assignmentDecisionFromMetadata(notif).toLowerCase();
  final taskId = _notificationTaskId(notif);
  if (taskId.isEmpty) {
    return const SizedBox.shrink();
  }
  final hasResponded = decision == 'accepted' || decision == 'declined';

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Assignment Action',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: hasResponded
                  ? null
                  : () => _handleAcceptTask(context, taskId, notif.notificationId),
              icon: Icon(hasResponded && decision == 'accepted'
                  ? Icons.check_circle
                  : Icons.check),
              label: Text(decision == 'accepted' ? 'Accepted' : 'Accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: hasResponded
                  ? null
                  : () => _handleDeclineTask(
                        context,
                        taskId,
                        notif.notificationId,
                      ),
              icon: Icon(
                hasResponded && decision == 'declined'
                    ? Icons.block
                    : Icons.close,
              ),
              label: Text(decision == 'declined' ? 'Declined' : 'Decline'),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    decision == 'declined' ? Colors.orange : Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
      if (hasResponded) ...[
        const SizedBox(height: 8),
        Text(
          'Assignment request has been ${decision == 'accepted' ? 'accepted' : 'declined'}.',
          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
        ),
      ],
    ],
  );
}

Future<void> _handleAcceptTask(
  BuildContext context,
  String taskId,
  String notificationId,
) async {
  final taskProvider = Provider.of<TaskProvider>(context, listen: false);
  try {
    await taskProvider.acceptTask(taskId);
    await _markAssignmentDecision(
      notificationId: notificationId,
      decision: 'accepted',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task accepted!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _handleDeclineTask(
  BuildContext context,
  String taskId,
  String notificationId,
) async {
  final taskProvider = Provider.of<TaskProvider>(context, listen: false);
  try {
    await taskProvider.declineTask(taskId);
    await _markAssignmentDecision(
      notificationId: notificationId,
      decision: 'declined',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task declined'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error declining task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

bool _isTaskAssignmentNotification(InAppNotification notif) {
  final isTaskAssigned = notif.category == 'task_assigned';
  final hasTaskId = _notificationTaskId(notif).isNotEmpty;
  return isTaskAssigned && hasTaskId;
}

String _notificationTaskId(InAppNotification notif) {
  final relatedId = (notif.relatedId ?? '').trim();
  if (relatedId.isNotEmpty) return relatedId;
  final metadata = notif.metadata ?? const <String, dynamic>{};
  return (metadata['taskId']?.toString() ?? '').trim();
}

String _assignmentDecisionFromMetadata(InAppNotification notif) {
  final metadata = notif.metadata ?? const <String, dynamic>{};
  return (metadata['assignmentDecision']?.toString() ?? '').trim();
}

Future<void> _markAssignmentDecision({
  required String notificationId,
  required String decision,
}) async {
  await FirebaseFirestore.instance
      .collection('in_app_notifications')
      .doc(notificationId)
      .update({
    'metadata.assignmentDecision': decision,
    'metadata.assignmentRespondedAt': Timestamp.now(),
    'isRead': true,
    'readAt': Timestamp.now(),
  });
}

bool _isPokeNotification(InAppNotification notif) {
  final metadata = notif.metadata ?? const <String, dynamic>{};
  final kind = (metadata['kind']?.toString() ?? '').trim();
  final source = (metadata['source']?.toString() ?? '').trim();
  return (kind == 'poke' && (source.isEmpty || source == 'poke')) ||
      (metadata['type']?.toString() ?? '').contains('poke');
}

bool _isPokeReminderNotification(InAppNotification notif) {
  final metadata = notif.metadata ?? const <String, dynamic>{};
  return (metadata['kind']?.toString() ?? '').trim() == 'reminder' &&
      (metadata['source']?.toString() ?? '').trim() == 'poke';
}

Widget _buildPokeSummarySection(InAppNotification notif, Color accent) {
  final metadata = notif.metadata ?? const <String, dynamic>{};
  final subject = (metadata['subject']?.toString() ?? '').trim();
  final pokeMessage = (metadata['pokeMessage']?.toString() ?? '').trim();
  final timing = (metadata['pokeTiming']?.toString() ?? '').trim();
  final scheduledAtRaw = (metadata['scheduledAt']?.toString() ?? '').trim();
  final scheduledAt = scheduledAtRaw.isEmpty ? null : DateTime.tryParse(scheduledAtRaw);

  final timingLine = switch (timing.toLowerCase()) {
    'later' => scheduledAt != null
        ? 'Later - ${_formatDateTime(scheduledAt)}'
        : 'Later',
    'now' => 'Now',
    _ => '',
  };

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: accent.withValues(alpha: 0.28)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Poke Details',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
        if (subject.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Subject: $subject',
            style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600),
          ),
        ],
        if (pokeMessage.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Message: $pokeMessage', style: TextStyle(color: Colors.grey[800])),
        ],
        if (timingLine.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Timing: $timingLine', style: TextStyle(color: Colors.grey[700])),
        ],
      ],
    ),
  );
}

Widget _buildReminderSummarySection(InAppNotification notif, Color accent) {
  final metadata = notif.metadata ?? const <String, dynamic>{};
  final sender = (metadata['createdByUserName']?.toString() ?? '').trim();
  final targetType = (metadata['targetType']?.toString() ?? '').trim();
  final targetLabel = (metadata['targetLabel']?.toString() ?? '').trim();
  final actionNeeded = (metadata['actionNeeded']?.toString() ?? '').trim();
  final details = (metadata['details']?.toString() ?? '').trim();
  final timing = (metadata['pokeTiming']?.toString() ?? '').trim();
  final scheduledAtRaw = (metadata['scheduledAt']?.toString() ?? '').trim();
  final scheduledAt = scheduledAtRaw.isEmpty ? null : DateTime.tryParse(scheduledAtRaw);

  final targetLine = (targetType.isNotEmpty && targetLabel.isNotEmpty)
      ? '${_formatCategory(targetType)} $targetLabel'
      : targetLabel;
  final senderLabel = sender.isEmpty ? 'Someone' : sender;
  final summaryLine = targetLine.isEmpty
      ? '$senderLabel sent a reminder.'
      : '$senderLabel sent a reminder for $targetLine.';
  final timingLine = switch (timing.toLowerCase()) {
    'later' => scheduledAt != null
        ? 'Later - ${_formatDateTime(scheduledAt)}'
        : 'Later',
    'now' => 'Now',
    _ => '',
  };

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: accent.withValues(alpha: 0.28)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reminder Details',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
        const SizedBox(height: 6),
        Text(summaryLine, style: TextStyle(color: Colors.grey[800])),
        if (actionNeeded.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Action Needed: $actionNeeded',
            style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600),
          ),
        ],
        if (details.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Details: $details', style: TextStyle(color: Colors.grey[800])),
        ],
        if (timingLine.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Timing: $timingLine', style: TextStyle(color: Colors.grey[700])),
        ],
      ],
    ),
  );
}

