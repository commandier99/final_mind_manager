import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../datasources/models/task_model.dart';
import '../../../datasources/providers/task_provider.dart';
import '../../../datasources/services/task_application_service.dart';
import '../../pages/task_details_page.dart';
import '../dialogs/edit_task_dialog.dart';
import '../../../../boards/datasources/providers/board_provider.dart';
import '../../../../../shared/datasources/providers/navigation_provider.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final ValueChanged<bool?>? onToggleDone;
  final bool showFocusAction;
  final VoidCallback? onFocus;
  final VoidCallback? onPause;
  final bool showBoardLabel;
  final bool showFocusInMainRow;
  final bool showCheckboxWhenFocusedOnly;
  final bool useStatusColor;
  final bool isPomodoroMode;
  final bool isDimmed;
  final bool showFrogBadge;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onDelete,
    this.onToggleDone,
    this.showFocusAction = false,
    this.onFocus,
    this.onPause,
    this.showBoardLabel = true,
    this.showFocusInMainRow = false,
    this.showCheckboxWhenFocusedOnly = false,
    this.useStatusColor = true,
    this.isPomodoroMode = false,
    this.isDimmed = false,
    this.showFrogBadge = false,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  late String _currentUserId;
  final TaskApplicationService _taskApplicationService =
      TaskApplicationService();

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  bool _hasSteps() {
    return (widget.task.taskStats.taskStepsCount ?? 0) > 0;
  }

  bool _isTaskUnassigned() {
    // Task is unassigned if assigned to empty string
    return widget.task.taskAssignedTo.isEmpty;
  }

  bool _shouldAllowUnassigned() {
    // Only allow unassigned status if there are multiple board members
    // If board has only 1 member (the manager), tasks must be assigned
    if (widget.task.taskBoardId.isEmpty) return true;

    final boardProvider = context.read<BoardProvider>();
    final board = boardProvider.getBoardById(widget.task.taskBoardId);

    return board == null || (board.memberIds.length > 1);
  }

  bool _canCurrentUserApply() {
    if (widget.task.taskBoardId.isEmpty) return true;
    final boardProvider = context.read<BoardProvider>();
    final board = boardProvider.getBoardById(widget.task.taskBoardId);
    if (board == null) return true;
    return _currentUserId != board.boardManagerId;
  }

  void _showApplicationDialog() {
    final applicationController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _submitApplication(applicationController.text);
              applicationController.dispose();
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

  String _normalizeStatus(String status) {
    return status.toUpperCase().replaceAll(' ', '_');
  }

  bool _isInProgressStatus(String status) {
    return _normalizeStatus(status) == 'IN_PROGRESS';
  }

  Color _getStatusColor(String status) {
    switch (_normalizeStatus(status)) {
      case 'OVERDUE':
        return Colors.red;
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
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getDeadlineColor() {
    if (widget.task.taskDeadlineMissed) {
      return Colors.red;
    }
    if (widget.task.taskDeadline == null) {
      return Colors.grey;
    }
    final daysUntil = widget.task.taskDeadline!
        .difference(DateTime.now())
        .inDays;
    if (daysUntil < 0) {
      return Colors.red; // Missed
    } else if (daysUntil <= 3) {
      return Colors.orange; // Upcoming soon
    } else {
      return Colors.green; // Far away
    }
  }

  String _formatDeadline(DateTime? deadline) {
    if (deadline == null) return '';
    final now = DateTime.now();
    final daysUntil = deadline
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    if (daysUntil < 0) {
      return '${-daysUntil} day${-daysUntil > 1 ? 's' : ''} overdue';
    } else if (daysUntil == 0) {
      return 'Due today';
    } else if (daysUntil == 1) {
      return 'Due tomorrow';
    } else {
      return 'Due in $daysUntil days';
    }
  }

  IconData _getStatusIcon(String status) {
    switch (_normalizeStatus(status)) {
      case 'OVERDUE':
        return Icons.error;
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
        return Icons.check_circle;
      default:
        return Icons.circle_outlined;
    }
  }

  String _getAcceptanceStatusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'declined':
        return 'Declined';
      default:
        return '';
    }
  }

  Color _getAcceptanceStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.green;
      case 'declined':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handleDuplicate() async {
    try {
      final taskProvider = context.read<TaskProvider>();
      final duplicatedTask = await taskProvider.duplicateTask(widget.task);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task duplicated: ${duplicatedTask.taskTitle}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to duplicate task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.task.taskStats.taskStepsDoneCount ?? 0;
    final total = widget.task.taskStats.taskStepsCount ?? 0;
    final progress = widget.task.taskIsDone
        ? 1.0
        : (total > 0 ? done / total : 0.0);
    final percent = widget.task.taskIsDone
        ? 100
        : (total > 0 ? (progress * 100).round() : 0);
    final isFocused = _isInProgressStatus(widget.task.taskStatus);
    final isCompleted =
        widget.task.taskIsDone ||
        _normalizeStatus(widget.task.taskStatus) == 'COMPLETED';
    final showFocusAction = widget.showFocusAction && !isCompleted;
    final missingRequiredSubmission =
        widget.task.taskRequiresSubmission &&
        (widget.task.taskSubmissionId ?? '').trim().isEmpty;

    final showCheckbox =
        !widget.showCheckboxWhenFocusedOnly || (isFocused && !isCompleted);
    final statusColor = widget.useStatusColor
        ? _getStatusColor(widget.task.taskStatus)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    final cardBaseColor = Theme.of(context).cardColor;
    final borderColor = isFocused ? statusColor : Colors.grey.shade300;

    // Board tasks: manager/supervisor can edit. Personal tasks: owner can edit.
    bool canEditTask = widget.task.taskOwnerId == _currentUserId;
    if (widget.task.taskBoardId.isNotEmpty) {
      canEditTask = false;
      final boardProvider = context.read<BoardProvider>();
      final board = boardProvider.getBoardById(widget.task.taskBoardId);
      if (board?.isManager(_currentUserId) == true ||
          board?.isSupervisor(_currentUserId) == true) {
        canEditTask = true;
      }
    }
    if (widget.task.taskIsDone) {
      canEditTask = false;
    }
    final canDuplicateTask = canEditTask;
    final hasDeleteAction = widget.onDelete != null && !widget.task.taskIsDone;
    final hasSwipeActions = canEditTask || canDuplicateTask || hasDeleteAction;
    final actionCount =
        (canEditTask ? 1 : 0) +
        (canDuplicateTask ? 1 : 0) +
        (hasDeleteAction ? 1 : 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Opacity(
        opacity: widget.isDimmed ? 0.56 : 1,
        child: Slidable(
          key: ValueKey(widget.task.taskId),
          endActionPane: hasSwipeActions
              ? ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: actionCount * 0.25,
                  children: [
                    if (canEditTask)
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
                                  showDialog(
                                    context: context,
                                    builder: (context) =>
                                        EditTaskDialog(task: widget.task),
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
                    if (canDuplicateTask)
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
                    if (hasDeleteAction)
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
                                onTap: widget.onDelete,
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
          child: GestureDetector(
            onTap: () {
              context.read<NavigationProvider>().selectFromBottomNav(1);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TaskDetailsPage(task: widget.task),
                ),
              );
            },
            child: Card(
              elevation: isFocused ? 3 : 2,
              color: cardBaseColor,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide(color: borderColor, width: 1),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      10,
                      hasSwipeActions ? 30 : 12,
                      10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header: Board/Priority (left) + Status (right)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.showBoardLabel) ...[
                                  Icon(
                                    Icons.label,
                                    size: 12,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.task.taskBoardTitle ?? 'Personal',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (widget.showFrogBadge) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.green.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.pets,
                                          size: 10,
                                          color: Colors.green.shade700,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          'Frog',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.green.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getPriorityBackgroundColor(
                                      widget.task.taskPriorityLevel,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.task.taskPriorityLevel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _getPriorityColor(
                                        widget.task.taskPriorityLevel,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: statusColor,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getStatusIcon(widget.task.taskStatus),
                                    size: 11,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    widget.task.taskStatus,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Main content row
                        Row(
                          children: [
                            if (showCheckbox) ...[
                              Tooltip(
                                message: missingRequiredSubmission
                                    ? 'Upload is required before completing this task.'
                                    : '',
                                child: Checkbox(
                                  value: widget.task.taskIsDone,
                                  onChanged:
                                      missingRequiredSubmission &&
                                          !widget.task.taskIsDone
                                      ? null
                                      : (bool? newValue) =>
                                            widget.onToggleDone?.call(newValue),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        widget.task.taskDeadline == null
                                            ? Icons.calendar_today
                                            : (widget.task.taskDeadlineMissed
                                                  ? Icons.error
                                                  : Icons.calendar_today),
                                        size: 12,
                                        color: widget.task.taskDeadline == null
                                            ? Colors.grey
                                            : _getDeadlineColor(),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.task.taskDeadline == null
                                            ? 'No deadline'
                                            : _formatDeadline(
                                                widget.task.taskDeadline,
                                              ),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              widget.task.taskDeadline == null
                                              ? Colors.grey
                                              : _getDeadlineColor(),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  // Compact badges row
                                  if (widget.task.taskRequiresApproval ||
                                      widget.task.taskAssignmentStatus !=
                                          null ||
                                      widget.task.taskDependencyIds.isNotEmpty)
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (widget
                                              .task
                                              .taskDependencyIds
                                              .isNotEmpty)
                                            Tooltip(
                                              message:
                                                  '${widget.task.taskDependencyIds.length} prerequisite(s)',
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blueGrey[100],
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.link,
                                                      size: 10,
                                                      color:
                                                          Colors.blueGrey[800],
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      '${widget.task.taskDependencyIds.length}',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors
                                                            .blueGrey[800],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          if (widget.task.taskRequiresApproval)
                                            Tooltip(
                                              message: 'Requires approval',
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.purple[100],
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Icon(
                                                  Icons.verified_user,
                                                  size: 10,
                                                  color: Colors.purple[700],
                                                ),
                                              ),
                                            ),
                                          if (widget
                                                  .task
                                                  .taskAssignmentStatus !=
                                              null)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 4,
                                              ),
                                              child: Tooltip(
                                                message:
                                                    _getAcceptanceStatusLabel(
                                                      widget
                                                          .task
                                                          .taskAssignmentStatus,
                                                    ),
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                        vertical: 1,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _getAcceptanceStatusColor(
                                                      widget
                                                          .task
                                                          .taskAssignmentStatus,
                                                    ).withValues(alpha: 0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.check_circle,
                                                    size: 10,
                                                    color: _getAcceptanceStatusColor(
                                                      widget
                                                          .task
                                                          .taskAssignmentStatus,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Right side indicators
                            if (showFocusAction && widget.showFocusInMainRow)
                              // In Pomodoro: switching focus is allowed, manual pause is not.
                              if (widget.isPomodoroMode)
                                IconButton(
                                  onPressed: widget.onFocus,
                                  tooltip: 'Focus task',
                                  icon: const Icon(Icons.adjust, size: 28),
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                )
                              else if (!widget.isPomodoroMode)
                                IconButton(
                                  onPressed: isFocused
                                      ? widget.onPause
                                      : widget.onFocus,
                                  icon: Icon(
                                    isFocused ? Icons.pause : Icons.adjust,
                                    size: 28,
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                )
                              else if (!showFocusAction &&
                                  _isTaskUnassigned() &&
                                  _shouldAllowUnassigned() &&
                                  _canCurrentUserApply())
                                StreamBuilder<bool>(
                                  stream: _isUserAppliedStream(),
                                  builder: (context, snapshot) {
                                    final isApplied = snapshot.data ?? false;

                                    return GestureDetector(
                                      onTap: () {
                                        if (isApplied) {
                                          _withdrawApplication();
                                        } else {
                                          _showApplicationDialog();
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isApplied
                                              ? Colors.green[100]
                                              : Colors.grey[100],
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: isApplied
                                                ? Colors.green
                                                : Colors.grey[300]!,
                                          ),
                                        ),
                                        child: Icon(
                                          isApplied
                                              ? Icons.how_to_reg
                                              : Icons.app_registration,
                                          size: 16,
                                          color: isApplied
                                              ? Colors.green
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    );
                                  },
                                )
                              else if (_hasSteps())
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: progress,
                                        strokeWidth: 2.5,
                                        backgroundColor: Colors.grey.shade300,
                                        color: statusColor,
                                      ),
                                      Text(
                                        "$percent%",
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          ],
                        ),
                        // Focus action if needed
                        if (showFocusAction && !widget.showFocusInMainRow)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: OutlinedButton.icon(
                              onPressed: widget.isPomodoroMode
                                  ? widget.onFocus
                                  : (isFocused
                                        ? widget.onPause
                                        : widget.onFocus),
                              icon: Icon(
                                widget.isPomodoroMode
                                    ? Icons.adjust
                                    : (isFocused ? Icons.pause : Icons.adjust),
                                size: 14,
                              ),
                              label: Text(
                                widget.isPomodoroMode
                                    ? 'Focus'
                                    : (isFocused ? 'Pause' : 'Focus'),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
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
    );
  }
}

