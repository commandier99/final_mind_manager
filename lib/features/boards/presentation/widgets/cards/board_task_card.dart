import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/presentation/pages/task_details_page.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../datasources/models/board_model.dart';

class BoardTaskCard extends StatefulWidget {
  final Task task;
  final Board? board;
  final String? currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final ValueChanged<bool?>? onToggleDone;

  const BoardTaskCard({
    super.key,
    required this.task,
    this.board,
    this.currentUserId,
    this.onTap,
    this.onDelete,
    this.onToggleDone,
  });

  @override
  State<BoardTaskCard> createState() => _BoardTaskCardState();
}

class _BoardTaskCardState extends State<BoardTaskCard> {
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
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
    switch (status.toUpperCase()) {
      case 'TODO':
        return Colors.grey;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'IN_REVIEW':
        return Colors.purple;
      case 'ON_PAUSE':
        return Colors.orange;
      case 'UNDER_REVISION':
        return Colors.red;
      case 'COMPLETED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'TODO':
        return Icons.circle_outlined;
      case 'IN_PROGRESS':
        return Icons.autorenew;
      case 'IN_REVIEW':
        return Icons.visibility;
      case 'ON_PAUSE':
        return Icons.pause_circle;
      case 'UNDER_REVISION':
        return Icons.edit;
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
    
    // Only allow delete for board manager or task owner
    final canDelete = widget.board != null && widget.currentUserId != null &&
        (widget.board!.boardManagerId == widget.currentUserId ||
         widget.task.taskOwnerId == widget.currentUserId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Slidable(
        key: ValueKey(widget.task.taskId),
        endActionPane: canDelete ? ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.25,
          children: [
            SlidableAction(
              onPressed: (_) => _handleDelete(context),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
              borderRadius: BorderRadius.circular(12),
            ),
          ],
        ) : null,
        child: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => TaskDetailsPage(task: widget.task),
              ),
            );
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
                        // Checkbox - interactive for manager, view-only for members
                        if (widget.board != null && widget.currentUserId != null)
                          Checkbox(
                            value: widget.task.taskIsDone,
                            onChanged: !_isToggling && widget.board!.boardManagerId == widget.currentUserId
                                ? (bool? newValue) {
                                    _handleToggleDone(newValue ?? false);
                                  }
                                : null, // null makes it view-only for members or disabled during toggle
                          ),
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
                                        ? _formatDate(widget.task.taskDeadline!)
                                        : 'No deadline',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
                        // const SizedBox(width: 8),
                        // // Focus button - Commented out
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
                    // I volunteer button for unassigned tasks or declined tasks
                    if (_shouldShowVolunteerButton()) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => _handleVolunteer(context),
                        icon: const Icon(Icons.volunteer_activism, size: 16),
                        label: Text(
                          widget.task.taskAcceptanceStatus == 'declined'
                              ? 'I volunteer to help'
                              : 'I volunteer',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                    // Accept button for pending assigned tasks (only I got this)
                    if (_shouldShowAcceptButton()) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _handleAcceptTask(context),
                              icon: const Icon(Icons.thumb_up, size: 16),
                              label: const Text('I got this'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _handleRequestHelp(context),
                              icon: const Icon(Icons.help_outline, size: 16),
                              label: const Text('I need help'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Status badge for accepted/declined tasks
                    if (_getAcceptanceStatusBadge() != null) ...[
                      const SizedBox(height: 8),
                      _getAcceptanceStatusBadge()!,
                    ],
                  ],
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

  bool _shouldShowVolunteerButton() {
    // Show volunteer button if:
    // 1. Task is unassigned OR status is 'declined' (help requested)
    // 2. Current user is not already assigned or helping
    // 3. Task is not completed
    if (widget.currentUserId == null || widget.task.taskIsDone) {
      return false;
    }

    final isUnassigned = widget.task.taskAssignedTo.isEmpty;
    final needsHelp = widget.task.taskAcceptanceStatus == 'declined';
    final isNotAssigned = widget.task.taskAssignedTo != widget.currentUserId;
    final isNotHelper = !widget.task.taskHelpers.contains(widget.currentUserId);

    // Only show if (unassigned OR declined) AND user is not involved
    return (isUnassigned || needsHelp) && isNotAssigned && isNotHelper;
  }

  bool _shouldShowAcceptButton() {
    // Show "I got this" button only for pending tasks
    if (widget.currentUserId == null || widget.task.taskIsDone) {
      return false;
    }

    final isAssignedToCurrentUser =
        widget.task.taskAssignedTo == widget.currentUserId;
    final isPending =
        widget.task.taskAcceptanceStatus == null ||
        widget.task.taskAcceptanceStatus == 'pending';

    return isAssignedToCurrentUser && isPending;
  }

  Widget? _getAcceptanceStatusBadge() {
    if (widget.task.taskAcceptanceStatus == null ||
        widget.task.taskAcceptanceStatus == 'pending') {
      return null;
    }

    final isAccepted = widget.task.taskAcceptanceStatus == 'accepted';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAccepted ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAccepted ? Colors.green[300]! : Colors.orange[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAccepted ? Icons.thumb_up : Icons.help_outline,
            size: 14,
            color: isAccepted ? Colors.green[700] : Colors.orange[700],
          ),
          const SizedBox(width: 4),
          Text(
            isAccepted ? 'Accepted' : 'Needs Help',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isAccepted ? Colors.green[700] : Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAcceptTask(BuildContext context) async {
    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      await taskProvider.acceptTask(widget.task.taskId);

      if (context.mounted) {
        // Force rebuild by calling setState
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Task accepted! You got this!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error accepting task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleRequestHelp(BuildContext context) async {
    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      await taskProvider.declineTask(widget.task.taskId);

      if (context.mounted) {
        // Force rebuild by calling setState
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📢 Help requested! Others can now volunteer.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error requesting help: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleVolunteer(BuildContext context) async {
    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      await taskProvider.volunteerForTask(widget.task.taskId);

      if (context.mounted) {
        // Force rebuild by calling setState
        setState(() {});

        final isHelping = widget.task.taskAcceptanceStatus == 'declined';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isHelping
                  ? '🤝 You volunteered to help with this task!'
                  : '🙋 You volunteered for this task!',
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error volunteering: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleToggleDone(bool isDone) async {
    try {
      // Prevent multiple rapid toggles
      if (_isToggling) return;
      
      setState(() {
        _isToggling = true;
      });

      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      
      // Create updated task with new status
      final updatedTask = widget.task.copyWith(
        taskIsDone: isDone,
        taskStatus: isDone ? 'COMPLETED' : 'TODO',
      );
      
      // Toggle the task done status
      await taskProvider.toggleTaskDone(updatedTask);
      
      if (mounted) {
        setState(() {
          _isToggling = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDone ? '✅ Task completed!' : '↩️ Task marked as incomplete',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isToggling = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error updating task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
