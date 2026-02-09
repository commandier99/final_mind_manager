import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../datasources/models/task_model.dart';
import '../../../datasources/providers/task_provider.dart';
import '../../pages/task_details_page.dart';
import '../../pages/task_applications_page.dart';
import '../../../../boards/datasources/providers/board_provider.dart';

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
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  late bool _isInterested;
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    // Track if current user has already expressed interest in helpers list
    _isInterested = widget.task.taskHelpers.contains(_currentUserId);
  }

  bool _hasSubtasks() {
    return (widget.task.taskStats.taskSubtasksCount ?? 0) > 0;
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

  Future<void> _toggleInterest(bool interested) async {
    if (interested && !_isInterested) {
      // Show appeal dialog when expressing interest
      _showAppealDialog();
    } else if (!interested && _isInterested) {
      // Remove interest without dialog
      await _removeInterest();
    }
  }

  void _showAppealDialog() {
    final appealController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Express Your Interest'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Why should you be assigned to this task?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: appealController,
                maxLines: 5,
                minLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share your interest and relevant skills...',
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
              _submitInterest(appealController.text);
              appealController.dispose();
            },
            icon: const Icon(Icons.thumb_up),
            label: const Text('Submit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitInterest(String appealText) async {
    final taskProvider = context.read<TaskProvider>();
    
    try {
      final updatedHelpers = [...widget.task.taskHelpers, _currentUserId];
      
      // Update task with new helper
      final updatedTask = widget.task.copyWith(
        taskHelpers: updatedHelpers,
      );
      await taskProvider.updateTask(updatedTask);
      
      // Save appeal to subcollection
      final appealsRef = FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.taskId)
          .collection('appeals');
      
      await appealsRef.add({
        'userId': _currentUserId,
        'userName': widget.task.taskOwnerName,
        'userProfilePicture': '',
        'appealText': appealText,
        'createdAt': Timestamp.now(),
      });
      
      setState(() => _isInterested = true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Interest submitted!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error submitting interest: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit interest: $e')),
        );
      }
    }
  }

  Future<void> _removeInterest() async {
    final taskProvider = context.read<TaskProvider>();
    
    try {
      final updatedHelpers = widget.task.taskHelpers
          .where((id) => id != _currentUserId)
          .toList();
      final updatedTask = widget.task.copyWith(
        taskHelpers: updatedHelpers,
      );
      await taskProvider.updateTask(updatedTask);
      setState(() => _isInterested = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interest removed'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('Error removing interest: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove interest: $e')),
        );
      }
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
      case 'COMPLETED':
        return Colors.green;
      default:
        return Colors.grey;
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

  @override
  Widget build(BuildContext context) {
    final done = widget.task.taskStats.taskSubtasksDoneCount ?? 0;
    final total = widget.task.taskStats.taskSubtasksCount ?? 0;
    final progress =
        widget.task.taskIsDone ? 1.0 : (total > 0 ? done / total : 0.0);
    final percent =
        widget.task.taskIsDone
            ? 100
            : (total > 0 ? (progress * 100).round() : 0);
    final isFocused = _isInProgressStatus(widget.task.taskStatus);
    final isCompleted = widget.task.taskIsDone ||
      _normalizeStatus(widget.task.taskStatus) == 'COMPLETED';
    final showFocusAction = widget.showFocusAction && !isCompleted;
    final showFocusInMainRow = showFocusAction && widget.showFocusInMainRow;
    final showFocusInHeader = showFocusAction && !widget.showFocusInMainRow;
    final showCheckbox =
      !widget.showCheckboxWhenFocusedOnly || (isFocused && !isCompleted);
    final statusColor = widget.useStatusColor
      ? _getStatusColor(widget.task.taskStatus)
      : Theme.of(context).colorScheme.onSurfaceVariant;

    final cardBaseColor = Theme.of(context).cardColor;
    final borderColor = isFocused ? statusColor : Colors.grey.shade300;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Slidable(
        key: ValueKey(widget.task.taskId),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.25,
          children: [
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
                          Icon(Icons.delete, color: Colors.white, size: 20),
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
        ),
            child: GestureDetector(
              onTap: () {
                // If task is unassigned, go to applications page first
                // But only if user is the board manager
                if (widget.task.taskAssignedTo.isEmpty) {
                  final boardProvider = context.read<BoardProvider>();
                  final board = boardProvider.getBoardById(widget.task.taskBoardId);
                  
                  if (board?.boardManagerId == _currentUserId) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TaskApplicationsPage(task: widget.task),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TaskDetailsPage(task: widget.task),
                      ),
                    );
                  }
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TaskDetailsPage(task: widget.task),
                    ),
                  );
                }
              },
              child: Card(
                elevation: isFocused ? 3 : 2,
                color: cardBaseColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                  side: BorderSide(
                    color: borderColor,
                    width: 1,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.zero,
                    color: Colors.transparent,
                  ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.showBoardLabel) ...[
                                    Icon(
                                      Icons.label,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.task.taskBoardTitle ?? 'Personal',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  // Priority badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
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
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _getPriorityColor(
                                          widget.task.taskPriorityLevel,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              // Right side - status + focus action
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
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
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getStatusIcon(widget.task.taskStatus),
                                          size: 12,
                                          color: statusColor,
                                        ),
                                        const SizedBox(width: 4),
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
                                  if (showFocusInHeader) ...[
                                    const SizedBox(width: 6),
                                    OutlinedButton.icon(
                                      onPressed: isFocused
                                          ? widget.onPause
                                          : widget.onFocus,
                                      icon: Icon(
                                        isFocused ? Icons.pause : Icons.play_arrow,
                                        size: 14,
                                      ),
                                      label: Text(
                                        isFocused ? 'Pause' : 'Focus',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        minimumSize: const Size(0, 0),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                              const SizedBox(height: 6),
                          // Additional badges row (approval, acceptance, helpers)
                          if (widget.task.taskRequiresApproval ||
                              widget.task.taskAcceptanceStatus != null ||
                              widget.task.taskHelpers.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4,
                                  ),
                              child: Row(
                                children: [
                                  // Approval indicator
                                  if (widget.task.taskRequiresApproval)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Tooltip(
                                        message: 'Requires approval',
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.check_circle_outline,
                                            size: 12,
                                            color: Colors.amber.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 6),
                                  // Acceptance status
                                  if (widget.task.taskAcceptanceStatus !=
                                      null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Tooltip(
                                        message: _getAcceptanceStatusLabel(
                                          widget.task.taskAcceptanceStatus,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                _getAcceptanceStatusColor(
                                                  widget
                                                      .task
                                                      .taskAcceptanceStatus,
                                                ).withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _getAcceptanceStatusLabel(
                                              widget.task
                                                  .taskAcceptanceStatus,
                                            ),
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  _getAcceptanceStatusColor(
                                                    widget
                                                        .task
                                                        .taskAcceptanceStatus,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 6),
                                  // Helpers count
                                  if (widget.task.taskHelpers.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Tooltip(
                                        message:
                                            '${widget.task.taskHelpers.length} helper${widget.task.taskHelpers.length > 1 ? 's' : ''}',
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.shade100,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.people,
                                                size: 11,
                                                color: Colors.teal.shade700,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                widget.task.taskHelpers.length
                                                    .toString(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.teal.shade700,
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
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          if (showCheckbox) ...[
                            Checkbox(
                              value: widget.task.taskIsDone,
                              onChanged: (bool? newValue) {
                                widget.onToggleDone?.call(newValue);
                              },
                            ),
                            const SizedBox(width: 12),
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
                                    fontSize: 15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Flexible(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.task.taskDeadline != null
                                              ? _formatDate(
                                                widget.task.taskDeadline!,
                                              )
                                              : 'No deadline',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (widget.task.taskIsRepeating) ...[
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.repeat,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatRepeatDays(
                                              widget.task.taskRepeatInterval,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (showFocusInMainRow) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed:
                                  isFocused ? widget.onPause : widget.onFocus,
                              icon: Icon(
                                isFocused ? Icons.pause : Icons.adjust,
                                size: 34,
                              ),
                              padding: const EdgeInsets.all(10),
                              constraints: const BoxConstraints(
                                minWidth: 56,
                                minHeight: 56,
                              ),
                              splashRadius: 28,
                            ),
                          ],
                          const SizedBox(width: 8),
                          // Show interest buttons only if task is unassigned AND unassigned is allowed
                          if (_isTaskUnassigned() && _shouldAllowUnassigned())
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: _isInterested ? 'Not interested' : 'Interested',
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_isInterested) {
                                        _removeInterest();
                                      } else {
                                        _toggleInterest(true);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _isInterested
                                            ? Colors.green.shade100
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: _isInterested
                                              ? Colors.green
                                              : Colors.grey.shade400,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isInterested
                                                ? Icons.thumb_up
                                                : Icons.thumb_up_outlined,
                                            size: 16,
                                            color: _isInterested
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _isInterested ? 'Interested' : 'Interest?',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: _isInterested
                                                  ? Colors.green.shade700
                                                  : Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else if (_hasSubtasks())
                            const SizedBox(width: 8),
                          if (_hasSubtasks())
                            SizedBox(
                              width: 45,
                              height: 45,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 3,
                                    backgroundColor: Colors.grey.shade300,
                                    color:
                                        widget.task.taskIsDone
                                            ? Colors.green
                                            : Colors.blue,
                                  ),
                                  Text(
                                    widget.task.taskIsDone ? "100%" : "$percent%",
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(width: 8),
                          // const SizedBox(width: 8),
                          // // Focus button - Commented out, focus session feature not used
                          // Tooltip(
                          //   message: _isFocused ? 'Unfocus' : 'Set as current task',
                          //   child: GestureDetector(
                          //     onTap: () {
                          //       setState(() {
                          //         _isFocused = !_isFocused;
                          //       });
                          //     },
                          //     child: Container(
                          //       padding: const EdgeInsets.all(8),
                          //       decoration: BoxDecoration(
                          //         color: _isFocused ? Colors.blue : Colors.blue.shade50,
                          //         borderRadius: BorderRadius.circular(8),
                          //         border: Border.all(
                          //           color: Colors.blue,
                          //           width: 1.5,
                          //         ),
                          //       ),
                          //       child: Icon(
                          //         Icons.adjust,
                          //         size: 20,
                          //         color: _isFocused ? Colors.white : Colors.blue,
                          //       ),
                          //     ),
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  String _formatRepeatDays(String? repeatInterval) {
    if (repeatInterval == null || repeatInterval.isEmpty) {
      return '';
    }

    final days = repeatInterval.split(',');
    const allDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const dayAbbreviations = {
      'Monday': 'Mo',
      'Tuesday': 'Tu',
      'Wednesday': 'We',
      'Thursday': 'Th',
      'Friday': 'Fr',
      'Saturday': 'Sa',
      'Sunday': 'Su',
    };

    // Check if all days are selected
    if (days.length == 7 &&
        days.every((day) => allDays.contains(day.trim()))) {
      return 'Daily';
    }

    // Abbreviate selected days
    return days.map((day) => dayAbbreviations[day.trim()] ?? '').join(', ');
  }
}
