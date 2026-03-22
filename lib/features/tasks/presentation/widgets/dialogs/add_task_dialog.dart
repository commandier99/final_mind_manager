import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../datasources/providers/task_provider.dart'; // Import TaskProvider
import '../../../datasources/models/task_model.dart';
import '../../../datasources/models/task_stats_model.dart';
import '../../../datasources/helpers/task_dependency_helper.dart';
import '../../utils/task_assignment_workflow_helper.dart';
import '../../../../boards/datasources/models/board_model.dart';
import '../../../../boards/datasources/providers/board_provider.dart';
import '../../../../../shared/features/users/datasources/services/user_services.dart';
import 'package:uuid/uuid.dart';

class AddTaskDialog extends StatefulWidget {
  final String userId;

  const AddTaskDialog({super.key, required this.userId});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  static const TimeOfDay _defaultDeadlineTime = TimeOfDay(hour: 23, minute: 59);
  // Priority field
  String _priorityLevel = 'Low';
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _deadline;
  TimeOfDay? _deadlineTime;
  Board? _selectedBoard;
  final List<Board> _boards = [];
  // Repeating fields
  bool _isRepeating = false;
  final List<String> _repeatDays = []; // Track selected days
  DateTime? _repeatEndDate;
  TimeOfDay? _repeatTime;
  bool _taskRequiresSubmission = false;
  bool _taskRequiresApproval = false;
  String _currentUserName = 'Unknown'; // Store current user's name
  bool _isLoading = false; // Loading state for task creation
  // Assignment fields
  String? _assignedToUserId;
  String? _assignedToUserName;
  Map<String, String> _boardMembers = {};
  bool _loadingMembers = false;
  final String? _viewerUserId = FirebaseAuth.instance.currentUser?.uid;
  static const String _lanePublished = Task.lanePublished;
  static const String _laneDrafts = Task.laneDrafts;
  final Set<String> _selectedDependencyIds = <String>{};

  static const List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

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

  int _taskLimitForMember(Board board, String memberId) {
    return board.taskLimitForUser(memberId);
  }

  bool _isAtCapacity({
    required Board board,
    required String memberId,
    required List<Task> boardTasks,
  }) {
    final limit = _taskLimitForMember(board, memberId);
    if (limit <= 0) return false;
    final active = _activeTasksForMember(
      boardTasks: boardTasks,
      memberId: memberId,
    );
    return active >= limit;
  }

  String _assigneeOptionLabel(String memberId, String memberName) {
    if (_viewerUserId != null && memberId == _viewerUserId) {
      return '$memberName (You)';
    }
    return memberName;
  }

  @override
  void initState() {
    super.initState();
    _loadBoards();
  }

  Future<void> _loadBoards() async {
    try {
      // Get boards from BoardProvider
      final boardProvider = context.read<BoardProvider>();
      _boards.clear();
      _boards.addAll(
        boardProvider.boards.where(
          (board) =>
              board.boardManagerId == widget.userId ||
              board.memberIds.contains(widget.userId),
        ),
      );

      final defaultBoard = _resolveDefaultBoard(_boards);
      _selectedBoard = defaultBoard;
      if (_selectedBoard?.boardType == 'team') {
        await _loadBoardMembers();
      } else {
        _boardMembers = {};
        _assignedToUserId = null;
        _assignedToUserName = null;
        _taskRequiresSubmission = false;
        _taskRequiresApproval = false;
      }

      // Load current user's name
      final userService = UserService();
      final userData = await userService.getUserById(widget.userId);
      if (userData != null && userData.userName.isNotEmpty) {
        _currentUserName = userData.userName;
      }

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint('Error loading boards: $e');
    }
  }

  Board? _resolveDefaultBoard(List<Board> boards) {
    if (boards.isEmpty) return null;
    for (final board in boards) {
      if (board.boardType.toLowerCase() == 'personal') {
        return board;
      }
    }
    for (final board in boards) {
      final title = board.boardTitle.trim().toLowerCase();
      if (title == 'personal' || title == 'personal hq') {
        return board;
      }
    }
    return boards.first;
  }

  Future<void> _loadBoardMembers() async {
    if (_selectedBoard == null) {
      setState(() {
        _boardMembers = {};
        _assignedToUserId = null;
        _assignedToUserName = null;
      });
      return;
    }

    setState(() => _loadingMembers = true);

    try {
      final members = <String, String>{};

      // Add the task owner (manager) using the real profile name when available.
      final currentUserData = await UserService().getUserById(widget.userId);
      if (currentUserData != null && currentUserData.userName.isNotEmpty) {
        _currentUserName = currentUserData.userName;
        members[widget.userId] = currentUserData.userName;
      } else {
        members[widget.userId] = 'Manager';
      }

      // Add all board members
      for (String memberId in _selectedBoard!.memberIds) {
        if (memberId != widget.userId) {
          // Skip supervisors - they cannot be assigned tasks
          final role = _selectedBoard!.memberRoles[memberId] ?? 'member';
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
        _loadingMembers = false;
        // Reset assignee selection when board changes
        _assignedToUserId = null;
        _assignedToUserName = null;
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
    if (_selectedBoard == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No board found. Your Personal HQ board is required.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

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
      final isRepeating = _deadline != null ? _isRepeating : false;
      final selectedBoard = _selectedBoard!;
      final boardTasks = taskProvider.tasks
          .where(
            (task) =>
                task.taskBoardId == selectedBoard.boardId &&
                !task.taskIsDeleted,
          )
          .toList();

      String taskTitle = _titleController.text.trim();

      // If title is empty, generate default "Task XX" title
      if (taskTitle.isEmpty) {
        taskTitle = _getNextUntitledTaskNumber(taskProvider.tasks);
      }

      // Determine the assigned to name and ID
      final isTeamBoard = selectedBoard.boardType == 'team';
      String assignedToId = isTeamBoard
          ? (_assignedToUserId ?? 'None')
          : widget.userId;
      String assignedToName = isTeamBoard
          ? (_assignedToUserName ?? 'Unassigned')
          : _currentUserName;
      final hasProposedAssignee =
          TaskAssignmentWorkflowHelper.requiresAcceptance(
            boardType: selectedBoard.boardType,
            boardManagerId: selectedBoard.boardManagerId,
            assigneeId: assignedToId,
          );

      if (isTeamBoard &&
          assignedToId != widget.userId &&
          assignedToId != 'None' &&
          _isAtCapacity(
            board: selectedBoard,
            memberId: assignedToId,
            boardTasks: boardTasks,
          )) {
        if (mounted) {
          Navigator.pop(context); // Close loading modal
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This member is already at task capacity.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // If assigned to manager, add "(Manager)" suffix
      if (assignedToId == widget.userId) {
        if (selectedBoard.boardManagerId == widget.userId) {
          assignedToName = '$_currentUserName (Manager)';
        }
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

      // Convert repeat time to HH:mm format
      String? repeatTimeStr;
      if (_repeatTime != null) {
        repeatTimeStr =
            '${_repeatTime!.hour.toString().padLeft(2, '0')}:${_repeatTime!.minute.toString().padLeft(2, '0')}';
      }

      final newTask = Task(
        taskId: const Uuid().v4(),
        taskBoardId: selectedBoard.boardId,
        taskBoardTitle: selectedBoard.boardTitle,
        taskOwnerId: widget.userId,
        taskOwnerName: _currentUserName,
        taskAssignedBy: widget.userId,
        taskAssignedTo: hasProposedAssignee ? 'None' : assignedToId,
        taskAssignedToName: hasProposedAssignee
            ? 'None (Pending)'
            : assignedToName,
        taskCreatedAt: DateTime.now(),
        taskTitle: taskTitle,
        taskDescription: _descriptionController.text.trim(),
        taskDeadline: finalDeadline,
        taskDeadlineMissed: false,
        taskExtensionCount: 0,
        taskIsDone: false,
        taskIsDoneAt: null,
        taskFailed: false,
        taskIsDeleted: false,
        taskDeletedAt: null,
        taskStats: TaskStats(), // Always initialize as empty
        taskPriorityLevel: _priorityLevel,
        taskStatus: Task.statusToDo,
        taskAllowsSubmissions:
            _taskRequiresSubmission || _taskRequiresApproval,
        taskRequiresSubmission: _taskRequiresSubmission,
        taskRequiresApproval: _taskRequiresApproval,
        taskIsRepeating: isRepeating,
        taskRepeatInterval: isRepeating && _repeatDays.isNotEmpty
            ? _repeatDays.join(',')
            : null,
        taskRepeatEndDate: _repeatEndDate,
        taskNextRepeatDate: null,
        taskRepeatTime: isRepeating ? repeatTimeStr : null,
        taskAssignmentStatus: hasProposedAssignee ? 'pending' : null,
        taskProposedAssigneeId: hasProposedAssignee ? assignedToId : null,
        taskProposedAssigneeName: hasProposedAssignee ? assignedToName : null,
        taskBoardLane: selectedBoard.boardType == 'personal'
            ? _lanePublished
            : _laneDrafts,
        taskDependencyIds: TaskDependencyHelper.sanitizeDependencyIds(
          _selectedDependencyIds,
        ),
      );
      final shouldSendAssignmentRequest =
          hasProposedAssignee && newTask.taskBoardLane == _lanePublished;

      await taskProvider.addTask(newTask);
      if (shouldSendAssignmentRequest) {
        await TaskAssignmentWorkflowHelper.createAssignmentRequestIfNeeded(
          context: context,
          task: newTask,
          assigneeId: assignedToId,
          assigneeName: assignedToName,
          actorUserId: widget.userId,
          actorUserName: _currentUserName,
        );
      }

      if (mounted) {
        Navigator.pop(context); // Close loading modal
        Navigator.pop(context); // Close dialog
      }
    } catch (e) {
      debugPrint('Error creating task: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading modal
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating task: $e')));
      }
    }
  }

  List<Task> _dependencyCandidates(TaskProvider taskProvider) {
    final selectedBoard = _selectedBoard;
    if (selectedBoard == null) return const <Task>[];
    final tasks = taskProvider.tasks
        .where(
          (task) =>
              task.taskBoardId == selectedBoard.boardId && !task.taskIsDeleted,
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
    // Repeating is only allowed when a deadline is set
    final canRepeat = _deadline != null;
    final effectiveRepeat = canRepeat ? _isRepeating : false;
    final taskProvider = context.watch<TaskProvider>();
    final selectedBoard = _selectedBoard;
    final boardTasks = selectedBoard == null
        ? const <Task>[]
        : taskProvider.tasks
              .where(
                (task) =>
                    task.taskBoardId == selectedBoard.boardId &&
                    !task.taskIsDeleted,
              )
              .toList();

    final formContent = SingleChildScrollView(
      child: Column(
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
            onChanged: (_) => setState(() {}),
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
            onChanged: (_) => setState(() {}),
          ),
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
          _buildPrioritySelector(),
          const SizedBox(height: 12),
          DropdownButtonFormField<Board>(
            initialValue: _selectedBoard,
            items: _boards
                .map(
                  (board) => DropdownMenuItem<Board>(
                    value: board,
                    child: Text(
                      board.boardTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _boards.isEmpty
                ? null
                : (board) async {
                    if (board == null) return;
                    setState(() {
                      _selectedBoard = board;
                      _selectedDependencyIds.clear();
                    });
                    if (board.boardType == 'team') {
                      await _loadBoardMembers();
                      return;
                    }
                    setState(() {
                      _boardMembers = {};
                      _assignedToUserId = null;
                      _assignedToUserName = null;
                      _taskRequiresSubmission = false;
                      _taskRequiresApproval = false;
                    });
                  },
            decoration: const InputDecoration(
              labelText: 'Select Board',
              hintText: 'Required',
            ),
          ),
          if (_boards.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'No available boards found.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          const SizedBox(height: 12),
          // Assignment dropdown (Team boards only)
          if (_selectedBoard?.boardType == 'team') ...[
            if (_loadingMembers)
              const Center(child: CircularProgressIndicator())
            else if (_boardMembers.isNotEmpty)
              DropdownButtonFormField<String?>(
                initialValue: _assignedToUserId,
                decoration: const InputDecoration(
                  labelText: 'Assign To',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                items: [
                  // "None" option for unassigned tasks
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('None'),
                  ),
                  // All board members
                  ..._boardMembers.entries.map((entry) {
                    final selectedBoard = _selectedBoard;
                    final active = _activeTasksForMember(
                      boardTasks: boardTasks,
                      memberId: entry.key,
                    );
                    final limit = selectedBoard == null
                        ? 0
                        : _taskLimitForMember(selectedBoard, entry.key);
                    final atCapacity =
                        selectedBoard != null &&
                        entry.key != widget.userId &&
                        _isAtCapacity(
                          board: selectedBoard,
                          memberId: entry.key,
                          boardTasks: boardTasks,
                        );
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
            const SizedBox(height: 8),
          ],
          _buildDependenciesSection(context),
          const SizedBox(height: 12),
          _buildSubmissionOptionsSection(),
          if (canRepeat) ...[
            SwitchListTile(
              title: const Text('Repeating Task'),
              value: effectiveRepeat,
              onChanged: (val) => setState(() => _isRepeating = val),
              contentPadding: EdgeInsets.zero,
            ),
            if (effectiveRepeat) ...[
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
        ],
      ),
    );

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
                        'Add Task',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
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
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Task'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
