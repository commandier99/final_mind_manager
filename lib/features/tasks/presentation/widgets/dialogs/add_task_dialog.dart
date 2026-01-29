import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/providers/task_provider.dart'; // Import TaskProvider
import '../../../datasources/models/task_model.dart';
import '../../../datasources/models/task_stats_model.dart';
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
  String _currentUserName = 'Unknown'; // Store current user's name
  bool _isLoading = false; // Loading state for task creation
  // Assignment fields
  String? _assignedToUserId;
  String? _assignedToUserName;
  Map<String, String> _boardMembers = {};
  bool _loadingMembers = false;
  
  static const List<String> _daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

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
      _boards.addAll(boardProvider.boards.where((board) => 
        board.boardManagerId == widget.userId || 
        board.memberIds.contains(widget.userId)
      ));
      
      // Load current user's name
      final userService = UserService();
      final userData = await userService.getUserById(widget.userId);
      if (userData != null && userData.userName.isNotEmpty) {
        _currentUserName = userData.userName;
      }
      
      setState(() {});
    } catch (e) {
      print('Error loading boards: $e');
    }
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

      // Add the task owner (manager)
      members[widget.userId] = 'Manager';

      // Add all board members
      for (String memberId in _selectedBoard!.memberIds) {
        if (memberId != widget.userId) {
          // Skip inspectors - they cannot be assigned tasks
          final role = _selectedBoard!.memberRoles[memberId] ?? 'member';
          if (role == 'inspector') continue;

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
      
      String taskTitle = _titleController.text.trim();
      
      // If title is empty, generate default "Task XX" title
      if (taskTitle.isEmpty) {
        taskTitle = _getNextUntitledTaskNumber(taskProvider.tasks);
      }

      // Determine the assigned to name and ID
      String assignedToId = _assignedToUserId ?? widget.userId;
      String assignedToName = _assignedToUserName ?? _currentUserName;
      
      // If assigned to manager, add "(Manager)" suffix
      if (assignedToId == widget.userId) {
        if (_selectedBoard != null && _selectedBoard!.boardManagerId == widget.userId) {
          assignedToName = '$_currentUserName (Manager)';
        }
      }

      // Merge deadline date with time
      DateTime? finalDeadline = _deadline;
      if (finalDeadline != null && _deadlineTime != null) {
        finalDeadline = DateTime(
          finalDeadline.year,
          finalDeadline.month,
          finalDeadline.day,
          _deadlineTime!.hour,
          _deadlineTime!.minute,
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
        taskBoardId: _selectedBoard?.boardId ?? '',
        taskBoardTitle: _selectedBoard?.boardTitle,
        taskOwnerId: widget.userId,
        taskOwnerName: _currentUserName,
        taskAssignedBy: widget.userId,
        taskAssignedTo: assignedToId,
        taskAssignedToName: assignedToName,
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
        taskStatus: 'TODO',
        taskRequiresApproval: false,
        taskIsRepeating: isRepeating,
        taskRepeatInterval: isRepeating && _repeatDays.isNotEmpty ? _repeatDays.join(',') : null,
        taskRepeatEndDate: _repeatEndDate,
        taskNextRepeatDate: null,
        taskRepeatTime: isRepeating ? repeatTimeStr : null,
      );

      await taskProvider.addTask(newTask);

      if (mounted) {
        Navigator.pop(context); // Close loading modal
        Navigator.pop(context); // Close dialog
      }
    } catch (e) {
      print('Error creating task: $e');
      if (mounted) {
        Navigator.pop(context); // Close loading modal
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating task: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Repeating is only allowed when a deadline is set
    final canRepeat = _deadline != null;
    final effectiveRepeat = canRepeat ? _isRepeating : false;

    return AlertDialog(
      title: const Text('Add New Task'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 650),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: const OutlineInputBorder(),
                  counterText: '${_titleController.text.length}/50',
                ),
                maxLength: 50,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: const OutlineInputBorder(),
                  counterText: '${_descriptionController.text.length}/500',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _deadline ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _deadline = picked);
                        }
                      },
                      child: Text(
                        _deadline == null
                            ? 'Deadline: None'
                            : 'Deadline: ${_deadline!.toLocal().toString().split(' ')[0]}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
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
                    child: Text(
                      _deadlineTime == null
                          ? 'Time'
                          : _deadlineTime!.format(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _priorityLevel,
                items: const [
                  DropdownMenuItem(value: 'Low', child: Text('Low')),
                  DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'High', child: Text('High')),
                ],
                onChanged:
                    (val) => setState(() => _priorityLevel = val ?? 'Low'),
                decoration: const InputDecoration(labelText: 'Priority Level'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Board>(
                initialValue: _selectedBoard,
                items:
                    _boards.isEmpty
                        ? [
                          const DropdownMenuItem<Board>(
                            value: null,
                            child: Text("No boards available"),
                          ),
                        ]
                        : [
                          const DropdownMenuItem<Board>(
                            value: null,
                            child: Text("No board (Personal)"),
                          ),
                          ..._boards
                              .map(
                                (board) => DropdownMenuItem<Board>(
                                  value: board,
                                  child: Text(
                                    board.boardTitle,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              ,
                        ],
                onChanged:
                    _boards.isEmpty
                        ? null
                        : (board) {
                          setState(() => _selectedBoard = board);
                          if (board != null) {
                            _loadBoardMembers();
                          } else {
                            setState(() {
                              _boardMembers = {};
                              _assignedToUserId = null;
                              _assignedToUserName = null;
                            });
                          }
                        },
                decoration: const InputDecoration(
                  labelText: 'Select Board',
                  hintText: 'Optional',
                ),
              ),
              const SizedBox(height: 8),
              // Assignment dropdown
              if (_selectedBoard != null) ...[
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
                        child: Text('None - Open for petitions'),
                      ),
                      // All board members
                      ..._boardMembers.entries.map((entry) {
                        return DropdownMenuItem<String?>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _assignedToUserId = val;
                        _assignedToUserName = val != null ? _boardMembers[val] : null;
                      });
                    },
                  ),
                const SizedBox(height: 8),
              ],
              if (canRepeat) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Repeating Task'),
                    const Spacer(),
                    Switch(
                      value: effectiveRepeat,
                      onChanged: (val) => setState(() => _isRepeating = val),
                    ),
                  ],
                ),
                if (effectiveRepeat) ...[
                  const SizedBox(height: 8),
                  const Text('Repeat on days:',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _daysOfWeek
                          .map((day) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(day.substring(0, 3)),
                                  selected: _repeatDays.contains(day),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _repeatDays.add(day);
                                        // Sort days by week order
                                        _repeatDays.sort((a, b) =>
                                            _daysOfWeek.indexOf(a) -
                                            _daysOfWeek.indexOf(b));
                                      } else {
                                        _repeatDays.remove(day);
                                      }
                                    });
                                  },
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
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
                          child: Text(
                            _repeatEndDate == null
                                ? 'Pick Repeat End Date'
                                : 'Repeat End: ${_repeatEndDate!.toLocal().toString().split(' ')[0]}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _repeatTime ?? TimeOfDay.now(),
                          );
                          if (picked != null) {
                            setState(() => _repeatTime = picked);
                          }
                        },
                        child: Text(
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
