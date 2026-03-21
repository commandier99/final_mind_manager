import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../notifications/datasources/models/notification_model.dart';
import '../../../notifications/datasources/providers/notification_provider.dart';
import '../../../thoughts/datasources/models/thought_model.dart';
import '../../../thoughts/datasources/providers/thought_provider.dart';
import '../../datasources/models/task_model.dart';

class TaskAssignmentWorkflowHelper {
  static const String _managerToMember = 'manager_to_member';

  static bool requiresAcceptance({
    required String boardType,
    required String boardManagerId,
    required String? assigneeId,
  }) {
    final normalizedAssignee = (assigneeId ?? '').trim();
    return boardType.trim().toLowerCase() == 'team' &&
        normalizedAssignee.isNotEmpty &&
        normalizedAssignee != 'None' &&
        normalizedAssignee != boardManagerId;
  }

  static Future<void> createAssignmentRequestIfNeeded({
    required BuildContext context,
    required Task task,
    required String assigneeId,
    required String assigneeName,
    required String actorUserId,
    required String actorUserName,
  }) async {
    final normalizedAssigneeId = assigneeId.trim();
    if (normalizedAssigneeId.isEmpty || normalizedAssigneeId == 'None') return;
    if (normalizedAssigneeId == actorUserId) return;
    if (task.taskId.trim().isEmpty) return;

    final thoughtProvider = context.read<ThoughtProvider>();
    final notificationProvider = context.read<NotificationProvider>();
    final now = DateTime.now();
    final notificationSeed = const Uuid().v4();
    final cleanActorName = actorUserName.trim().isEmpty
        ? 'Manager'
        : actorUserName.trim();
    final cleanAssigneeName = assigneeName.trim().isEmpty
        ? 'Assigned Member'
        : assigneeName.trim();
    final taskTitle = task.taskTitle.trim().isEmpty ? 'Untitled Task' : task.taskTitle.trim();

    try {
      final thoughtId = await thoughtProvider.createThought(
        Thought(
          thoughtId: '',
          type: Thought.typeTaskAssignment,
          status: Thought.statusPending,
          scopeType: Thought.scopeTask,
          boardId: task.taskBoardId,
          taskId: task.taskId,
          authorId: actorUserId,
          authorName: cleanActorName,
          targetUserId: normalizedAssigneeId,
          targetUserName: cleanAssigneeName,
          title: 'Task Assignment for $taskTitle',
          message:
              '$cleanActorName assigned you to $taskTitle. Accept or decline this assignment.',
          createdAt: now,
          updatedAt: now,
          metadata: {
            'source': 'task_assignment_workflow',
            'notificationSeed': notificationSeed,
            'assignmentDirection': _managerToMember,
            'assignmentAssigneeId': normalizedAssigneeId,
            'assignmentAssigneeName': cleanAssigneeName,
            if ((task.taskBoardTitle ?? '').trim().isNotEmpty)
              'boardTitle': task.taskBoardTitle!.trim(),
            'taskTitle': taskTitle,
          },
        ),
      );

      await notificationProvider.createNotifications([
        AppNotification(
          notificationId: '',
          recipientUserId: normalizedAssigneeId,
          title: 'Task Assignment Received',
          message: '$cleanActorName assigned you to $taskTitle.',
          type: 'thought_task_assignment_received',
          deliveryStatus: AppNotification.deliveryPending,
          isRead: false,
          isDeleted: false,
          createdAt: now,
          updatedAt: now,
          actorUserId: actorUserId,
          actorUserName: cleanActorName,
          boardId: task.taskBoardId,
          taskId: task.taskId,
          thoughtId: thoughtId,
          eventKey:
              '$notificationSeed:$normalizedAssigneeId:thought_task_assignment_received',
          metadata: const {'assignmentDirection': _managerToMember},
        ),
      ]);
    } catch (e) {
      final errorText = e.toString().toLowerCase();
      if (errorText.contains('already pending') ||
          errorText.contains('already exists')) {
        return;
      }
      rethrow;
    }
  }
}
