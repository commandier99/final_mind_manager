import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../datasources/models/task_model.dart';
import '../../../datasources/providers/task_provider.dart';
import '../../pages/task_details_page.dart';
import '../../pages/task_applications_page.dart';
import '../dialogs/edit_task_dialog.dart';
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
  final bool isPomodoroMode;

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
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
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
              _submitAppeal(appealController.text);
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

  Stream<bool> _isUserInterestedStream() {
    return FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.task.taskId)
        .collection('appeals')
        .where('userId', isEqualTo: _currentUserId)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  Future<void> _submitAppeal(String appealText) async {
    await FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.task.taskId)
        .collection('appeals')
        .add({
      'userId': _currentUserId,
      'appealText': appealText,
      'createdAt': Timestamp.now(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Interest submitted!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _removeAppeal() async {
    final query = await FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.task.taskId)
        .collection('appeals')
        .where('userId', isEqualTo: _currentUserId)
        .get();

    for (final doc in query.docs) {
      await doc.reference.delete();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Interest removed'),
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
    final daysUntil = widget.task.taskDeadline!.difference(DateTime.now()).inDays;
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
    final daysUntil = deadline.difference(DateTime(now.year, now.month, now.day)).inDays;
    
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
    
    final showCheckbox =
      !widget.showCheckboxWhenFocusedOnly || (isFocused && !isCompleted);
    final statusColor = widget.useStatusColor
      ? _getStatusColor(widget.task.taskStatus)
      : Theme.of(context).colorScheme.onSurfaceVariant;

    final cardBaseColor = Theme.of(context).cardColor;
    final borderColor = isFocused ? statusColor : Colors.grey.shade300;

    // Check if user can edit (task owner or board manager)
    bool canEditTask = widget.task.taskOwnerId == _currentUserId;
    if (!canEditTask && widget.task.taskBoardId.isNotEmpty) {
      final boardProvider = context.read<BoardProvider>();
      final board = boardProvider.getBoardById(widget.task.taskBoardId);
      if (board?.boardManagerId == _currentUserId) {
        canEditTask = true;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Slidable(
        key: ValueKey(widget.task.taskId),
        startActionPane: canEditTask
            ? ActionPane(
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
                          color: Colors.blue.shade400,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Slidable.of(context)?.close();
                              showDialog(
                                context: context,
                                builder: (context) => EditTaskDialog(task: widget.task),
                              );
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 20),
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
                ],
              )
            : null,
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
              side: BorderSide(color: borderColor, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            Icon(Icons.label, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              widget.task.taskBoardTitle ?? 'Personal',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getPriorityBackgroundColor(widget.task.taskPriorityLevel),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.task.taskPriorityLevel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getPriorityColor(widget.task.taskPriorityLevel),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: statusColor, width: 1.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getStatusIcon(widget.task.taskStatus), size: 11, color: statusColor),
                            const SizedBox(width: 3),
                            Text(
                              widget.task.taskStatus,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
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
                        Checkbox(
                          value: widget.task.taskIsDone,
                          onChanged: (bool? newValue) => widget.onToggleDone?.call(newValue),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                                      : _formatDeadline(widget.task.taskDeadline),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: widget.task.taskDeadline == null
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
                                widget.task.taskAcceptanceStatus != null)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.task.taskRequiresApproval)
                                      Tooltip(
                                        message: 'Requires approval',
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.purple[100],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Icon(Icons.verified_user, size: 10, color: Colors.purple[700]),
                                        ),
                                      ),
                                    if (widget.task.taskAcceptanceStatus != null)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Tooltip(
                                          message: _getAcceptanceStatusLabel(widget.task.taskAcceptanceStatus),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: _getAcceptanceStatusColor(widget.task.taskAcceptanceStatus).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Icon(Icons.check_circle, size: 10, color: _getAcceptanceStatusColor(widget.task.taskAcceptanceStatus)),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Right side indicators
                      if (showFocusAction && widget.showFocusInMainRow)
                        // In Pomodoro: hide button when focused, show focus when not focused
                        // In other modes: show pause when focused, show focus when not focused
                        if (widget.isPomodoroMode && !isFocused)
                          IconButton(
                            onPressed: widget.onFocus,
                            icon: const Icon(Icons.adjust, size: 28),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          )
                        else if (!widget.isPomodoroMode)
                          IconButton(
                            onPressed: isFocused ? widget.onPause : widget.onFocus,
                            icon: Icon(isFocused ? Icons.pause : Icons.adjust, size: 28),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          )
                      else if (!showFocusAction && _isTaskUnassigned() && _shouldAllowUnassigned())
                        StreamBuilder<bool>(
                          stream: _isUserInterestedStream(),
                          builder: (context, snapshot) {
                            final isInterested = snapshot.data ?? false;

                            return GestureDetector(
                              onTap: () {
                                if (isInterested) {
                                  _removeAppeal();
                                } else {
                                  _showAppealDialog();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isInterested ? Colors.green[100] : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isInterested ? Colors.green : Colors.grey[300]!,
                                  ),
                                ),
                                child: Icon(
                                  isInterested ? Icons.thumb_up : Icons.thumb_up_outlined,
                                  size: 16,
                                  color: isInterested ? Colors.green : Colors.grey[600],
                                ),
                              ),
                            );
                          },
                        )

                      else if (_hasSubtasks())
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
                              Text("$percent%", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
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
                        onPressed: isFocused ? widget.onPause : widget.onFocus,
                        icon: Icon(isFocused ? Icons.pause : Icons.adjust, size: 14),
                        label: Text(isFocused ? 'Pause' : 'Focus', style: const TextStyle(fontSize: 11)),
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
