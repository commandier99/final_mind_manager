import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../datasources/models/task_model.dart';
import '../../../datasources/providers/task_provider.dart';
import '../../../datasources/helpers/task_dependency_helper.dart';
import '../../../../boards/datasources/models/board_model.dart';
import '../../../../boards/datasources/services/board_services.dart';
import '../../../../../shared/features/users/datasources/services/user_services.dart';
import '../../../../notifications/datasources/helpers/notification_helper.dart';

class EditTaskDialog extends StatefulWidget {
  final Task task;
  final bool asSheet;
  const EditTaskDialog({super.key, required this.task, this.asSheet = false});

  @override
  State<EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<EditTaskDialog> {
  static const String _laneDrafts = Task.laneDrafts;
  static const String _lanePublished = Task.lanePublished;
  static const TimeOfDay _defaultDeadlineTime = TimeOfDay(hour: 23, minute: 59);

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _priorityLevel;
  late DateTime? _deadline;
  late TimeOfDay? _deadlineTime;
  late bool _isRepeating;
  late List<String> _repeatDays;
  late DateTime? _repeatEndDate;
  late TimeOfDay? _repeatTime;
  late bool _taskAllowsSubmissions;
  late bool _taskRequiresSubmission;
  late bool _taskRequiresApproval;
  String? _assignedToUserId;
  String? _assignedToUserName;
  late Set<String> _selectedDependencyIds;
  late String _taskBoardLane;
  String _boardType = 'team';
  Board? _boardDetails;
  Map<String, String> _boardMembers = {};
  bool _loadingMembers = true;
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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.taskTitle);
    _descriptionController = TextEditingController(
      text: widget.task.taskDescription,
    );
    _priorityLevel = widget.task.taskPriorityLevel;
    _deadline = widget.task.taskDeadline;
    // Extract time from deadline if it exists
    if (widget.task.taskDeadline != null) {
      _deadlineTime = TimeOfDay.fromDateTime(widget.task.taskDeadline!);
    } else {
      _deadlineTime = null;
    }
    _isRepeating = widget.task.taskIsRepeating;
    // Parse repeat days from comma-separated string
    if (widget.task.taskRepeatInterval != null &&
        widget.task.taskRepeatInterval!.isNotEmpty) {
      _repeatDays = widget.task.taskRepeatInterval!.split(',').toList();
    } else {
      _repeatDays = [];
    }
    _repeatEndDate = widget.task.taskRepeatEndDate;
    // Parse repeat time from taskRepeatTime string
    if (widget.task.taskRepeatTime != null) {
      final parts = widget.task.taskRepeatTime!.split(':');
      if (parts.length == 2) {
        _repeatTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }
    } else {
      _repeatTime = null;
    }
    _taskAllowsSubmissions = widget.task.taskAllowsSubmissions;
    _taskRequiresSubmission = widget.task.taskRequiresSubmission;
    _taskRequiresApproval = widget.task.taskRequiresApproval;
    // Handle "None" or empty assignedTo values
    if (widget.task.taskAssignedTo.isEmpty ||
        widget.task.taskAssignedTo == 'None') {
      _assignedToUserId = null;
      _assignedToUserName = null;
    } else {
      _assignedToUserId = widget.task.taskAssignedTo;
      _assignedToUserName = widget.task.taskAssignedToName;
    }
    _taskBoardLane = widget.task.taskBoardLane;
    _selectedDependencyIds = TaskDependencyHelper.sanitizeDependencyIds(
      widget.task.taskDependencyIds,
      selfTaskId: widget.task.taskId,
    ).toSet();
    _loadBoardMembers();
  }

  Future<void> _loadBoardMembers() async {
    setState(() => _loadingMembers = true);

    try {
      final board = await BoardService().getBoardById(widget.task.taskBoardId);
      if (board == null) {
        setState(() => _loadingMembers = false);
        return;
      }

      final members = <String, String>{};

      // Add the task owner (manager)
      members[widget.task.taskOwnerId] = 'Manager';

      // Add all board members
      for (String memberId in board.memberIds) {
        if (memberId != widget.task.taskOwnerId) {
          // Skip supervisors - they cannot be assigned tasks
          final role = board.memberRoles[memberId] ?? 'member';
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
        _boardDetails = board;
        _boardType = board.boardType;
        if (_boardType == 'personal') _taskBoardLane = _lanePublished;
        _boardMembers = members;
        _loadingMembers = false;
      });
    } catch (e) {
      setState(() => _loadingMembers = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title cannot be empty')));
      return;
    }

    try {
      final taskProvider = context.read<TaskProvider>();

      final bool assigneeChanged =
          _assignedToUserId != widget.task.taskAssignedTo;

      if (_boardType != 'personal' &&
          _assignedToUserId != null &&
          _assignedToUserId != widget.task.taskOwnerId &&
          _isAtCapacity(
            _assignedToUserId!,
            taskProvider.tasks
                .where(
                  (task) =>
                      task.taskBoardId == widget.task.taskBoardId &&
                      !task.taskIsDeleted,
                )
                .toList(),
            includeCurrentTask: false,
          )) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This member is already at task capacity.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final updatedTask = widget.task.copyWith(
        taskTitle: _titleController.text.trim(),
        taskDescription: _descriptionController.text.trim(),
        taskPriorityLevel: _priorityLevel,
        taskDeadline: _deadline != null
            ? DateTime(
                _deadline!.year,
                _deadline!.month,
                _deadline!.day,
                (_deadlineTime ?? _defaultDeadlineTime).hour,
                (_deadlineTime ?? _defaultDeadlineTime).minute,
              )
            : _deadline,
        taskIsRepeating: _isRepeating,
        taskRepeatInterval: _repeatDays.isNotEmpty
            ? _repeatDays.join(',')
            : null,
        taskRepeatEndDate: _repeatEndDate,
        taskRepeatTime: _repeatTime != null
            ? '${_repeatTime!.hour.toString().padLeft(2, '0')}:${_repeatTime!.minute.toString().padLeft(2, '0')}'
            : null,
        // Personal boards always assign to manager.
        taskAssignedTo: _boardType == 'personal'
            ? widget.task.taskOwnerId
            : (_assignedToUserId ?? 'None'),
        taskAssignedToName: _boardType == 'personal'
            ? widget.task.taskOwnerName
            : (_assignedToUserName ?? 'Unassigned'),
        taskBoardLane: _boardType == 'personal'
            ? _lanePublished
            : _taskBoardLane,
        // Reset acceptance status to 'pending' if task is reassigned to a different person
        taskAcceptanceStatus: _boardType == 'personal'
            ? null
            : (assigneeChanged
            ? (_assignedToUserId != null &&
                      _assignedToUserId != widget.task.taskOwnerId
                  ? 'pending'
                  : null)
            : widget.task.taskAcceptanceStatus),
        taskDependencyIds: TaskDependencyHelper.sanitizeDependencyIds(
          _selectedDependencyIds,
          selfTaskId: widget.task.taskId,
        ),
        taskAllowsSubmissions: _taskAllowsSubmissions,
        taskRequiresSubmission: _taskAllowsSubmissions
            ? _taskRequiresSubmission
            : false,
        taskRequiresApproval: _taskAllowsSubmissions
            ? _taskRequiresApproval
            : false,
      );

      await taskProvider.updateTask(updatedTask);

      // Send notification if task was reassigned to a different user
      if (assigneeChanged &&
          _assignedToUserId != null &&
          _assignedToUserId != 'None' &&
          _assignedToUserId != widget.task.taskOwnerId) {
        try {
          final deadlineInfo = updatedTask.taskDeadline != null
              ? ' with a deadline on ${updatedTask.taskDeadline!.toString().split(' ')[0]}'
              : '';

          await NotificationHelper.createInAppOnly(
            userId: _assignedToUserId!,
            title: 'Task Assigned',
            message:
                'You have been assigned to "${updatedTask.taskTitle}"$deadlineInfo',
            category: 'task_assignment',
            relatedId: updatedTask.taskId,
            metadata: {
              'boardId': updatedTask.taskBoardId,
              'taskId': updatedTask.taskId,
              'taskTitle': updatedTask.taskTitle,
              'deadline': updatedTask.taskDeadline?.toIso8601String() ?? '',
              'assignedBy': updatedTask.taskAssignedBy,
            },
          );
          print(
            '[TaskNotification] ? Task reassignment notification sent to: $_assignedToUserId',
          );
        } catch (e) {
          print(
            '[TaskNotification] ?? Failed to send reassignment notification: $e',
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating task: $e')));
      }
    }
  }

  List<Task> _dependencyCandidates(TaskProvider taskProvider) {
    final tasks = taskProvider.tasks
        .where(
          (task) =>
              task.taskBoardId == widget.task.taskBoardId &&
              task.taskId != widget.task.taskId &&
              !task.taskIsDeleted,
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
                  ? const Text('No other tasks available on this board yet.')
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
                            final wantsSelect = checked ?? false;
                            if (wantsSelect) {
                              final createsCycle =
                                  TaskDependencyHelper.wouldCreateCycle(
                                    taskId: widget.task.taskId,
                                    candidateDependencyId: candidate.taskId,
                                    tasks: taskProvider.tasks,
                                    selectedDependencies:
                                        _selectedDependencyIds,
                                  );
                              if (createsCycle) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Cannot set "${candidate.taskTitle}" as prerequisite because it creates a circular dependency.',
                                    ),
                                  ),
                                );
                                return;
                              }
                            }

                            setDialogState(() {
                              if (wantsSelect) {
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
    final board = _boardDetails;
    if (board == null) return 0;
    return board.taskLimitForUser(memberId);
  }

  bool _isAtCapacity(
    String memberId,
    List<Task> boardTasks, {
    bool includeCurrentTask = true,
  }) {
    final limit = _taskLimitForMember(memberId);
    if (limit <= 0) return false;
    var active = _activeTasksForMember(
      boardTasks: boardTasks,
      memberId: memberId,
    );
    if (!includeCurrentTask &&
        widget.task.taskAssignedTo == memberId &&
        !widget.task.taskIsDone &&
        !widget.task.taskIsDeleted &&
        active > 0) {
      active -= 1;
    }
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
              const SizedBox(width: 8),
              laneButton(
                value: _lanePublished,
                label: 'Published',
                icon: Icons.campaign_outlined,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _taskBoardLane == _laneDrafts
                ? 'Drafts keeps this task private for manager prep.'
                : 'Published makes this task visible to members.',
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
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow Submissions'),
            value: _taskAllowsSubmissions,
            onChanged: (value) {
              setState(() {
                _taskAllowsSubmissions = value;
                if (!value) {
                  _taskRequiresSubmission = false;
                  _taskRequiresApproval = false;
                }
              });
            },
          ),
          if (_taskAllowsSubmissions) ...[
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boardTasks = context.watch<TaskProvider>().tasks.where((task) {
      return task.taskBoardId == widget.task.taskBoardId && !task.taskIsDeleted;
    }).toList();

    final formContent = SingleChildScrollView(
      child: ConstrainedBox(
        constraints: widget.asSheet
            ? const BoxConstraints()
            : const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            if (_boardType == 'team') ...[
              _buildLaneSection(),
              const SizedBox(height: 12),
            ],
            _buildSubmissionOptionsSection(),
            const SizedBox(height: 12),
            _buildDependenciesSection(context),
            const SizedBox(height: 12),
            ...[
              if (_loadingMembers)
                const Center(child: CircularProgressIndicator())
              else if (_boardType == 'team' && _boardMembers.isNotEmpty)
                DropdownButtonFormField<String?>(
                  initialValue: _assignedToUserId,
                  decoration: const InputDecoration(
                    labelText: 'Assigned To',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: [
                    // "None" option for unassigned tasks
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None - Open for petitions'),
                    ),
                    // All board members
                    ..._boardMembers.entries.map((entry) {
                      final active = _activeTasksForMember(
                        boardTasks: boardTasks,
                        memberId: entry.key,
                      );
                      final limit = _taskLimitForMember(entry.key);
                      final atCapacity =
                          entry.key != widget.task.taskOwnerId &&
                          _isAtCapacity(
                            entry.key,
                            boardTasks,
                            includeCurrentTask: false,
                          ) &&
                          entry.key != _assignedToUserId;
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
                    }).toList(),
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
              const SizedBox(height: 12),
            ],
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
            SwitchListTile(
              title: const Text('Repeating Task'),
              value: _isRepeating,
              onChanged: (val) => setState(() => _isRepeating = val),
              contentPadding: EdgeInsets.zero,
            ),
            if (_isRepeating) ...[
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
        icon: const Icon(Icons.save),
        label: const Text('Save'),
      ),
    ];

    if (!widget.asSheet) {
      return AlertDialog(
        title: const Text('Edit Task'),
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
                    const Expanded(
                      child: Text(
                        'Edit Task',
                        style: TextStyle(
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
