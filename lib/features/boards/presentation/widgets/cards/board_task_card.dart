import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/datasources/services/task_application_service.dart';
import '../../../../tasks/presentation/pages/task_details_page.dart';
import '../../../../tasks/presentation/widgets/dialogs/edit_task_dialog.dart';
import '../../../../notifications/datasources/helpers/notification_helper.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../datasources/models/board_model.dart';

class BoardTaskCard extends StatefulWidget {
  final Task task;
  final Board? board;
  final String? currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final ValueChanged<bool?>? onToggleDone;
  final bool showCheckbox;
  final bool isDisabled;
  final VoidCallback? onPublish;
  final bool showPublishButton;
  final bool isPublishing;

  const BoardTaskCard({
    super.key,
    required this.task,
    this.board,
    this.currentUserId,
    this.onTap,
    this.onDelete,
    this.onToggleDone,
    this.showCheckbox = false,
    this.isDisabled = false,
    this.onPublish,
    this.showPublishButton = false,
    this.isPublishing = false,
  });

  @override
  State<BoardTaskCard> createState() => _BoardTaskCardState();
}

class _BoardTaskCardState extends State<BoardTaskCard> {
  late String _currentUserId;
  final TaskApplicationService _taskApplicationService =
      TaskApplicationService();
  bool _isPoking = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  bool _isTaskUnassigned() {
    return widget.task.taskAssignedTo.isEmpty ||
        widget.task.taskAssignedTo == 'None';
  }

  bool _shouldAllowUnassigned() {
    // Only allow unassigned status if there are multiple board members
    // If board has only 1 member (the manager), tasks must be assigned
    return widget.board == null || (widget.board!.memberIds.length > 1);
  }

  bool _canCurrentUserApply() {
    if (widget.board == null || widget.currentUserId == null) {
      return true;
    }
    // Managers should not apply to board tasks.
    return widget.currentUserId != widget.board!.boardManagerId;
  }

  List<String> _incompleteDependencyTitles(TaskProvider taskProvider) {
    if (widget.task.taskDependencyIds.isEmpty) return const <String>[];
    final byId = <String, Task>{
      for (final t in taskProvider.tasks) t.taskId: t,
    };
    final titles = <String>[];
    for (final dependencyId in widget.task.taskDependencyIds) {
      final dependencyTask = byId[dependencyId];
      if (dependencyTask == null || !dependencyTask.taskIsDone) {
        final title = dependencyTask?.taskTitle.trim();
        titles.add(
          (title != null && title.isNotEmpty) ? title : 'a prerequisite task',
        );
      }
    }
    return titles;
  }

  String _buildDependencyLockMessage(List<String> titles) {
    if (titles.isEmpty) return 'Complete prerequisites first.';
    if (titles.length == 1) return 'Complete "${titles.first}" first.';
    if (titles.length == 2) {
      return 'Complete "${titles[0]}" and "${titles[1]}" first.';
    }
    return 'Complete "${titles[0]}", "${titles[1]}", and ${titles.length - 2} more first.';
  }

  void _showApplicationDialog() {
    final applicationController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apply for Task'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Why are you a good fit for this task?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: applicationController,
                maxLines: 5,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share relevant skills or context...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final text = applicationController.text;
              Navigator.pop(dialogContext);
              _submitApplication(text);
            },
            icon: const Icon(Icons.how_to_reg),
            label: const Text('Apply'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Stream<bool> _isUserAppliedStream() {
    return _taskApplicationService.hasUserApplied(
      widget.task.taskId,
      _currentUserId,
    );
  }

  Future<void> _submitApplication(String applicationText) async {
    try {
      await _taskApplicationService.submitApplication(
        taskId: widget.task.taskId,
        userId: _currentUserId,
        applicationText: applicationText,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You cannot apply to this task.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _withdrawApplication() async {
    await _taskApplicationService.removeUserApplications(
      taskId: widget.task.taskId,
      userId: _currentUserId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application withdrawn'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Widget _buildApplicationToggle(bool isApplied) {
    final colorScheme = Theme.of(context).colorScheme;
    final inactiveBorder = Colors.grey.shade400;
    final activeColor = colorScheme.primary;

    return Semantics(
      button: true,
      toggled: isApplied,
      label: isApplied ? 'Applied' : 'Apply',
      child: OutlinedButton.icon(
        onPressed: () {
          if (isApplied) {
            _withdrawApplication();
          } else {
            _showApplicationDialog();
          }
        },
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          foregroundColor: isApplied ? activeColor : Colors.grey.shade700,
          side: BorderSide(
            color: isApplied ? activeColor : inactiveBorder,
            width: 1.2,
          ),
          backgroundColor: isApplied
              ? activeColor.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        icon: Icon(
          isApplied ? Icons.waving_hand : Icons.waving_hand_outlined,
          size: 16,
        ),
        label: Text(isApplied ? 'Applied' : 'Apply'),
      ),
    );
  }

  String _getDisplayAssignedName() {
    if (widget.task.taskAssignedToName.isEmpty ||
        widget.task.taskAssignedToName == 'Unassigned') {
      return 'Unassigned';
    }

    String displayName = widget.task.taskAssignedToName;

    // Check if assigned to the board manager
    if (widget.board != null &&
        widget.task.taskAssignedTo == widget.board!.boardManagerId) {
      // If current user is the one viewing, show "Me (Manager)"
      if (widget.currentUserId == widget.task.taskAssignedTo) {
        displayName = 'Me (Manager)';
      } else {
        // If another member is viewing, show their name with (Manager)
        displayName = '${widget.task.taskAssignedToName} (Manager)';
      }
    }

    return displayName;
  }

  bool _isSupervisorDraft() {
    if (widget.board == null) return false;
    if (widget.task.taskBoardLane != Task.laneDrafts) return false;
    if (widget.task.taskOwnerId == widget.board!.boardManagerId) return false;
    return widget.board!.isSupervisor(widget.task.taskOwnerId);
  }

  bool _canPokeMember() {
    if (widget.board == null || widget.currentUserId == null) return false;
    if (!widget.board!.canPokeMembers(widget.currentUserId)) return false;
    if (widget.task.taskIsDone) return false;
    if (_isTaskUnassigned()) return false;
    final assigneeId = widget.task.taskAssignedTo;
    if (assigneeId.isEmpty || assigneeId == 'None') return false;
    if (assigneeId == widget.currentUserId) return false;
    return true;
  }

  Future<void> _pokeMember() async {
    if (!_canPokeMember() || _isPoking) return;
    String detailsText = '';
    String? detailsError;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Poke Assignee',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Action Needed: Update progress/status',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Task: ${widget.task.taskTitle}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      maxLines: 4,
                      maxLength: 400,
                      onChanged: (value) {
                        detailsText = value;
                        if (detailsError != null) {
                          setModalState(() => detailsError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Details',
                        hintText:
                            'Write your reminder details for the assignee.',
                        helperText: 'Minimum 15 characters.',
                        errorText: detailsError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final details = detailsText.trim();
                          if (details.length < 15) {
                            setModalState(() {
                              detailsError =
                                  'Details must be at least 15 characters.';
                            });
                            return;
                          }
                          Navigator.of(context).pop(true);
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('Send Poke'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final details = detailsText.trim();
    if (confirmed != true) return;

    setState(() => _isPoking = true);
    try {
      const actionNeeded = 'Update progress/status';
      final reminderMessage = 'Action needed: $actionNeeded\nDetails: $details';

      await NotificationHelper.createNotificationPair(
        userId: widget.task.taskAssignedTo,
        title: 'Task Reminder: ${widget.task.taskTitle}',
        message: reminderMessage,
        category: NotificationHelper.categoryReminder,
        relatedId: widget.task.taskId,
        metadata: {
          'kind': 'reminder',
          'source': 'poke',
          'actionNeeded': actionNeeded,
          'details': details,
          'reminderMessage': reminderMessage,
          'targetType': 'task',
          'targetLabel': widget.task.taskTitle,
          'createdByUserId': _currentUserId,
          'createdByUserName':
              FirebaseAuth.instance.currentUser?.displayName ?? 'Manager',
          'pokeTiming': 'now',
          'taskId': widget.task.taskId,
          'boardId': widget.task.taskBoardId,
          'type': 'task_poke',
        },
      );
      final messenger = mounted ? ScaffoldMessenger.maybeOf(context) : null;
      messenger?.showSnackBar(const SnackBar(content: Text('Poke sent.')));
    } catch (e) {
      final messenger = mounted ? ScaffoldMessenger.maybeOf(context) : null;
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Failed to send poke: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPoking = false);
      }
    }
  }

  Color _getMemberColor() {
    if (widget.task.taskAssignedToName.isEmpty ||
        widget.task.taskAssignedToName == 'Unassigned') {
      return Colors.transparent;
    }
    return Colors.grey.shade700;
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityBackgroundColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade100;
      case 'medium':
        return Colors.orange.shade100;
      case 'low':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getStatusColor(String status) {
    switch (_normalizeStatus(status)) {
      case 'TO_DO':
      case 'TODO':
        return Colors.grey;
      case 'IN_PROGRESS':
      case 'IN_REVIEW':
      case 'UNDER_REVISION':
        return Colors.blue;
      case 'PAUSED':
      case 'ON_PAUSE':
        return Colors.orange;
      case 'SUBMITTED':
        return Colors.purple;
      case 'COMPLETED':
      case 'DONE':
        return Colors.green;
      case 'OVERDUE':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _normalizeStatus(String status) {
    return status.trim().toUpperCase().replaceAll(' ', '_');
  }

  String _getStatusLabel(String status) {
    switch (_normalizeStatus(status)) {
      case 'TO_DO':
      case 'TODO':
        return 'To Do';
      case 'IN_PROGRESS':
      case 'IN_REVIEW':
      case 'UNDER_REVISION':
        return 'In Progress';
      case 'PAUSED':
      case 'ON_PAUSE':
        return 'Paused';
      case 'SUBMITTED':
        return 'Submitted';
      case 'COMPLETED':
      case 'DONE':
        return 'Completed';
      case 'OVERDUE':
        return 'Overdue';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (_normalizeStatus(status)) {
      case 'TO_DO':
      case 'TODO':
        return Icons.circle_outlined;
      case 'IN_PROGRESS':
      case 'IN_REVIEW':
      case 'UNDER_REVISION':
        return Icons.autorenew;
      case 'PAUSED':
      case 'ON_PAUSE':
        return Icons.pause_circle;
      case 'SUBMITTED':
        return Icons.upload_file;
      case 'COMPLETED':
      case 'DONE':
        return Icons.check_circle;
      case 'OVERDUE':
        return Icons.error;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final memberColor = _getMemberColor();
    final isUnassigned =
        widget.task.taskAssignedToName.isEmpty ||
        widget.task.taskAssignedToName == 'Unassigned';
    final priorityColor = _getPriorityColor(widget.task.taskPriorityLevel);
    final canHaveUnassigned = _shouldAllowUnassigned();
    final blockedDependencyTitles = _incompleteDependencyTitles(taskProvider);
    final isDependencyLocked = blockedDependencyTitles.isNotEmpty;
    final isLocked = widget.isDisabled;
    final canShowApplyAction =
        _isTaskUnassigned() &&
        canHaveUnassigned &&
        _canCurrentUserApply() &&
        !widget.showPublishButton;
    final canPoke = _canPokeMember() && !isDependencyLocked;
    final isSupervisorDraft = _isSupervisorDraft();
    final missingRequiredSubmission =
        widget.task.taskRequiresSubmission &&
        (widget.task.taskSubmissionId ?? '').trim().isEmpty;

    // Only allow delete for board manager or task owner
    final canDelete =
        !isLocked &&
        !widget.task.taskIsDone &&
        widget.board != null &&
        widget.currentUserId != null &&
        (widget.board!.boardManagerId == widget.currentUserId ||
            widget.task.taskOwnerId == widget.currentUserId);

    // Only allow edit for board manager/supervisor.
    final canEdit =
        !isLocked &&
        !widget.task.taskIsDone &&
        widget.currentUserId != null &&
        (widget.task.taskOwnerId == widget.currentUserId ||
            (widget.board != null &&
                (widget.board!.isManager(widget.currentUserId) ||
                    widget.board!.isSupervisor(widget.currentUserId))));
    final canDuplicate = canEdit;
    final hasSwipeActions = canEdit || canDuplicate || canDelete;
    final actionCount =
        (canEdit ? 1 : 0) + (canDuplicate ? 1 : 0) + (canDelete ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Opacity(
        opacity: isLocked ? 0.5 : 1,
        child: IgnorePointer(
          ignoring: isLocked,
          child: Slidable(
            key: ValueKey(widget.task.taskId),
            endActionPane: hasSwipeActions
                ? ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: actionCount * 0.22,
                    children: [
                      if (canEdit)
                        Expanded(
                          child: Container(
                            alignment: Alignment.center,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.amber.shade500,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    Slidable.of(context)?.close();
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (context) => EditTaskDialog(
                                        task: widget.task,
                                        asSheet: true,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Edit',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (canDuplicate)
                        Expanded(
                          child: Container(
                            alignment: Alignment.center,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade500,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _handleDuplicate,
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.copy,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Duplicate',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (canDelete)
                        Expanded(
                          child: Container(
                            alignment: Alignment.center,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _handleDelete,
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Delete',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  )
                : null,
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: () {
                  Slidable.of(context)?.close();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => TaskDetailsPage(task: widget.task),
                    ),
                  );
                },
                child: Card(
                  elevation: 2,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                    side: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          12,
                          hasSwipeActions ? 30 : 12,
                          12,
                        ),
                        child: Column(
                          children: [
                            // Top row: Assigned to + Priority (left) and Status (right)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Assigned to + Priority badge
                                Row(
                                  children: [
                                    if (!isUnassigned)
                                      Icon(
                                        Icons.person_outline,
                                        size: 12,
                                        color: memberColor,
                                      ),
                                    if (!isUnassigned) const SizedBox(width: 4),
                                    Text(
                                      _getDisplayAssignedName(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isUnassigned
                                            ? Colors.grey[400]
                                            : memberColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(width: 8),
                                    // Priority badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getPriorityBackgroundColor(
                                          widget.task.taskPriorityLevel,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        widget.task.taskPriorityLevel,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: priorityColor,
                                        ),
                                      ),
                                    ),
                                    if (isSupervisorDraft)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.deepPurple.shade50,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.deepPurple.shade200,
                                            ),
                                          ),
                                          child: Text(
                                            'Supervisor Draft',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.deepPurple.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (widget
                                        .task
                                        .taskDependencyIds
                                        .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blueGrey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.link,
                                                size: 10,
                                                color: Colors.blueGrey.shade800,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                '${widget.task.taskDependencyIds.length}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      Colors.blueGrey.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                // Status badge on the right
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _getStatusColor(
                                        widget.task.taskStatus,
                                      ),
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getStatusIcon(widget.task.taskStatus),
                                        size: 12,
                                        color: _getStatusColor(
                                          widget.task.taskStatus,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getStatusLabel(widget.task.taskStatus),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: _getStatusColor(
                                            widget.task.taskStatus,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (widget.showCheckbox) ...[
                                  Tooltip(
                                    message: missingRequiredSubmission
                                        ? 'Upload is required before completing this task.'
                                        : '',
                                    child: Checkbox(
                                      value: widget.task.taskIsDone,
                                      onChanged:
                                          isLocked ||
                                              (missingRequiredSubmission &&
                                                  !widget.task.taskIsDone)
                                          ? null
                                          : (value) => widget.onToggleDone
                                                ?.call(value),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                // Main content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (isDependencyLocked)
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.lock_outline,
                                              size: 14,
                                              color: Colors.red.shade700,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _buildDependencyLockMessage(
                                                  blockedDependencyTitles,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.red.shade700,
                                                  height: 1.2,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        Text(
                                          widget.task.taskTitle,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 12,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            widget.task.taskDeadline != null
                                                ? '${_formatDate(widget.task.taskDeadline!)} • ${_formatTime(widget.task.taskDeadline!)}'
                                                : 'No deadline',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          if (_getDeadlineTag(
                                                widget.task.taskDeadline,
                                              ) !=
                                              null) ...[
                                            const SizedBox(width: 8),
                                            Builder(
                                              builder: (context) {
                                                final tag = _getDeadlineTag(
                                                  widget.task.taskDeadline,
                                                )!;
                                                final color =
                                                    _getDeadlineTagColor(tag);
                                                return Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: color.withValues(
                                                      alpha: 0.12,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: color,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    tag,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: color,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Show application button only if task is unassigned AND unassigned is allowed
                                if (canPoke) ...[
                                  Tooltip(
                                    message: 'Poke assignee',
                                    child: OutlinedButton(
                                      onPressed: _isPoking ? null : _pokeMember,
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        foregroundColor: Colors.orange.shade800,
                                        minimumSize: const Size(40, 40),
                                        padding: EdgeInsets.zero,
                                        shape: const CircleBorder(),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        side: BorderSide(
                                          color: Colors.orange.shade300,
                                        ),
                                      ),
                                      child: Icon(
                                        _isPoking
                                            ? Icons.hourglass_top
                                            : Icons.ads_click,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (canShowApplyAction)
                                  StreamBuilder<bool>(
                                    stream: _isUserAppliedStream(),
                                    builder: (context, snapshot) {
                                      final isApplied = snapshot.data ?? false;

                                      return Tooltip(
                                        message: isApplied
                                            ? 'Withdraw application'
                                            : 'Apply',
                                        child: _buildApplicationToggle(
                                          isApplied,
                                        ),
                                      );
                                    },
                                  )
                                else if (widget.showPublishButton)
                                  Tooltip(
                                    message: 'Move to Published',
                                    child: OutlinedButton(
                                      onPressed: widget.isPublishing
                                          ? null
                                          : widget.onPublish,
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Icon(
                                        widget.isPublishing
                                            ? Icons.hourglass_top
                                            : Icons.publish_outlined,
                                        size: 16,
                                      ),
                                    ),
                                  )
                                else if (_hasSteps())
                                  const SizedBox(width: 8),
                                // Circular progress indicator
                                if (_hasSteps())
                                  SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: _getProgress(),
                                          strokeWidth: 2.5,
                                          backgroundColor: const Color(
                                            0xFFCFD8DC,
                                          ),
                                          color: widget.task.taskIsDone
                                              ? const Color(0xFF66BB6A)
                                              : const Color(0xFF5B9BD5),
                                        ),
                                        Text(
                                          _getProgressPercent(),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (hasSwipeActions)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          child: Tooltip(
                            message: 'Swipe left for actions',
                            child: SizedBox(
                              width: 24,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Positioned(
                                    right: 5,
                                    child: Icon(
                                      Icons.keyboard_double_arrow_left,
                                      size: 16,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _getProgress() {
    final done = widget.task.taskStats.taskStepsDoneCount ?? 0;
    final total = widget.task.taskStats.taskStepsCount ?? 0;
    return total > 0 ? done / total : 0.0;
  }

  bool _hasSteps() {
    return (widget.task.taskStats.taskStepsCount ?? 0) > 0;
  }

  String _getProgressPercent() {
    final total = widget.task.taskStats.taskStepsCount ?? 0;
    if (total == 0) return "0%";
    final percent = ((_getProgress()) * 100).round();
    return "$percent%";
  }

  String _formatDate(DateTime date) {
    return "${date.month}/${date.day}";
  }

  String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }

  String? _getDeadlineTag(DateTime? deadline) {
    if (deadline == null) return null;
    final now = DateTime.now();
    final isSameDay =
        deadline.year == now.year &&
        deadline.month == now.month &&
        deadline.day == now.day;

    if (deadline.isBefore(now)) return 'Missed';
    if (isSameDay) return 'Today';
    return 'Upcoming';
  }

  Color _getDeadlineTagColor(String tag) {
    switch (tag) {
      case 'Missed':
        return Colors.red;
      case 'Today':
        return Colors.orange;
      case 'Upcoming':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handleDuplicate() async {
    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      final duplicatedTask = await taskProvider.duplicateTask(widget.task);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task duplicated: ${duplicatedTask.taskTitle}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error duplicating task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleDelete() async {
    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // Delete the task and pass the task object for activity tracking
      await taskProvider.deleteTask(
        widget.task.taskId,
        ownerId: userProvider.userId,
        task: widget.task,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task deleted'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

