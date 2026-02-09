import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '/features/tasks/datasources/models/task_model.dart';
import '/features/tasks/datasources/models/task_stats_model.dart';
import '/features/tasks/datasources/providers/task_provider.dart';
import '/features/boards/datasources/models/board_model.dart';
import '/shared/features/users/datasources/services/user_services.dart';

class AddTaskToSessionDialog extends StatefulWidget {
  final String userId;
  final Board board;
  final ValueChanged<String>? onTaskCreated;

  const AddTaskToSessionDialog({
    super.key,
    required this.userId,
    required this.board,
    this.onTaskCreated,
  });

  @override
  State<AddTaskToSessionDialog> createState() => _AddTaskToSessionDialogState();
}

class _AddTaskToSessionDialogState extends State<AddTaskToSessionDialog> {
  String _priorityLevel = 'Low';
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _deadline;
  TimeOfDay? _deadlineTime;
  bool _isRepeating = false;
  final List<String> _repeatDays = [];
  DateTime? _repeatEndDate;
  TimeOfDay? _repeatTime;
  String _currentUserName = 'Unknown';
  bool _isLoading = false;

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
    _loadCurrentUserName();
  }

  Future<void> _loadCurrentUserName() async {
    try {
      final userData = await UserService().getUserById(widget.userId);
      if (userData != null && userData.userName.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _currentUserName = userData.userName;
        });
      }
    } catch (_) {
      // Keep default name on failure.
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

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

      String taskTitle = _titleController.text.trim();
      if (taskTitle.isEmpty) {
        taskTitle = _getNextUntitledTaskNumber(taskProvider.tasks);
      }

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

      String? repeatTimeStr;
      if (_repeatTime != null) {
        repeatTimeStr =
            '${_repeatTime!.hour.toString().padLeft(2, '0')}:${_repeatTime!.minute.toString().padLeft(2, '0')}';
      }

      final newTask = Task(
        taskId: const Uuid().v4(),
        taskBoardId: widget.board.boardId,
        taskBoardTitle: widget.board.boardTitle,
        taskOwnerId: widget.userId,
        taskOwnerName: _currentUserName,
        taskAssignedBy: widget.userId,
        taskAssignedTo: widget.userId,
        taskAssignedToName: _currentUserName,
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
        taskRequiresApproval: false,
        taskIsRepeating: _isRepeating,
        taskRepeatInterval: _repeatDays.isNotEmpty ? _repeatDays.join(',') : null,
        taskRepeatEndDate: _repeatEndDate,
        taskNextRepeatDate: null,
        taskRepeatTime: repeatTimeStr,
      );

      await taskProvider.addTask(newTask);
      widget.onTaskCreated?.call(newTask.taskId);

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Task "${newTask.taskTitle}" added to ${widget.board.boardTitle}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating task: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Task to Session'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 650),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
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
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: DropdownButtonFormField<String>(
                  initialValue: _priorityLevel,
                  decoration: const InputDecoration(
                    labelText: 'Priority Level',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Low', child: Text('Low')),
                    DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'High', child: Text('High')),
                  ],
                  onChanged: (val) =>
                      setState(() => _priorityLevel = val ?? 'Low'),
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
                                    _repeatDays.sort(
                                      (a, b) => _daysOfWeek.indexOf(a) -
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
          onPressed: _isLoading ? null : _submit,
          icon: const Icon(Icons.add),
          label: const Text('Add Task'),
        ),
      ],
    );
  }
}
