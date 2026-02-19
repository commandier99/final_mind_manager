import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/models/task_model.dart';
import '../../../datasources/providers/task_provider.dart';
import '../../../../boards/datasources/services/board_services.dart';
import '../../../../../shared/features/users/datasources/services/user_services.dart';
import '../../../../notifications/datasources/helpers/notification_helper.dart';

class EditTaskDialog extends StatefulWidget {
  final Task task;
  const EditTaskDialog({super.key, required this.task});

  @override
  State<EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<EditTaskDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _priorityLevel;
  late DateTime? _deadline;
  late TimeOfDay? _deadlineTime;
  late bool _isRepeating;
  late List<String> _repeatDays;
  late DateTime? _repeatEndDate;
  late TimeOfDay? _repeatTime;
  String? _assignedToUserId;
  String? _assignedToUserName;
  Map<String, String> _boardMembers = {};
  bool _loadingMembers = true;

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
    // Handle "None" or empty assignedTo values
    if (widget.task.taskAssignedTo.isEmpty || widget.task.taskAssignedTo == 'None') {
      _assignedToUserId = null;
      _assignedToUserName = null;
    } else {
      _assignedToUserId = widget.task.taskAssignedTo;
      _assignedToUserName = widget.task.taskAssignedToName;
    }
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
          // Skip inspectors - they cannot be assigned tasks
          final role = board.memberRoles[memberId] ?? 'member';
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

      // Track what changed
      final bool titleChanged =
          _titleController.text.trim() != widget.task.taskTitle;
      final bool descriptionChanged =
          _descriptionController.text.trim() != widget.task.taskDescription;
      final bool priorityChanged =
          _priorityLevel != widget.task.taskPriorityLevel;
      final bool deadlineChanged = _deadline != widget.task.taskDeadline;
      final bool assigneeChanged =
          _assignedToUserId != widget.task.taskAssignedTo;

      final bool hasChanges =
          titleChanged ||
          descriptionChanged ||
          priorityChanged ||
          deadlineChanged ||
          assigneeChanged;
      final updatedTask = widget.task.copyWith(
        taskTitle: _titleController.text.trim(),
        taskDescription: _descriptionController.text.trim(),
        taskPriorityLevel: _priorityLevel,
        taskDeadline:
            _deadline != null && _deadlineTime != null
                ? DateTime(
                  _deadline!.year,
                  _deadline!.month,
                  _deadline!.day,
                  _deadlineTime!.hour,
                  _deadlineTime!.minute,
                )
                : _deadline,
        taskIsRepeating: _isRepeating,
        taskRepeatInterval:
            _repeatDays.isNotEmpty ? _repeatDays.join(',') : null,
        taskRepeatEndDate: _repeatEndDate,
        taskRepeatTime:
            _repeatTime != null
                ? '${_repeatTime!.hour.toString().padLeft(2, '0')}:${_repeatTime!.minute.toString().padLeft(2, '0')}'
                : null,
        // Convert null to "None" for unassigned tasks
        taskAssignedTo: _assignedToUserId ?? 'None',
        taskAssignedToName: _assignedToUserName ?? 'Unassigned',
        // Reset acceptance status to 'pending' if task is reassigned to a different person
        taskAcceptanceStatus:
            assigneeChanged
                ? (_assignedToUserId != null && _assignedToUserId != widget.task.taskOwnerId
                    ? 'pending'
                    : null)
                : widget.task.taskAcceptanceStatus,
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
            message: 'You have been assigned to "${updatedTask.taskTitle}"$deadlineInfo',
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
          print('[TaskNotification] ✅ Task reassignment notification sent to: $_assignedToUserId');
        } catch (e) {
          print('[TaskNotification] ⚠️ Failed to send reassignment notification: $e');
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Task'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
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
              DropdownButtonFormField<String>(
                initialValue: _priorityLevel,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Low', child: Text('Low')),
                  DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'High', child: Text('High')),
                ],
                onChanged:
                    (val) => setState(() => _priorityLevel = val ?? 'Medium'),
              ),
              const SizedBox(height: 12),
              ...[
                if (_loadingMembers)
                  const Center(child: CircularProgressIndicator())
                else if (_boardMembers.isNotEmpty)
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
                        if (picked != null) setState(() => _deadline = picked);
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
                    onPressed:
                        _deadline == null
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
                    children:
                        _daysOfWeek
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
      ],
    );
  }
}
