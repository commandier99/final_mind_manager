import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/models/task_stats_model.dart';
import '../../../../tasks/datasources/helpers/task_dependency_helper.dart';
import '../../../../tasks/presentation/utils/task_assignment_workflow_helper.dart';
import '../../../datasources/models/board_model.dart';
import '../../../../../shared/features/users/datasources/services/user_services.dart';
import 'package:uuid/uuid.dart';

class AddTaskToBoardDialog extends StatefulWidget {
  final String userId;
  final Board board;
  final ValueChanged<String>? onTaskCreated;
  final bool asSheet;

  const AddTaskToBoardDialog({
    super.key,
    required this.userId,
    required this.board,
    this.onTaskCreated,
    this.asSheet = false,
  });

  @override
  State<AddTaskToBoardDialog> createState() => _AddTaskToBoardDialogState();
}

class _AddTaskToBoardDialogState extends State<AddTaskToBoardDialog> {
  static const String _laneDrafts = Task.laneDrafts;
  static const String _lanePublished = Task.lanePublished;
  static const TimeOfDay _defaultDeadlineTime = TimeOfDay(hour: 23, minute: 59);

  String _priorityLevel = 'Low';
  String _taskBoardLane = _laneDrafts;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _deadline;
  TimeOfDay? _deadlineTime;
  bool _isRepeating = false;
  bool _taskRequiresSubmission = false;
  bool _taskRequiresApproval = false;
  final List<String> _repeatDays = [];
  DateTime? _repeatEndDate;
  TimeOfDay? _repeatTime;
  String? _assignedToUserId;
  String? _assignedToUserName;
  final Set<String> _selectedDependencyIds = <String>{};
  Map<String, String> _boardMembers = {};
  bool _loadingMembers = true;
  String _currentUserName = 'Unknown'; // Store current user's name
  final String? _viewerUserId = FirebaseAuth.instance.currentUser?.uid;

  static const List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  bool get _isCurrentUserSupervisor =>
      widget.board.isSupervisor(widget.userId) &&
      !widget.board.isManager(widget.userId);

  @override
  void initState() {
    super.initState();
    if (widget.board.boardType == 'personal') {
      _taskBoardLane = _lanePublished;
    } else if (_isCurrentUserSupervisor) {
      _taskBoardLane = _laneDrafts;
    }
    _loadBoardMembers();
  }

  Future<void> _loadBoardMembers() async {
    setState(() => _loadingMembers = true);

    final members = <String, String>{};

    // Add the manager (current user) with their actual name
    try {
      final currentUserData = await UserService().getUserById(widget.userId);
      if (currentUserData != null && currentUserData.userName.isNotEmpty) {
        _currentUserName = currentUserData.userName;
        members[widget.userId] = currentUserData.userName;
      } else {
        members[widget.userId] = 'Manager';
      }
    } catch (e) {
      members[widget.userId] = 'Manager';
    }

    // Add all board members
    for (String memberId in widget.board.memberIds) {
      if (memberId != widget.userId) {
        // Skip supervisors - they cannot be assigned tasks
        final role =
            (widget.board.memberRoles[memberId] ?? '').trim().toLowerCase();
        if (role == 'supervisor') continue;

        try {
          final userData = await UserService().getUserById(memberId);
          if (userData != null && userData.userName.isNotEmpty) {
            members[memberId] = userData.userName;
          } else {
            members[memberId] = 'Unknown User';
          }
        } catch (e) {
          members[memberId] = 'Unknown User';
        }
      }
    }

    setState(() {
      _boardMembers = members;
      if (widget.board.boardType == 'personal') {
        _assignedToUserId = widget.board.boardManagerId;
        _assignedToUserName =
            members[widget.board.boardManagerId] ?? _currentUserName;
      } else {
        // Default assignment is always None.
        _assignedToUserId = null;
        _assignedToUserName = null;
      }
      _loadingMembers = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Get the next untitled task number based on existing tasks
  String _getNextUntitledTaskNumber(List<Task> existingTasks) {
    int maxNumber = 0;
    final regex = RegExp(r'^Task (\d+)$');

    for (final task in existingTasks) {
      final match = regex.firstMatch(task.taskTitle);
      if (match != null) {
        final number = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (number > maxNumber) {
          maxNumber = number;
        }
      }
    }

    return 'Task ${(maxNumber + 1).toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    // Show loading modal
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: Dialog(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text(
                    'Creating task...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final taskProvider = context.read<TaskProvider>();
      final boardTasks = taskProvider.tasks.where((task) {
        return task.taskBoardId == widget.board.boardId && !task.taskIsDeleted;
      }).toList();

      if (widget.board.boardType != 'personal' &&
          _assignedToUserId != null &&
          _assignedToUserId != widget.userId &&
          _isAtCapacity(_assignedToUserId!, boardTasks)) {
        if (mounted) {
          Navigator.pop(context); // close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This member is already at task capacity.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      String taskTitle = _titleController.text.trim();

      // If title is empty, generate default "Task XX" title
      if (taskTitle.isEmpty) {
        taskTitle = _getNextUntitledTaskNumber(taskProvider.tasks);
      }

      // Merge deadline date with time
      DateTime? finalDeadline = _deadline;
      if (finalDeadline != null) {
        final effectiveTime = _deadlineTime ?? _defaultDeadlineTime;
        finalDeadline = DateTime(
          finalDeadline.year,
          finalDeadline.month,
          finalDeadline.day,
          effectiveTime.hour,
          effectiveTime.minute,
        );
      }

      // Debug logging
      debugPrint('?? [TaskDialog] Creating task with deadline: $finalDeadline');
      if (finalDeadline == null) {
        debugPrint('?? [TaskDialog] No deadline set for this task');
      }

      // Convert repeat time to HH:mm format
      String? repeatTimeStr;
      if (_repeatTime != null) {
        repeatTimeStr =
            '${_repeatTime!.hour.toString().padLeft(2, '0')}:${_repeatTime!.minute.toString().padLeft(2, '0')}';
      }

      final hasProposedAssignee = TaskAssignmentWorkflowHelper.requiresAcceptance(
        boardType: widget.board.boardType,
        boardManagerId: widget.board.boardManagerId,
        assigneeId: _assignedToUserId,
      );

      final newTask = Task(
        taskId: const Uuid().v4(),
        taskBoardId: widget.board.boardId,
        taskBoardTitle: widget.board.boardTitle,
        taskOwnerId: widget.userId,
        taskOwnerName: _currentUserName,
        taskAssignedBy: widget.userId,
        // Personal boards always assign to board manager.
        taskAssignedTo: widget.board.boardType == 'personal'
            ? widget.board.boardManagerId
            : (hasProposedAssignee ? 'None' : (_assignedToUserId ?? 'None')),
        taskAssignedToName: widget.board.boardType == 'personal'
            ? (_boardMembers[widget.board.boardManagerId] ?? _currentUserName)
            : (hasProposedAssignee
                  ? 'None (Pending)'
                  : (_assignedToUserName ?? 'Unassigned')),
        taskCreatedAt: DateTime.now(),
        taskTitle: taskTitle,
        taskDescription: _descriptionController.text.trim(),
        taskDeadline: finalDeadline,
        taskIsDone: false,
        taskIsDoneAt: null,
        taskIsDeleted: false,
        taskDeletedAt: null,
        taskStats: TaskStats(),
        taskPriorityLevel: _priorityLevel,
        taskStatus: 'To Do',
        taskAllowsSubmissions:
            _taskRequiresSubmission || _taskRequiresApproval,
        taskRequiresSubmission: _taskRequiresSubmission,
        taskRequiresApproval: _taskRequiresApproval,
        taskIsRepeating: _isRepeating,
        taskRepeatInterval: _repeatDays.isNotEmpty
            ? _repeatDays.join(',')
            : null,
        taskRepeatEndDate: _repeatEndDate,
        taskNextRepeatDate: null,
        taskRepeatTime: repeatTimeStr,
        taskBoardLane: widget.board.boardType == 'personal'
            ? _lanePublished
            : (_isCurrentUserSupervisor ? _laneDrafts : _taskBoardLane),
        taskAssignmentStatus: hasProposedAssignee ? 'pending' : null,
        taskProposedAssigneeId: hasProposedAssignee ? _assignedToUserId : null,
        taskProposedAssigneeName: hasProposedAssignee
            ? _assignedToUserName
            : null,
        taskDependencyIds: TaskDependencyHelper.sanitizeDependencyIds(
          _selectedDependencyIds,
        ),
      );

      // Pass the selected member for assignment notification, not the task itself
      await taskProvider.addTask(newTask);
      if (hasProposedAssignee && _assignedToUserId != null) {
        await TaskAssignmentWorkflowHelper.createAssignmentRequestIfNeeded(
          context: context,
          task: newTask,
          assigneeId: _assignedToUserId!,
          assigneeName: _assignedToUserName ?? 'Assigned Member',
          actorUserId: widget.userId,
          actorUserName: _currentUserName,
        );
      }
      widget.onTaskCreated?.call(newTask.taskId);

      if (mounted) {
        Navigator.pop(context); // Close loading modal
        Navigator.pop(context); // Close dialog

        // Show snackbar after dialogs are closed and widget tree is stable
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Task "${newTask.taskTitle}" added to ${widget.board.boardTitle}',
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error creating task: $e');
      if (mounted) {
        // Close loading modal only
        Navigator.pop(context);
        // Close dialog after a brief delay to ensure stable widget tree
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });

        // Show error snackbar after dialog is closed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error creating task: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    }
  }

  List<Task> _dependencyCandidates(TaskProvider taskProvider) {
    final tasks = taskProvider.tasks
        .where(
          (task) =>
              task.taskBoardId == widget.board.boardId && !task.taskIsDeleted,
        )
        .toList();
    tasks.sort(
      (a, b) => a.taskTitle.toLowerCase().compareTo(b.taskTitle.toLowerCase()),
    );
    return tasks;
  }

  Future<void> _showDependenciesPicker() async {
    final taskProvider = context.read<TaskProvider>();
    final candidates = _dependencyCandidates(taskProvider);

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Choose tasks that must be done first'),
            content: SizedBox(
              width: 520,
              child: candidates.isEmpty
                  ? const Text(
                      'No existing tasks yet. Create one first, then come back.',
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final candidate = candidates[index];
                        final isSelected = _selectedDependencyIds.contains(
                          candidate.taskId,
                        );
                        return CheckboxListTile(
                          value: isSelected,
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            candidate.taskTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle:
                              candidate.taskAssignedToName.isEmpty ||
                                  candidate.taskAssignedToName == 'Unassigned'
                              ? null
                              : Text(
                                  'Assigned: ${candidate.taskAssignedToName}',
                                ),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked ?? false) {
                                _selectedDependencyIds.add(candidate.taskId);
                              } else {
                                _selectedDependencyIds.remove(candidate.taskId);
                              }
                            });
                            setState(() {});
                          },
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() => _selectedDependencyIds.clear());
                  Navigator.pop(context);
                },
                child: const Text('Clear'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  Task? _findDependencyTask(String dependencyId, TaskProvider taskProvider) {
    return taskProvider.tasks.cast<Task?>().firstWhere(
      (task) => task?.taskId == dependencyId,
      orElse: () => null,
    );
  }

  String _formatTaskDeadline(DateTime? deadline) {
    if (deadline == null) return 'No deadline';
    final month = deadline.month.toString().padLeft(2, '0');
    final day = deadline.day.toString().padLeft(2, '0');
    return '$month/$day';
  }

  Widget _buildRequiredTaskCard(
    BuildContext context, {
    required String dependencyId,
  }) {
    final taskProvider = context.read<TaskProvider>();
    final task = _findDependencyTask(dependencyId, taskProvider);
    final taskTitle = task?.taskTitle ?? 'Task unavailable';
    final assignedTo = (task?.taskAssignedToName ?? '').trim();
    final assignedLabel = assignedTo.isEmpty || assignedTo == 'Unassigned'
        ? 'Unassigned'
        : assignedTo;
    final description = (task?.taskDescription ?? '').trim();
    final descriptionLabel = description.isEmpty
        ? 'No description'
        : description;
    final deadlineLabel = _formatTaskDeadline(task?.taskDeadline);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  taskTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                tooltip: 'Remove required task',
                onPressed: () {
                  setState(() {
                    _selectedDependencyIds.remove(dependencyId);
                  });
                },
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            descriptionLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildMetaPill(Icons.person_outline, assignedLabel),
              _buildMetaPill(Icons.event_outlined, deadlineLabel),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _assigneeOptionLabel(String memberId, String memberName) {
    if (_viewerUserId != null && memberId == _viewerUserId) {
      return '$memberName (You)';
    }
    return memberName;
  }

  int _activeTasksForMember({
    required List<Task> boardTasks,
    required String memberId,
  }) {
    return boardTasks
        .where(
          (task) =>
              task.taskAssignedTo == memberId &&
              !task.taskIsDeleted &&
              !task.taskIsDone,
        )
        .length;
  }

  int _taskLimitForMember(String memberId) {
    return widget.board.taskLimitForUser(memberId);
  }

  bool _isAtCapacity(String memberId, List<Task> boardTasks) {
    final limit = _taskLimitForMember(memberId);
    if (limit <= 0) return false;
    final active = _activeTasksForMember(
      boardTasks: boardTasks,
      memberId: memberId,
    );
    return active >= limit;
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade700;
      case 'medium':
        return Colors.orange.shade700;
      default:
        return Colors.green.shade700;
    }
  }

  Color _priorityBackgroundColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade50;
      case 'medium':
        return Colors.orange.shade50;
      default:
        return Colors.green.shade50;
    }
  }

  Widget _buildPrioritySelector() {
    const levels = <String>['Low', 'Medium', 'High'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          const Text(
            'Priority Level:',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          ...levels.map((level) {
            final isSelected = _priorityLevel == level;
            final color = _priorityColor(level);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  level,
                  style: TextStyle(
                    color: isSelected ? Colors.white : color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (!selected) return;
                  setState(() => _priorityLevel = level);
                },
                selectedColor: color,
                backgroundColor: _priorityBackgroundColor(level),
                side: BorderSide(color: color.withValues(alpha: 0.35)),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLaneSection() {
    Widget laneButton({
      required String value,
      required String label,
      required IconData icon,
    }) {
      final isSelected = _taskBoardLane == value;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _taskBoardLane = value),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1565C0) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1565C0)
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 16,
                color: Colors.grey[700],
              ),
              const SizedBox(width: 6),
              Text(
                'Task Visibility',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              laneButton(
                value: _laneDrafts,
                label: 'Drafts',
                icon: Icons.edit_note,
              ),
              if (!_isCurrentUserSupervisor) ...[
                const SizedBox(width: 8),
                laneButton(
                  value: _lanePublished,
                  label: 'Published',
                  icon: Icons.campaign_outlined,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _isCurrentUserSupervisor
                ? 'Supervisors can draft tasks. Managers publish them when ready.'
                : (_taskBoardLane == _laneDrafts
                      ? 'Drafts keeps this task private for manager prep.'
                      : 'Published makes this task visible to members.'),
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildDependenciesSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link, size: 16, color: Colors.grey[700]),
              const SizedBox(width: 6),
              Text(
                'Dependencies (Optional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Set tasks that must be completed before this one can start.',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _showDependenciesPicker,
            icon: const Icon(Icons.account_tree_outlined),
            label: Text(
              _selectedDependencyIds.isEmpty
                  ? 'Select Required Tasks'
                  : 'Required Tasks: ${_selectedDependencyIds.length}',
            ),
          ),
          if (_selectedDependencyIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._selectedDependencyIds.map(
              (dependencyId) =>
                  _buildRequiredTaskCard(context, dependencyId: dependencyId),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmissionOptionsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_turned_in,
                size: 16,
                color: Colors.grey[700],
              ),
              const SizedBox(width: 6),
              Text(
                'Submission Settings',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Control whether members can submit outputs and whether manager/supervisor review is required.',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Submission Required'),
            value: _taskRequiresSubmission,
            onChanged: (value) {
              setState(() => _taskRequiresSubmission = value);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reviewer Approval Required'),
            value: _taskRequiresApproval,
            onChanged: (value) {
              setState(() => _taskRequiresApproval = value);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boardTasks = context.watch<TaskProvider>().tasks.where((task) {
      return task.taskBoardId == widget.board.boardId && !task.taskIsDeleted;
    }).toList();

    final formContent = SingleChildScrollView(
      child: ConstrainedBox(
        constraints: widget.asSheet
            ? const BoxConstraints()
            : const BoxConstraints(minWidth: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Task Title',
                border: const OutlineInputBorder(),
                counterText: '${_titleController.text.length}/50',
              ),
              maxLength: 50,
              autofocus: true,
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                border: const OutlineInputBorder(),
                counterText: '${_descriptionController.text.length}/500',
              ),
              maxLines: 3,
              maxLength: 500,
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _buildPrioritySelector(),
            const SizedBox(height: 12),
            if (widget.board.boardType == 'team') ...[
              _buildLaneSection(),
              const SizedBox(height: 12),
            ],
            _buildDependenciesSection(context),
            const SizedBox(height: 12),
            _buildSubmissionOptionsSection(),
            const SizedBox(height: 12),
            if (widget.board.boardType == 'team' &&
                !_loadingMembers &&
                _boardMembers.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: DropdownButtonFormField<String?>(
                  initialValue: _assignedToUserId,
                  decoration: const InputDecoration(
                    labelText: 'Assign To',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None'),
                    ),
                    ..._boardMembers.entries.map((entry) {
                      final active = _activeTasksForMember(
                        boardTasks: boardTasks,
                        memberId: entry.key,
                      );
                      final limit = _taskLimitForMember(entry.key);
                      final atCapacity =
                          entry.key != widget.userId &&
                          _isAtCapacity(entry.key, boardTasks);
                      final loadSuffix = limit > 0
                          ? ' ($active/$limit active)'
                          : ' ($active active)';
                      return DropdownMenuItem<String?>(
                        value: entry.key,
                        enabled: !atCapacity,
                        child: Text(
                          '${_assigneeOptionLabel(entry.key, entry.value)}$loadSuffix${atCapacity ? ' - At Capacity' : ''}',
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _assignedToUserId = val;
                      _assignedToUserName = val != null
                          ? _boardMembers[val]
                          : null;
                    });
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _deadline ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          _deadline = picked;
                          _deadlineTime ??= _defaultDeadlineTime;
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _deadline == null
                          ? 'Set Deadline'
                          : 'Deadline: ${_deadline!.toLocal().toString().split(' ')[0]}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _deadline == null
                      ? null
                      : () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _deadlineTime ?? TimeOfDay.now(),
                          );
                          if (picked != null) {
                            setState(() => _deadlineTime = picked);
                          }
                        },
                  icon: const Icon(Icons.access_time),
                  label: Text(
                    _deadlineTime == null
                        ? 'Time'
                        : _deadlineTime!.format(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_deadline != null)
              SwitchListTile(
                title: const Text('Repeating Task'),
                value: _isRepeating,
                onChanged: (val) => setState(() => _isRepeating = val),
                contentPadding: EdgeInsets.zero,
              ),
            if (_deadline != null && _isRepeating) ...[
              const SizedBox(height: 12),
              const Text(
                'Repeat on days:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _daysOfWeek
                      .map(
                        (day) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(day.substring(0, 3)),
                            selected: _repeatDays.contains(day),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _repeatDays.add(day);
                                  // Sort days by week order
                                  _repeatDays.sort(
                                    (a, b) =>
                                        _daysOfWeek.indexOf(a) -
                                        _daysOfWeek.indexOf(b),
                                  );
                                } else {
                                  _repeatDays.remove(day);
                                }
                              });
                            },
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _repeatEndDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _repeatEndDate = picked);
                        }
                      },
                      icon: const Icon(Icons.event),
                      label: Text(
                        _repeatEndDate == null
                            ? 'Set Repeat End Date'
                            : 'Ends: ${_repeatEndDate!.toLocal().toString().split(' ')[0]}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _repeatTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setState(() => _repeatTime = picked);
                      }
                    },
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      _repeatTime == null
                          ? 'Time'
                          : _repeatTime!.format(context),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    final actions = <Widget>[
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ElevatedButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    ];

    if (!widget.asSheet) {
      return AlertDialog(
        title: Text('Add Task to ${widget.board.boardTitle}'),
        content: formContent,
        actions: actions,
      );
    }

    return SafeArea(
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.92,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add Task to ${widget.board.boardTitle}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: formContent,
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [...actions],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
