import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../../boards/datasources/providers/board_provider.dart';
import '../../../../notifications/datasources/models/notification_model.dart';
import '../../../../notifications/datasources/providers/notification_provider.dart';
import '../../../../steps/datasources/services/step_services.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/models/task_stats_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/datasources/services/task_services.dart';
import '../../../../tasks/presentation/pages/task_details_page.dart';
import '../../../datasources/models/thought_model.dart';
import '../../../datasources/providers/thought_provider.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';

class ThoughtCard extends StatefulWidget {
  const ThoughtCard({
    super.key,
    required this.thought,
    this.isHighlighted = false,
  });

  final Thought thought;
  final bool isHighlighted;

  @override
  State<ThoughtCard> createState() => _ThoughtCardState();
}

class _ThoughtCardState extends State<ThoughtCard> {
  bool _isActing = false;
  final TaskService _taskService = TaskService();
  final StepService _stepService = StepService();

  @override
  Widget build(BuildContext context) {
    final thought = widget.thought;
    final statusStyle = _statusStyle(thought.status, context);
    final metadata = thought.metadata ?? const <String, dynamic>{};
    final boardTitle = _metadataValue(metadata, 'boardTitle');
    final taskTitle = _metadataValue(metadata, 'taskTitle');
    final targetName = thought.targetUserName?.trim() ?? '';
    final currentDeadline = _metadataDateValue(metadata, 'currentDeadline');
    final requestedDeadline = _metadataDateValue(metadata, 'requestedDeadline');
    final selectedUploads = _selectedUploads(metadata);
    final submissionState =
        (metadata['submissionState']?.toString() ?? '').trim().toLowerCase();
    final feedbackMessage = (metadata['feedbackMessage']?.toString() ?? '').trim();
    final canAccessUploads = _canAccessSubmissionUploads(
      thought,
      submissionState,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isHighlighted
            ? Colors.amber.shade50
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isHighlighted
              ? Colors.amber.shade300
              : Colors.grey.shade300,
          width: widget.isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  thought.title.trim().isEmpty ? 'Untitled Thought' : thought.title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusStyle.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _displayLabel(thought.status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusStyle.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            thought.message.trim().isEmpty ? 'No details yet.' : thought.message,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
          ),
          if (boardTitle != null || taskTitle != null || targetName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (boardTitle != null) _metaPill(Icons.dashboard_outlined, boardTitle),
                if (taskTitle != null) _metaPill(Icons.task_alt_outlined, taskTitle),
                if (targetName.isNotEmpty) _metaPill(Icons.person_outline, targetName),
              ],
            ),
          ],
          if (thought.type == Thought.typeTaskRequest &&
              (currentDeadline != null || requestedDeadline != null)) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (currentDeadline != null)
                  _metaPill(
                    Icons.event_busy_outlined,
                    'Current: ${_formatDateTimeLabel(currentDeadline)}',
                  ),
                if (requestedDeadline != null)
                  _metaPill(
                    Icons.event_available_outlined,
                    'Requested: ${_formatDateTimeLabel(requestedDeadline)}',
                  ),
              ],
            ),
          ],
          if (thought.type == Thought.typeSubmissionFeedback) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metaPill(
                  Icons.upload_file_outlined,
                  '${selectedUploads.length} upload(s)',
                ),
                if (submissionState.isNotEmpty)
                  _metaPill(Icons.rule_folder_outlined, submissionState.replaceAll('_', ' ')),
              ],
            ),
            if (selectedUploads.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                canAccessUploads
                    ? 'Files'
                    : 'Files are available after approval.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedUploads.map((upload) {
                  final fileName = upload['fileName'] ?? 'File';
                  final fileUrl = upload['fileUrl'] ?? '';
                  return OutlinedButton.icon(
                    onPressed: canAccessUploads && fileUrl.isNotEmpty
                        ? () => _openUpload(fileUrl)
                        : null,
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: Text(fileName),
                  );
                }).toList(),
              ),
            ],
            if (feedbackMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Feedback: $feedbackMessage',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  thought.authorName,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
              Text(
                _formatDate(thought.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          if (_actionButtons(thought).isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _actionButtons(thought),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _actionButtons(Thought thought) {
    if (_isActing || !thought.isActionable) return const [];

    switch (thought.type) {
      case Thought.typeReminder:
        if (thought.taskId.trim().isEmpty) return const [];
        return [
          _buildActionButton(
            label: 'Open Task',
            primary: true,
            onPressed: _openReferencedTask,
          ),
        ];
      case Thought.typeBoardRequest:
        if (!_canActOnBoardRequest(thought)) return const [];
        return [
          _buildActionButton(
            label: 'Accept',
            primary: true,
            onPressed: _acceptBoardRequest,
          ),
          _buildActionButton(
            label: 'Decline',
            onPressed: _declineBoardRequest,
          ),
        ];
      case Thought.typeTaskAssignment:
        if (!_canActOnTaskAssignment(thought)) return const [];
        return [
          _buildActionButton(
            label: 'Accept',
            primary: true,
            onPressed: _acceptTaskAssignment,
          ),
          _buildActionButton(
            label: 'Decline',
            onPressed: _declineTaskAssignment,
          ),
        ];
      case Thought.typeTaskRequest:
        if (!_canActOnTaskRequest(thought)) return const [];
        return [
          _buildActionButton(
            label: 'Accept',
            primary: true,
            onPressed: _acceptTaskRequest,
          ),
          _buildActionButton(
            label: 'Decline',
            onPressed: _declineTaskRequest,
          ),
        ];
      case Thought.typeSuggestion:
        return [
          _buildActionButton(
            label: 'Convert',
            primary: true,
            onPressed: _convertSuggestion,
          ),
          _buildActionButton(
            label: 'Delete',
            onPressed: _deleteThought,
          ),
        ];
      case Thought.typeSubmissionFeedback:
        if (!_canReviewSubmission(thought)) return const [];
        final metadata = thought.metadata ?? const <String, dynamic>{};
        final submissionState =
            (metadata['submissionState']?.toString() ?? '').trim().toLowerCase();
        if (submissionState != 'submitted') return const [];
        final deadlineMissed = metadata['deadlineMissed'] == true;
        return [
          _buildActionButton(
            label: 'Review',
            primary: true,
            onPressed: _reviewSubmission,
          ),
          if (deadlineMissed)
            _buildActionButton(
              label: 'Extend Deadline',
              onPressed: _extendSubmissionDeadline,
            ),
        ];
      default:
        return const [];
    }
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    bool primary = false,
  }) {
    if (primary) {
      return FilledButton(
        onPressed: onPressed,
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }

  Future<void> _deleteThought() async {
    final messenger = ScaffoldMessenger.of(context);
    final thoughtProvider = context.read<ThoughtProvider>();
    setState(() {
      _isActing = true;
    });

    try {
      await thoughtProvider.softDeleteThought(
        widget.thought.thoughtId,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Thought deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Failed to delete thought: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
        });
      }
    }
  }

  Future<void> _acceptBoardRequest() async {
    final messenger = ScaffoldMessenger.of(context);
    final boardProvider = context.read<BoardProvider>();
    final notificationProvider = context.read<NotificationProvider>();
    final thoughtProvider = context.read<ThoughtProvider>();
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No signed-in user found.')),
      );
      return;
    }

    final boardId = widget.thought.boardId.trim();
    final metadata = widget.thought.metadata ?? const <String, dynamic>{};
    final requestDirection = (metadata['requestDirection']?.toString() ?? '')
        .trim()
        .toLowerCase();
    final invitedRole = (metadata['invitedRole']?.toString() ?? 'member')
        .trim();
    final targetUserId = requestDirection == 'request_board_access'
        ? (metadata['requestedMemberId']?.toString() ?? '').trim()
        : (widget.thought.targetUserId?.trim() ?? '');
    if (boardId.isEmpty || targetUserId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This board request is missing board or member data.')),
      );
      return;
    }

    setState(() {
      _isActing = true;
    });

    try {
      await boardProvider.addMemberToBoard(
        boardId: boardId,
        userId: targetUserId,
        role: invitedRole,
        invitationThoughtId: widget.thought.thoughtId,
      );
      await thoughtProvider.updateThoughtStatus(
        thoughtId: widget.thought.thoughtId,
        status: Thought.statusAccepted,
        actionedBy: currentUser.userId,
        actionedByName: currentUser.userName,
      );
      await _createBoardRequestResponseNotifications(
        notificationProvider: notificationProvider,
        currentUserId: currentUser.userId,
        currentUserName: currentUser.userName,
        status: Thought.statusAccepted,
      );

      if (!mounted) return;
      final memberName = requestDirection == 'request_board_access'
          ? ((metadata['requestedMemberName']?.toString() ?? '').trim().isNotEmpty
                ? metadata['requestedMemberName'].toString().trim()
                : 'member')
          : (widget.thought.targetUserName?.trim().isNotEmpty == true
                ? widget.thought.targetUserName!.trim()
                : 'member');
      messenger.showSnackBar(
        SnackBar(content: Text('$memberName has been added to the board.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to accept board request: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
        });
      }
    }
  }

  Future<void> _declineBoardRequest() async {
    final messenger = ScaffoldMessenger.of(context);
    final boardProvider = context.read<BoardProvider>();
    final thoughtProvider = context.read<ThoughtProvider>();
    final notificationProvider = context.read<NotificationProvider>();
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No signed-in user found.')),
      );
      return;
    }

    setState(() {
      _isActing = true;
    });

    try {
      final boardId = widget.thought.boardId.trim();
      final metadata = widget.thought.metadata ?? const <String, dynamic>{};
      final requestDirection = (metadata['requestDirection']?.toString() ?? '')
          .trim()
          .toLowerCase();
      final invitedUserId = requestDirection == 'invite_member'
          ? (widget.thought.targetUserId?.trim() ?? '')
          : '';
      if (boardId.isNotEmpty && invitedUserId.isNotEmpty) {
        await boardProvider.clearPendingBoardInvite(
          boardId: boardId,
          userId: invitedUserId,
        );
      }
      await thoughtProvider.updateThoughtStatus(
        thoughtId: widget.thought.thoughtId,
        status: Thought.statusDeclined,
        actionedBy: currentUser.userId,
        actionedByName: currentUser.userName,
      );
      await _createBoardRequestResponseNotifications(
        notificationProvider: notificationProvider,
        currentUserId: currentUser.userId,
        currentUserName: currentUser.userName,
        status: Thought.statusDeclined,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Board request declined.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to decline board request: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
        });
      }
    }
  }

  Future<void> _acceptTaskAssignment() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final notificationProvider = context.read<NotificationProvider>();
    final taskProvider = context.read<TaskProvider>();
    final thoughtProvider = context.read<ThoughtProvider>();
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('No signed-in user found.')),
      );
      return;
    }

    final taskId = widget.thought.taskId.trim();
    final metadata = widget.thought.metadata ?? const <String, dynamic>{};
    final assigneeId =
        (metadata['assignmentAssigneeId']?.toString() ?? '').trim().isNotEmpty
        ? metadata['assignmentAssigneeId'].toString().trim()
        : (widget.thought.targetUserId?.trim() ?? '');
    final assigneeName =
        (metadata['assignmentAssigneeName']?.toString() ?? '').trim().isNotEmpty
        ? metadata['assignmentAssigneeName'].toString().trim()
        : (widget.thought.targetUserName?.trim() ?? '');
    if (taskId.isEmpty || assigneeId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('This assignment is missing task or member data.')),
      );
      return;
    }

    setState(() {
      _isActing = true;
    });

    try {
      await taskProvider.respondToTaskAssignment(
        taskId: taskId,
        accepted: true,
        assigneeId: assigneeId,
        assigneeName: assigneeName,
      );

      await thoughtProvider.updateThoughtStatus(
        thoughtId: widget.thought.thoughtId,
        status: Thought.statusAccepted,
        actionedBy: currentUser.userId,
        actionedByName: currentUser.userName,
      );
      await _createTaskAssignmentResponseNotifications(
        notificationProvider: notificationProvider,
        currentUserId: currentUser.userId,
        currentUserName: currentUser.userName,
        status: Thought.statusAccepted,
      );

      if (!mounted) return;
      final assigneeLabel = assigneeName.isEmpty ? 'member' : assigneeName;
      messenger?.showSnackBar(
        SnackBar(content: Text('Task assignment accepted for $assigneeLabel.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Failed to accept task assignment: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
        });
      }
    }
  }

  Future<void> _declineTaskAssignment() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final notificationProvider = context.read<NotificationProvider>();
    final taskProvider = context.read<TaskProvider>();
    final thoughtProvider = context.read<ThoughtProvider>();
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('No signed-in user found.')),
      );
      return;
    }

    setState(() {
      _isActing = true;
    });

    try {
      final taskId = widget.thought.taskId.trim();
      if (taskId.isNotEmpty) {
        await taskProvider.respondToTaskAssignment(
          taskId: taskId,
          accepted: false,
          assigneeId: '',
          assigneeName: '',
        );
      }

      await thoughtProvider.updateThoughtStatus(
        thoughtId: widget.thought.thoughtId,
        status: Thought.statusDeclined,
        actionedBy: currentUser.userId,
        actionedByName: currentUser.userName,
      );
      await _createTaskAssignmentResponseNotifications(
        notificationProvider: notificationProvider,
        currentUserId: currentUser.userId,
        currentUserName: currentUser.userName,
        status: Thought.statusDeclined,
      );

      if (!mounted) return;
      messenger?.showSnackBar(
        const SnackBar(content: Text('Task assignment declined.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Failed to decline task assignment: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
        });
      }
    }
  }

  Future<void> _acceptTaskRequest() async {
    final messenger = ScaffoldMessenger.of(context);
    final notificationProvider = context.read<NotificationProvider>();
    final taskProvider = context.read<TaskProvider>();
    final thoughtProvider = context.read<ThoughtProvider>();
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No signed-in user found.')),
      );
      return;
    }

    final metadata = widget.thought.metadata ?? const <String, dynamic>{};
    final requestKind = (metadata['requestKind']?.toString() ?? '')
        .trim()
        .toLowerCase();
    if (requestKind != 'deadline_extension') {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unsupported task request type.')),
      );
      return;
    }

    final requestedDeadlineRaw =
        (metadata['requestedDeadline']?.toString() ?? '').trim();
    final requestedDeadline = DateTime.tryParse(requestedDeadlineRaw);
    final currentDeadline = DateTime.tryParse(
      (metadata['currentDeadline']?.toString() ?? '').trim(),
    );
    final taskId = widget.thought.taskId.trim();
    if (taskId.isEmpty || requestedDeadline == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This request is missing deadline data.')),
      );
      return;
    }

    setState(() {
      _isActing = true;
    });

    try {
      final approvedDeadline = await _showDeadlineApprovalDialog(
        currentDeadline: currentDeadline,
        requestedDeadline: requestedDeadline,
      );
      if (!mounted || approvedDeadline == null) {
        return;
      }

      final task = await _taskService.getTaskById(taskId);
      if (task == null) {
        throw StateError('Task not found.');
      }

      await taskProvider.updateTask(
        task.copyWith(
          taskDeadline: approvedDeadline,
          taskDeadlineMissed: false,
          taskExtensionCount: task.taskExtensionCount + 1,
        ),
      );

      await thoughtProvider.updateThought(
        widget.thought.copyWith(
          status: Thought.statusAccepted,
          updatedAt: DateTime.now(),
          actionedAt: DateTime.now(),
          actionedBy: currentUser.userId,
          actionedByName: currentUser.userName,
          metadata: {
            ...metadata,
            'approvedDeadline': approvedDeadline.toIso8601String(),
          },
        ),
      );
      await _createTaskRequestResponseNotifications(
        notificationProvider: notificationProvider,
        currentUserId: currentUser.userId,
        currentUserName: currentUser.userName,
        status: Thought.statusAccepted,
        approvedDeadline: approvedDeadline,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Deadline extension approved for ${_formatDateTimeLabel(approvedDeadline)}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to accept task request: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
        });
      }
    }
  }

  Future<void> _declineTaskRequest() async {
    final messenger = ScaffoldMessenger.of(context);
    final notificationProvider = context.read<NotificationProvider>();
    final thoughtProvider = context.read<ThoughtProvider>();
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No signed-in user found.')),
      );
      return;
    }

    setState(() {
      _isActing = true;
    });

    try {
      await thoughtProvider.updateThoughtStatus(
        thoughtId: widget.thought.thoughtId,
        status: Thought.statusDeclined,
        actionedBy: currentUser.userId,
        actionedByName: currentUser.userName,
      );
      await _createTaskRequestResponseNotifications(
        notificationProvider: notificationProvider,
        currentUserId: currentUser.userId,
        currentUserName: currentUser.userName,
        status: Thought.statusDeclined,
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Task request declined.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to decline task request: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
        });
      }
    }
  }

  Future<void> _convertSuggestion() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final boardProvider = context.read<BoardProvider>();
    final taskProvider = context.read<TaskProvider>();
    final thoughtProvider = context.read<ThoughtProvider>();
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No signed-in user found.')),
      );
      return;
    }

    setState(() {
      _isActing = true;
    });

    try {
      final metadata = Map<String, dynamic>.from(
        widget.thought.metadata ?? const <String, dynamic>{},
      );
      final suggestionTarget = (metadata['suggestionTarget']?.toString() ?? '')
          .trim()
          .toLowerCase();

      if (suggestionTarget == 'step' && widget.thought.taskId.trim().isNotEmpty) {
        await _stepService.addStep(
          stepTaskId: widget.thought.taskId.trim(),
          stepBoardId: widget.thought.boardId.trim(),
          stepTitle: widget.thought.title.trim(),
          stepDescription: widget.thought.message.trim(),
        );

        metadata['convertedEntityType'] = 'step';
      } else {
        final board = boardProvider.getBoardById(widget.thought.boardId.trim());
        if (board == null) {
          throw StateError('Board not found for this suggestion.');
        }

        final isPersonalBoard = board.boardType.trim().toLowerCase() == 'personal';
        final taskId = const Uuid().v4();
        final createdTask = Task(
          taskId: taskId,
          taskBoardId: board.boardId,
          taskBoardTitle: board.boardTitle,
          taskOwnerId: currentUser.userId,
          taskOwnerName: currentUser.userName.trim().isEmpty
              ? 'Unknown'
              : currentUser.userName.trim(),
          taskAssignedBy: currentUser.userId,
          taskAssignedTo: isPersonalBoard ? currentUser.userId : 'None',
          taskAssignedToName: isPersonalBoard
              ? (currentUser.userName.trim().isEmpty
                    ? 'Unknown'
                    : currentUser.userName.trim())
              : 'Unassigned',
          taskCreatedAt: DateTime.now(),
          taskTitle: widget.thought.title.trim().isEmpty
              ? 'Untitled Task'
              : widget.thought.title.trim(),
          taskDescription: widget.thought.message.trim(),
          taskStats: TaskStats(),
          taskBoardLane: isPersonalBoard ? Task.lanePublished : Task.laneDrafts,
        );

        await taskProvider.addTask(createdTask);
        metadata['convertedEntityType'] = 'task';
        metadata['convertedTaskId'] = createdTask.taskId;
        metadata['taskTitle'] = createdTask.taskTitle;
      }

      await thoughtProvider.updateThought(
        widget.thought.copyWith(
          status: Thought.statusConverted,
          updatedAt: DateTime.now(),
          actionedAt: DateTime.now(),
          actionedBy: currentUser.userId,
          actionedByName: currentUser.userName,
          metadata: metadata,
        ),
      );

      if (!mounted) return;
      final convertedType = metadata['convertedEntityType']?.toString() ?? 'item';
      messenger.showSnackBar(
        SnackBar(content: Text('Suggestion converted into a $convertedType.')),
      );

      if (convertedType == 'task') {
        final convertedTaskId = metadata['convertedTaskId']?.toString() ?? '';
        if (convertedTaskId.isNotEmpty) {
          final convertedTask = await _taskService.getTaskById(convertedTaskId);
          if (!mounted || convertedTask == null) return;
          navigator.push(
            MaterialPageRoute(builder: (_) => TaskDetailsPage(task: convertedTask)),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Failed to convert suggestion: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
        });
      }
    }
  }

  Future<void> _openReferencedTask() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final taskId = widget.thought.taskId.trim();
    if (taskId.isEmpty) return;

    setState(() {
      _isActing = true;
    });

    try {
      final task = await _taskService.getTaskById(taskId);
      if (!mounted) return;
      if (task == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Referenced task could not be found.')),
        );
        return;
      }

      navigator.push(
        MaterialPageRoute(builder: (_) => TaskDetailsPage(task: task)),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Failed to open task: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
        });
      }
    }
  }

  bool _canReviewSubmission(Thought thought) {
    final currentUserId = context.read<UserProvider>().userId ?? '';
    if (currentUserId.isEmpty) return false;
    if (thought.boardId.trim().isEmpty) {
      return currentUserId == thought.targetUserId;
    }
    final board = context.read<BoardProvider>().getBoardById(thought.boardId);
    return board?.isManager(currentUserId) == true;
  }

  bool _canActOnBoardRequest(Thought thought) {
    final currentUserId = context.read<UserProvider>().userId ?? '';
    if (currentUserId.isEmpty) return false;
    final targetUserId = (thought.targetUserId ?? '').trim();
    if (targetUserId.isNotEmpty) {
      return currentUserId == targetUserId;
    }
    if (thought.boardId.trim().isEmpty) return false;
    final board = context.read<BoardProvider>().getBoardById(thought.boardId);
    return board?.isManager(currentUserId) == true;
  }

  bool _canActOnTaskAssignment(Thought thought) {
    final currentUserId = context.read<UserProvider>().userId ?? '';
    if (currentUserId.isEmpty) return false;
    final targetUserId = (thought.targetUserId ?? '').trim();
    if (targetUserId.isNotEmpty) return currentUserId == targetUserId;
    final metadata = thought.metadata ?? const <String, dynamic>{};
    final assigneeId = (metadata['assignmentAssigneeId']?.toString() ?? '')
        .trim();
    if (assigneeId.isNotEmpty) return currentUserId == assigneeId;
    return false;
  }

  bool _canActOnTaskRequest(Thought thought) {
    final currentUserId = context.read<UserProvider>().userId ?? '';
    if (currentUserId.isEmpty) return false;
    final targetUserId = (thought.targetUserId ?? '').trim();
    if (targetUserId.isNotEmpty) return currentUserId == targetUserId;
    if (thought.boardId.trim().isEmpty) return false;
    final board = context.read<BoardProvider>().getBoardById(thought.boardId);
    return board?.isManager(currentUserId) == true;
  }

  bool _canAccessSubmissionUploads(Thought thought, String submissionState) {
    final currentUserId = context.read<UserProvider>().userId ?? '';
    if (currentUserId.isEmpty) return false;
    final isOwnSubmission = thought.authorId == currentUserId;
    if (thought.boardId.trim().isEmpty) {
      return isOwnSubmission || submissionState == 'approved';
    }
    final board = context.read<BoardProvider>().getBoardById(thought.boardId);
    final isManager = board?.isManager(currentUserId) == true;
    return isManager || isOwnSubmission || submissionState == 'approved';
  }

  List<Map<String, String>> _selectedUploads(Map<String, dynamic> metadata) {
    final raw = metadata['selectedUploads'];
    if (raw is! List) return const <Map<String, String>>[];
    return raw
        .whereType<Map>()
        .map(
          (entry) => {
            'uploadId': (entry['uploadId']?.toString() ?? '').trim(),
            'fileName': (entry['fileName']?.toString() ?? '').trim(),
            'fileUrl': (entry['fileUrl']?.toString() ?? '').trim(),
          },
        )
        .toList();
  }

  Future<void> _openUpload(String fileUrl) async {
    final uri = Uri.tryParse(fileUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _reviewSubmission() async {
    final messenger = ScaffoldMessenger.of(context);
    final thoughtProvider = context.read<ThoughtProvider>();
    final taskProvider = context.read<TaskProvider>();
    final notificationProvider = context.read<NotificationProvider>();
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No signed-in user found.')),
      );
      return;
    }

    final review = await _showSubmissionReviewDialog();
    if (!mounted || review == null) return;

    setState(() {
      _isActing = true;
    });

    try {
      final task = await _taskService.getTaskById(widget.thought.taskId);
      if (task == null) {
        throw StateError('Task not found.');
      }

      final metadata = Map<String, dynamic>.from(
        widget.thought.metadata ?? const <String, dynamic>{},
      );
      final now = DateTime.now();
      String submissionState = 'approved';
      String thoughtStatus = Thought.statusAccepted;
      Task updatedTask = task.copyWith(
        taskLatestSubmissionThoughtId: widget.thought.thoughtId,
      );

      switch (review.verdict) {
        case _SubmissionVerdict.success:
          submissionState = 'approved';
          thoughtStatus = Thought.statusAccepted;
          updatedTask = updatedTask.copyWith(
            taskIsDone: true,
            taskIsDoneAt: now,
            taskStatus: Task.statusCompleted,
            taskOutcome: Task.outcomeSuccessful,
            taskFailed: false,
            taskApprovalStatus: 'approved',
          );
          break;
        case _SubmissionVerdict.failure:
          submissionState = 'rejected';
          thoughtStatus = Thought.statusDeclined;
          updatedTask = updatedTask.copyWith(
            taskIsDone: false,
            taskIsDoneAt: null,
            taskStatus: Task.statusRejected,
            taskOutcome: Task.outcomeFailed,
            taskFailed: true,
            taskApprovalStatus: 'rejected',
          );
          break;
        case _SubmissionVerdict.needsRevision:
          submissionState = 'changes_requested';
          thoughtStatus = Thought.statusDeclined;
          updatedTask = updatedTask.copyWith(
            taskIsDone: false,
            taskIsDoneAt: null,
            taskStatus: Task.statusPaused,
            taskOutcome: Task.outcomeNone,
            taskFailed: false,
            taskApprovalStatus: 'changes_requested',
          );
          break;
      }

      await taskProvider.updateTask(updatedTask);
      await thoughtProvider.updateThought(
        widget.thought.copyWith(
          status: thoughtStatus,
          updatedAt: now,
          actionedAt: now,
          actionedBy: currentUser.userId,
          actionedByName: currentUser.userName,
          metadata: {
            ...metadata,
            'submissionState': submissionState,
            'feedbackMessage': review.feedback.trim(),
            'verdict': review.verdict.name,
            'reviewedByUserId': currentUser.userId,
            'reviewedByUserName': currentUser.userName,
            'reviewedAt': now.toIso8601String(),
          },
        ),
      );

      await _createSubmissionReviewNotification(
        notificationProvider: notificationProvider,
        reviewerId: currentUser.userId,
        reviewerName: currentUser.userName,
        verdict: review.verdict,
        feedback: review.feedback.trim(),
      );

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Submission marked as ${review.verdict.label}.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to review submission: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
        });
      }
    }
  }

  Future<void> _extendSubmissionDeadline() async {
    final messenger = ScaffoldMessenger.of(context);
    final thoughtProvider = context.read<ThoughtProvider>();
    final taskProvider = context.read<TaskProvider>();
    final notificationProvider = context.read<NotificationProvider>();
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No signed-in user found.')),
      );
      return;
    }

    setState(() {
      _isActing = true;
    });

    try {
      final metadata = Map<String, dynamic>.from(
        widget.thought.metadata ?? const <String, dynamic>{},
      );
      final task = await _taskService.getTaskById(widget.thought.taskId);
      if (task == null) {
        throw StateError('Task not found.');
      }

      final currentDeadline = _metadataDateValue(metadata, 'currentDeadline') ?? task.taskDeadline;
      final approvedDeadline = await _showDeadlineExtensionDialog(
        currentDeadline: currentDeadline,
      );
      if (!mounted || approvedDeadline == null) {
        return;
      }

      await taskProvider.updateTask(
        task.copyWith(
          taskDeadline: approvedDeadline,
          taskDeadlineMissed: false,
          taskExtensionCount: task.taskExtensionCount + 1,
          taskStatus: _restoredTaskStatus(
            metadata['previousTaskStatus']?.toString(),
          ),
          taskApprovalStatus: 'none',
          taskLatestSubmissionThoughtId: null,
        ),
      );

      await thoughtProvider.updateThought(
        widget.thought.copyWith(
          status: Thought.statusResolved,
          updatedAt: DateTime.now(),
          actionedAt: DateTime.now(),
          actionedBy: currentUser.userId,
          actionedByName: currentUser.userName,
          metadata: {
            ...metadata,
            'submissionState': 'deadline_extended',
            'feedbackMessage':
                'Deadline extended to ${_formatDateTimeLabel(approvedDeadline)}.',
            'approvedDeadline': approvedDeadline.toIso8601String(),
            'reviewedByUserId': currentUser.userId,
            'reviewedByUserName': currentUser.userName,
            'reviewedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      await notificationProvider.createNotification(
        AppNotification(
          notificationId: '',
          recipientUserId: widget.thought.authorId,
          title: 'Deadline Extended',
          message:
              '${currentUser.userName} extended the deadline for ${_metadataValue(metadata, 'taskTitle') ?? 'the task'} until ${_formatDateTimeLabel(approvedDeadline)}.',
          type: 'thought_submission_deadline_extended',
          deliveryStatus: AppNotification.deliveryPending,
          isRead: false,
          isDeleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          actorUserId: currentUser.userId,
          actorUserName: currentUser.userName,
          boardId: widget.thought.boardId.trim().isEmpty ? null : widget.thought.boardId,
          taskId: widget.thought.taskId.trim().isEmpty ? null : widget.thought.taskId,
          thoughtId: widget.thought.thoughtId,
          metadata: {
            'thoughtType': Thought.typeSubmissionFeedback,
            'approvedDeadline': approvedDeadline.toIso8601String(),
          },
        ),
      );

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Deadline extended to ${_formatDateTimeLabel(approvedDeadline)}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to extend deadline: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
        });
      }
    }
  }

  Future<_SubmissionReviewResult?> _showSubmissionReviewDialog() async {
    final feedbackController = TextEditingController();
    var verdict = _SubmissionVerdict.success;

    final result = await showDialog<_SubmissionReviewResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Review Submission'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _SubmissionVerdict.values
                          .map(
                            (value) => ChoiceChip(
                              label: Text(value.segmentLabel),
                              selected: verdict == value,
                              onSelected: (_) {
                                setDialogState(() {
                                  verdict = value;
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: feedbackController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Feedback',
                        border: OutlineInputBorder(),
                        hintText: 'Leave feedback for the member.',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(
                    _SubmissionReviewResult(
                      verdict: verdict,
                      feedback: feedbackController.text,
                    ),
                  ),
                  child: const Text('Save Review'),
                ),
              ],
            );
          },
        );
      },
    );
    feedbackController.dispose();
    return result;
  }

  Widget _metaPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  String? _metadataValue(Map<String, dynamic> metadata, String key) {
    final value = metadata[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  String _displayLabel(String status) {
    switch (status) {
      case Thought.statusOpen:
        return 'Open';
      case Thought.statusPending:
        return 'Pending';
      case Thought.statusAccepted:
        return 'Accepted';
      case Thought.statusDeclined:
        return 'Declined';
      case Thought.statusResolved:
        return 'Resolved';
      case Thought.statusConverted:
        return 'Converted';
      default:
        return status;
    }
  }

  _StatusStyle _statusStyle(String status, BuildContext context) {
    switch (status) {
      case Thought.statusAccepted:
        return const _StatusStyle(Color(0xFFE6F4EA), Color(0xFF1B5E20));
      case Thought.statusDeclined:
        return const _StatusStyle(Color(0xFFFDECEA), Color(0xFFB3261E));
      case Thought.statusResolved:
        return const _StatusStyle(Color(0xFFE8F0FE), Color(0xFF174EA6));
      case Thought.statusConverted:
        return const _StatusStyle(Color(0xFFFFF4E5), Color(0xFF9A6700));
      case Thought.statusPending:
        return const _StatusStyle(Color(0xFFF3E8FF), Color(0xFF6B21A8));
      case Thought.statusOpen:
      default:
        return _StatusStyle(
          Theme.of(context).colorScheme.primaryContainer,
          Theme.of(context).colorScheme.primary,
        );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatDateTimeLabel(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$month/$day/$year $hour:$minute $suffix';
  }

  DateTime? _metadataDateValue(Map<String, dynamic> metadata, String key) {
    final raw = (metadata[key]?.toString() ?? '').trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<DateTime?> _showDeadlineApprovalDialog({
    required DateTime? currentDeadline,
    required DateTime requestedDeadline,
  }) async {
    var selectedDeadline = requestedDeadline;

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDeadline,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked == null) return;
              setDialogState(() {
                selectedDeadline = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  selectedDeadline.hour,
                  selectedDeadline.minute,
                );
              });
            }

            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(selectedDeadline),
              );
              if (picked == null) return;
              setDialogState(() {
                selectedDeadline = DateTime(
                  selectedDeadline.year,
                  selectedDeadline.month,
                  selectedDeadline.day,
                  picked.hour,
                  picked.minute,
                );
              });
            }

            return AlertDialog(
              title: const Text('Approve Extension'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (currentDeadline != null)
                      Text('Current deadline: ${_formatDateTimeLabel(currentDeadline)}'),
                    const SizedBox(height: 8),
                    Text(
                      'Requested deadline: ${_formatDateTimeLabel(requestedDeadline)}',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Approved deadline',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickDate,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(_formatDateTimeLabel(selectedDeadline).split(' ').first),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickTime,
                            icon: const Icon(Icons.schedule_outlined),
                            label: Text(TimeOfDay.fromDateTime(selectedDeadline).format(context)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You can approve the suggested deadline or choose a different date and time.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      selectedDeadline = requestedDeadline;
                    });
                  },
                  child: const Text('Use Suggested'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(selectedDeadline),
                  child: const Text('Approve'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<DateTime?> _showDeadlineExtensionDialog({
    required DateTime? currentDeadline,
  }) async {
    final initialDeadline =
        currentDeadline?.add(const Duration(days: 1)) ??
        DateTime.now().add(const Duration(days: 1));
    var selectedDeadline = initialDeadline;

    return showDialog<DateTime>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDeadline,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked == null) return;
              setDialogState(() {
                selectedDeadline = DateTime(
                  picked.year,
                  picked.month,
                  picked.day,
                  selectedDeadline.hour,
                  selectedDeadline.minute,
                );
              });
            }

            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(selectedDeadline),
              );
              if (picked == null) return;
              setDialogState(() {
                selectedDeadline = DateTime(
                  selectedDeadline.year,
                  selectedDeadline.month,
                  selectedDeadline.day,
                  picked.hour,
                  picked.minute,
                );
              });
            }

            return AlertDialog(
              title: const Text('Extend Deadline'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (currentDeadline != null)
                      Text(
                        'Current deadline: ${_formatDateTimeLabel(currentDeadline)}',
                      ),
                    const SizedBox(height: 16),
                    Text(
                      'New deadline',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickDate,
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              _formatDateTimeLabel(selectedDeadline).split(' ').first,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickTime,
                            icon: const Icon(Icons.schedule_outlined),
                            label: Text(
                              TimeOfDay.fromDateTime(selectedDeadline).format(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(selectedDeadline),
                  child: const Text('Extend'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _restoredTaskStatus(String? rawStatus) {
    final normalized = Task.normalizeTaskStatus(rawStatus ?? Task.statusPaused);
    if (normalized == Task.statusCompleted || normalized == Task.statusSubmitted) {
      return Task.statusPaused;
    }
    return normalized;
  }

  Future<void> _createBoardRequestResponseNotifications({
    required NotificationProvider notificationProvider,
    required String currentUserId,
    required String currentUserName,
    required String status,
  }) async {
    final metadata = widget.thought.metadata ?? const <String, dynamic>{};
    final requestDirection = (metadata['requestDirection']?.toString() ?? '')
        .trim()
        .toLowerCase();
    final boardTitle =
        _metadataValue(metadata, 'boardTitle') ?? 'the board';
    final notificationSeed =
        (metadata['notificationSeed']?.toString() ?? '').trim().isNotEmpty
        ? metadata['notificationSeed'].toString().trim()
        : const Uuid().v4();

    final recipientUserId = requestDirection == 'request_board_access'
        ? (metadata['requestedMemberId']?.toString() ?? '').trim()
        : (widget.thought.authorId.trim());
    if (recipientUserId.isEmpty || recipientUserId == currentUserId) return;

    final isAccepted = status == Thought.statusAccepted;
    final type = requestDirection == 'request_board_access'
        ? (isAccepted
              ? 'thought_board_request_accepted'
              : 'thought_board_request_declined')
        : (isAccepted
              ? 'thought_board_invite_accepted'
              : 'thought_board_invite_declined');
    final title = requestDirection == 'request_board_access'
        ? (isAccepted
              ? 'Board Access Request Accepted'
              : 'Board Access Request Declined')
        : (isAccepted ? 'Board Invite Accepted' : 'Board Invite Declined');
    final message = requestDirection == 'request_board_access'
        ? (isAccepted
              ? '$currentUserName approved your request to join $boardTitle.'
              : '$currentUserName declined your request to join $boardTitle.')
        : (isAccepted
              ? '$currentUserName accepted your invite to join $boardTitle.'
              : '$currentUserName declined your invite to join $boardTitle.');

    try {
      await notificationProvider.createNotification(
        AppNotification(
          notificationId: '',
          recipientUserId: recipientUserId,
          title: title,
          message: message,
          type: type,
          deliveryStatus: AppNotification.deliveryPending,
          isRead: false,
          isDeleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          actorUserId: currentUserId,
          actorUserName: currentUserName,
          thoughtId: widget.thought.thoughtId,
          eventKey: '$notificationSeed:$recipientUserId:$type',
          metadata: {
            'thoughtType': widget.thought.type,
            'requestDirection': requestDirection,
            if ((metadata['invitedRole']?.toString() ?? '').trim().isNotEmpty)
              'role': metadata['invitedRole'].toString(),
          },
        ),
      );
    } catch (_) {
      // Response action remains valid even if notification fanout fails.
    }
  }

  Future<void> _createTaskAssignmentResponseNotifications({
    required NotificationProvider notificationProvider,
    required String currentUserId,
    required String currentUserName,
    required String status,
  }) async {
    final metadata = widget.thought.metadata ?? const <String, dynamic>{};
    final assignmentDirection =
        (metadata['assignmentDirection']?.toString() ?? '').trim().toLowerCase();
    final notificationSeed =
        (metadata['notificationSeed']?.toString() ?? '').trim().isNotEmpty
        ? metadata['notificationSeed'].toString().trim()
        : const Uuid().v4();
    final taskTitle = _metadataValue(metadata, 'taskTitle') ?? 'the task';
    final isAccepted = status == Thought.statusAccepted;

    final recipientUserId = assignmentDirection == 'member_to_manager'
        ? widget.thought.authorId.trim()
        : (widget.thought.authorId.trim());
    if (recipientUserId.isEmpty || recipientUserId == currentUserId) return;

    final type = assignmentDirection == 'member_to_manager'
        ? (isAccepted
              ? 'thought_task_request_accepted'
              : 'thought_task_request_declined')
        : (isAccepted
              ? 'thought_task_assignment_accepted'
              : 'thought_task_assignment_declined');
    final title = assignmentDirection == 'member_to_manager'
        ? (isAccepted ? 'Task Request Accepted' : 'Task Request Declined')
        : (isAccepted ? 'Task Assignment Accepted' : 'Task Assignment Declined');
    final message = assignmentDirection == 'member_to_manager'
        ? (isAccepted
              ? '$currentUserName approved your request for $taskTitle.'
              : '$currentUserName declined your request for $taskTitle.')
        : (isAccepted
              ? '$currentUserName accepted the assignment for $taskTitle.'
              : '$currentUserName declined the assignment for $taskTitle.');

    try {
      await notificationProvider.createNotification(
        AppNotification(
          notificationId: '',
          recipientUserId: recipientUserId,
          title: title,
          message: message,
          type: type,
          deliveryStatus: AppNotification.deliveryPending,
          isRead: false,
          isDeleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          actorUserId: currentUserId,
          actorUserName: currentUserName,
          boardId: widget.thought.boardId.isEmpty ? null : widget.thought.boardId,
          taskId: widget.thought.taskId.isEmpty ? null : widget.thought.taskId,
          thoughtId: widget.thought.thoughtId,
          eventKey: '$notificationSeed:$recipientUserId:$type',
          metadata: {
            'thoughtType': widget.thought.type,
            'assignmentDirection': assignmentDirection,
          },
        ),
      );
    } catch (_) {
      // Response action remains valid even if notification fanout fails.
    }
  }

  Future<void> _createTaskRequestResponseNotifications({
    required NotificationProvider notificationProvider,
    required String currentUserId,
    required String currentUserName,
    required String status,
    DateTime? approvedDeadline,
  }) async {
    final metadata = widget.thought.metadata ?? const <String, dynamic>{};
    final requestKind = (metadata['requestKind']?.toString() ?? '')
        .trim()
        .toLowerCase();
    if (requestKind != 'deadline_extension') return;

    final notificationSeed =
        (metadata['notificationSeed']?.toString() ?? '').trim().isNotEmpty
        ? metadata['notificationSeed'].toString().trim()
        : const Uuid().v4();
    final taskTitle = _metadataValue(metadata, 'taskTitle') ?? 'the task';
    final recipientUserId = widget.thought.authorId.trim();
    if (recipientUserId.isEmpty || recipientUserId == currentUserId) return;

    final requestedDeadline = (metadata['requestedDeadline']?.toString() ?? '').trim();
    final isAccepted = status == Thought.statusAccepted;
    final type = isAccepted
        ? 'thought_deadline_extension_request_accepted'
        : 'thought_deadline_extension_request_declined';
    final title = isAccepted
        ? 'Deadline Extension Approved'
        : 'Deadline Extension Declined';
    final message = isAccepted
        ? approvedDeadline != null
              ? '$currentUserName approved your extension request for $taskTitle until ${_formatDateTimeLabel(approvedDeadline)}.'
              : '$currentUserName approved your extension request for $taskTitle.'
        : '$currentUserName declined your extension request for $taskTitle.';

    try {
      await notificationProvider.createNotification(
        AppNotification(
          notificationId: '',
          recipientUserId: recipientUserId,
          title: title,
          message: message,
          type: type,
          deliveryStatus: AppNotification.deliveryPending,
          isRead: false,
          isDeleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          actorUserId: currentUserId,
          actorUserName: currentUserName,
          boardId: widget.thought.boardId.isEmpty ? null : widget.thought.boardId,
          taskId: widget.thought.taskId.isEmpty ? null : widget.thought.taskId,
          thoughtId: widget.thought.thoughtId,
          eventKey: '$notificationSeed:$recipientUserId:$type',
          metadata: {
            'thoughtType': widget.thought.type,
            'requestKind': requestKind,
            if (requestedDeadline.isNotEmpty) 'requestedDeadline': requestedDeadline,
            if (approvedDeadline != null)
              'approvedDeadline': approvedDeadline.toIso8601String(),
          },
        ),
      );
    } catch (_) {
      // Request action remains valid even if notification fanout fails.
    }
  }

  Future<void> _createSubmissionReviewNotification({
    required NotificationProvider notificationProvider,
    required String reviewerId,
    required String reviewerName,
    required _SubmissionVerdict verdict,
    required String feedback,
  }) async {
    final metadata = widget.thought.metadata ?? const <String, dynamic>{};
    final notificationSeed =
        (metadata['notificationSeed']?.toString() ?? '').trim().isNotEmpty
        ? metadata['notificationSeed'].toString().trim()
        : const Uuid().v4();
    final recipientUserId = widget.thought.authorId.trim();
    if (recipientUserId.isEmpty || recipientUserId == reviewerId) return;

    final title = switch (verdict) {
      _SubmissionVerdict.success => 'Submission Approved',
      _SubmissionVerdict.failure => 'Submission Failed',
      _SubmissionVerdict.needsRevision => 'Revisions Requested',
    };
    final message = switch (verdict) {
      _SubmissionVerdict.success =>
        '$reviewerName marked your submission for ${_metadataValue(metadata, 'taskTitle') ?? 'the task'} as successful.',
      _SubmissionVerdict.failure =>
        '$reviewerName marked your submission for ${_metadataValue(metadata, 'taskTitle') ?? 'the task'} as failed.',
      _SubmissionVerdict.needsRevision =>
        '$reviewerName requested revisions for ${_metadataValue(metadata, 'taskTitle') ?? 'the task'}.',
    };

    try {
      await notificationProvider.createNotification(
        AppNotification(
          notificationId: '',
          recipientUserId: recipientUserId,
          title: title,
          message: message,
          type: 'thought_submission_reviewed',
          deliveryStatus: AppNotification.deliveryPending,
          isRead: false,
          isDeleted: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          actorUserId: reviewerId,
          actorUserName: reviewerName,
          boardId: widget.thought.boardId.isEmpty ? null : widget.thought.boardId,
          taskId: widget.thought.taskId.isEmpty ? null : widget.thought.taskId,
          thoughtId: widget.thought.thoughtId,
          eventKey: '$notificationSeed:$recipientUserId:thought_submission_reviewed:${verdict.name}',
          metadata: {
            'thoughtType': widget.thought.type,
            'verdict': verdict.name,
            if (feedback.isNotEmpty) 'feedbackMessage': feedback,
          },
        ),
      );
    } catch (_) {
      // Review action remains valid even if notification fanout fails.
    }
  }
}

enum _SubmissionVerdict { success, failure, needsRevision }

extension on _SubmissionVerdict {
  String get label {
    switch (this) {
      case _SubmissionVerdict.success:
        return 'approved';
      case _SubmissionVerdict.failure:
        return 'rejected';
      case _SubmissionVerdict.needsRevision:
        return 'needs revisions';
    }
  }

  String get segmentLabel {
    switch (this) {
      case _SubmissionVerdict.success:
        return 'Approve';
      case _SubmissionVerdict.failure:
        return 'Reject';
      case _SubmissionVerdict.needsRevision:
        return 'Needs Revision';
    }
  }
}

class _SubmissionReviewResult {
  const _SubmissionReviewResult({
    required this.verdict,
    required this.feedback,
  });

  final _SubmissionVerdict verdict;
  final String feedback;
}

class _StatusStyle {
  final Color background;
  final Color foreground;

  const _StatusStyle(this.background, this.foreground);
}
