import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/presentation/pages/task_details_page.dart';
import '../../../../tasks/presentation/widgets/dialogs/edit_task_dialog.dart';
import '../../../../thoughts/datasources/models/thought_model.dart';
import '../../../../thoughts/presentation/widgets/dialogs/create_thought_dialog.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../../../shared/datasources/providers/navigation_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  bool _isTaskUnassigned() {
    return widget.task.taskAssignedTo.isEmpty ||
        widget.task.taskAssignedTo == 'None';
  }

  bool _hasPendingAssignment() {
    return widget.task.taskAssignmentStatus == 'pending' &&
        (widget.task.taskProposedAssigneeId ?? '').trim().isNotEmpty;
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

  String _getDisplayAssignedName() {
    if (widget.task.taskAssignmentStatus == 'pending' &&
        (widget.task.taskProposedAssigneeName ?? '').trim().isNotEmpty) {
      return '${widget.task.taskProposedAssigneeName!.trim()} (Pending)';
    }

    if (widget.task.taskAssignedToName.isEmpty ||
        widget.task.taskAssignedToName == 'Unassigned' ||
        widget.task.taskAssignedToName == 'None (Pending)') {
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

  bool _canApplyForTask() {
    final board = widget.board;
    if (board == null) return false;
    if (widget.showPublishButton) return false;
    if (widget.task.taskIsDone || widget.task.taskIsDeleted) return false;
    if (widget.task.taskBoardLane != Task.lanePublished) return false;
    if (!_isTaskUnassigned() || _hasPendingAssignment()) return false;
    return board.roleOf(_currentUserId) == 'member';
  }

  bool _isConnectedRequiredTaskForCurrentUser(TaskProvider taskProvider) {
    return taskProvider.tasks.any(
      (task) =>
          !task.taskIsDeleted &&
          !task.taskIsDone &&
          task.taskAssignedTo == _currentUserId &&
          task.taskDependencyIds.contains(widget.task.taskId),
    );
  }

  bool _canSendReminder(TaskProvider taskProvider) {
    final board = widget.board;
    if (board == null) return false;
    if (widget.showPublishButton) return false;
    if (widget.task.taskIsDone || widget.task.taskIsDeleted) return false;
    if (_isTaskUnassigned() || _hasPendingAssignment()) return false;
    return board.canPokeMembers(_currentUserId) ||
        _isConnectedRequiredTaskForCurrentUser(taskProvider);
  }

  bool _isDeadlineMissed() {
    if (widget.task.taskIsDone || widget.task.taskIsDeleted) return false;
    if (widget.task.taskDeadlineMissed) return true;
    final deadline = widget.task.taskDeadline;
    if (deadline == null) return false;
    return deadline.isBefore(DateTime.now());
  }

  bool _canRequestDeadlineExtension() {
    final board = widget.board;
    if (board == null) return false;
    if (widget.showPublishButton) return false;
    if (widget.task.taskIsDone || widget.task.taskIsDeleted) return false;
    if (widget.task.taskBoardLane != Task.lanePublished) return false;
    if (_isTaskUnassigned() || _hasPendingAssignment()) return false;
    return widget.task.taskAssignedTo == _currentUserId;
  }

  Future<void> _openApplyForTask() async {
    await CreateThoughtDialog.show(
      context,
      initialType: Thought.typeTaskAssignment,
      initialBoardId: widget.task.taskBoardId,
      initialTaskId: widget.task.taskId,
      initialTaskAssignmentMode: 'member_to_manager',
      lockType: true,
    );
  }

  Future<void> _openReminder() async {
    await CreateThoughtDialog.show(
      context,
      initialType: Thought.typeReminder,
      initialBoardId: widget.task.taskBoardId,
      initialTaskId: widget.task.taskId,
      lockType: true,
    );
  }

  Future<void> _openDeadlineExtensionRequest() async {
    await CreateThoughtDialog.show(
      context,
      initialType: Thought.typeTaskRequest,
      initialBoardId: widget.task.taskBoardId,
      initialTaskId: widget.task.taskId,
      lockType: true,
    );
  }

  bool _isSupervisorDraft() {
    if (widget.board == null) return false;
    if (widget.task.taskBoardLane != Task.laneDrafts) return false;
    if (widget.task.taskOwnerId == widget.board!.boardManagerId) return false;
    return widget.board!.isSupervisor(widget.task.taskOwnerId);
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
        widget.task.taskAssignedToName == 'Unassigned' ||
        widget.task.taskAssignedToName == 'None (Pending)';
    final priorityColor = _getPriorityColor(widget.task.taskPriorityLevel);
    final blockedDependencyTitles = _incompleteDependencyTitles(taskProvider);
    final isDependencyLocked = blockedDependencyTitles.isNotEmpty;
    final isDeadlineMissed = _isDeadlineMissed();
    final isTaskFailed = widget.task.taskFailed || widget.task.isRejected;
    final isLocked =
        widget.isDisabled || (widget.task.isWorkDisabled && !isDeadlineMissed);
    final taskDisabledReason = widget.task.workDisabledReason;
    final isSupervisorDraft = _isSupervisorDraft();
    final canApplyForTask = _canApplyForTask() && !isDeadlineMissed && !isTaskFailed;
    final canSendReminder = _canSendReminder(taskProvider) && !isDeadlineMissed && !isTaskFailed;
    final canRequestDeadlineExtension = _canRequestDeadlineExtension();
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
                  context.read<NavigationProvider>().selectFromBottomNav(1);
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
                                    message: taskDisabledReason ?? '',
                                    child: Checkbox(
                                      value: widget.task.taskIsDone,
                                      onChanged: isLocked || widget.task.isWorkDisabled
                                          ? null
                                          : (value) =>
                                                widget.onToggleDone?.call(value),
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
                                if (canApplyForTask ||
                                    canSendReminder ||
                                    canRequestDeadlineExtension)
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (canApplyForTask)
                                        Tooltip(
                                          message: 'Apply for Task',
                                          child: OutlinedButton(
                                            onPressed: _openApplyForTask,
                                            style: OutlinedButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              minimumSize: const Size(42, 36),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                            ),
                                            child: const Icon(
                                              Icons.assignment_ind_outlined,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      if (canApplyForTask && canSendReminder)
                                        const SizedBox(height: 6),
                                      if (canSendReminder)
                                        Tooltip(
                                          message: 'Send Reminder',
                                          child: OutlinedButton(
                                            onPressed: _openReminder,
                                            style: OutlinedButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              minimumSize: const Size(42, 36),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                            ),
                                            child: const Icon(
                                              Icons.notifications_active_outlined,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      if ((canApplyForTask || canSendReminder) &&
                                          canRequestDeadlineExtension)
                                        const SizedBox(height: 6),
                                      if (canRequestDeadlineExtension)
                                        Tooltip(
                                          message: isDeadlineMissed
                                              ? 'Request Deadline Extension'
                                              : 'Request Deadline Extension Early',
                                          child: OutlinedButton(
                                            onPressed:
                                                _openDeadlineExtensionRequest,
                                            style: OutlinedButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              minimumSize: const Size(42, 36),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                            ),
                                            child: const Icon(
                                              Icons.schedule_send_outlined,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                    ],
                                  )
                                else
                                  const SizedBox.shrink(),
                                if (widget.showPublishButton)
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

