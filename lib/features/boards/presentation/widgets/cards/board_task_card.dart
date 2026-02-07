import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/presentation/pages/task_details_page.dart';
import '../../../../tasks/presentation/pages/task_applications_page.dart';
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
  });

  @override
  State<BoardTaskCard> createState() => _BoardTaskCardState();
}

class _BoardTaskCardState extends State<BoardTaskCard> {
  late bool _isInterested;
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _isInterested = widget.task.taskHelpers.contains(_currentUserId);
  }

  bool _isTaskUnassigned() {
    return widget.task.taskAssignedTo.isEmpty || widget.task.taskAssignedTo == 'None';
  }

  bool _shouldAllowUnassigned() {
    // Only allow unassigned status if there are multiple board members
    // If board has only 1 member (the manager), tasks must be assigned
    return widget.board == null || (widget.board!.memberIds.length > 1);
  }

  String _getAutoAssignedUserId() {
    // If board has only 1 member, return that member's ID
    if (widget.board != null && widget.board!.memberIds.length == 1) {
      return widget.board!.memberIds.first;
    }
    return '';
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
      
      // Save appeal to subcollection - wrapped in try-catch for permission errors
      try {
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
      } catch (e) {
        print('⚠️ Warning: Could not save appeal text: $e');
        // Continue anyway - the interest (taskHelpers) was still recorded
      }
      
      if (mounted) {
        setState(() => _isInterested = true);
        
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

  Color _getMemberColor() {
    // Default to blue for all members
    if (widget.task.taskAssignedToName.isEmpty ||
        widget.task.taskAssignedToName == 'Unassigned') {
      return Colors.transparent;
    }
    return Colors.blue;
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
    switch (status) {
      case 'To Do':
        return Colors.grey;
      case 'In Progress':
        return Colors.blue;
      case 'Paused':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'To Do':
        return Icons.circle_outlined;
      case 'In Progress':
        return Icons.autorenew;
      case 'Paused':
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
    final memberColor = _getMemberColor();
    final isUnassigned =
        widget.task.taskAssignedToName.isEmpty ||
        widget.task.taskAssignedToName == 'Unassigned';
    final priorityColor = _getPriorityColor(widget.task.taskPriorityLevel);
    final canHaveUnassigned = _shouldAllowUnassigned();
    
    // Only allow delete for board manager or task owner
    final canDelete =
        !widget.isDisabled &&
        widget.board != null &&
        widget.currentUserId != null &&
        (widget.board!.boardManagerId == widget.currentUserId ||
         widget.task.taskOwnerId == widget.currentUserId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Opacity(
        opacity: widget.isDisabled ? 0.5 : 1,
        child: IgnorePointer(
          ignoring: widget.isDisabled,
          child: Slidable(
            key: ValueKey(widget.task.taskId),
            endActionPane: canDelete
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
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _handleDelete(context),
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
                  )
                : null,
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: () {
                  if (widget.isDisabled) return;
                  Slidable.of(context)?.close();
                  // If task is unassigned, go to applications page first
                  // But only if user is the board manager
                  final isUnassigned = widget.task.taskAssignedTo.isEmpty || widget.task.taskAssignedTo == 'None';
                  final isManager = widget.board?.boardManagerId == _currentUserId;
                  
                  if (isUnassigned && isManager) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TaskApplicationsPage(task: widget.task),
                      ),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TaskDetailsPage(task: widget.task),
                      ),
                    );
                  }
                },
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                    side: BorderSide(
                      color: isUnassigned ? Colors.grey.shade300 : memberColor,
                      width: isUnassigned ? 1 : 2,
                    ),
                  ),
                  child: Container(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
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
                                      color:
                                          isUnassigned
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
                                  if (widget.task.taskHelpers.isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '+${widget.task.taskHelpers.length}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
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
                                    color: _getStatusColor(widget.task.taskStatus),
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
                                      color: _getStatusColor(widget.task.taskStatus),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.task.taskStatus,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(widget.task.taskStatus),
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
                                Checkbox(
                                  value: widget.task.taskIsDone,
                                  onChanged: widget.isDisabled
                                      ? null
                                      : (value) => widget.onToggleDone?.call(value),
                                ),
                                const SizedBox(width: 8),
                              ],
                              // Main content
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      children: [
                                        const Icon(
                                          Icons.calendar_today,
                                          size: 12,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.task.taskDeadline != null
                                              ? '${_formatDate(widget.task.taskDeadline!)} • ${_formatTime(widget.task.taskDeadline!)}'
                                              : 'No deadline',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        if (_getDeadlineTag(widget.task.taskDeadline) != null) ...[
                                          const SizedBox(width: 8),
                                          Builder(
                                            builder: (context) {
                                              final tag = _getDeadlineTag(widget.task.taskDeadline)!;
                                              final color = _getDeadlineTagColor(tag);
                                              return Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: color.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: color, width: 1),
                                                ),
                                                child: Text(
                                                  tag,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
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
                              // Show interest buttons only if task is unassigned AND unassigned is allowed
                              if (_isTaskUnassigned() && canHaveUnassigned)
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
                                                  fontSize: 12,
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
                              // Circular progress indicator
                              if (_hasSubtasks())
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: _getProgress(),
                                        strokeWidth: 2.5,
                                        backgroundColor: const Color(0xFFCFD8DC),
                                        color:
                                            widget.task.taskIsDone
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
                              const SizedBox(width: 8),
                            ],
                          ),
                        ],
                      ),
                    ),
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
    final done = widget.task.taskStats.taskSubtasksDoneCount ?? 0;
    final total = widget.task.taskStats.taskSubtasksCount ?? 0;
    return total > 0 ? done / total : 0.0;
  }

  bool _hasSubtasks() {
    return (widget.task.taskStats.taskSubtasksCount ?? 0) > 0;
  }

  String _getProgressPercent() {
    final total = widget.task.taskStats.taskSubtasksCount ?? 0;
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
    final isSameDay = deadline.year == now.year &&
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



  Future<void> _handleDelete(BuildContext context) async {
    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // Delete the task and pass the task object for activity tracking
      await taskProvider.deleteTask(
        widget.task.taskId,
        ownerId: userProvider.userId,
        task: widget.task,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ Task deleted'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error deleting task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
