import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/shared/features/users/datasources/providers/user_provider.dart';
import '../../datasources/providers/plan_provider.dart';
import '../../datasources/models/plans_model.dart';
import '../../../tasks/datasources/providers/task_provider.dart';

class CreatePlanPage extends StatefulWidget {
  final String initialTechnique;

  const CreatePlanPage({super.key, this.initialTechnique = 'quick_todo'});

  @override
  State<CreatePlanPage> createState() => _CreatePlanPageState();
}

class _CreatePlanPageState extends State<CreatePlanPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late String _selectedStyle;
  DateTime? _scheduledDate;
  bool _isSaving = false;
  final Set<String> _selectedTaskIds = {};
  late Set<String> _selectedFilters;
  
  // Define available task statuses for filtering
  static const List<String> taskStatuses = [
    'TODO',
    'IN_PROGRESS',
    'IN_REVIEW',
    'ON_PAUSE',
    'UNDER_REVISION',
  ];
  
  static const Map<String, String> statusLabels = {
    'TODO': 'TO DO',
    'IN_PROGRESS': 'IN PROGRESS',
    'IN_REVIEW': 'IN REVIEW',
    'ON_PAUSE': 'ON PAUSE',
    'UNDER_REVISION': 'UNDER REVISION',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<UserProvider>().userId;
    if (userId != null) {
      context.read<TaskProvider>().streamUserActiveTasks(userId);
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedStyle = widget.initialTechnique;
    _selectedFilters = Set.from(taskStatuses); // Show all by default
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Plan'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Plan Title',
                  hintText: 'e.g., Monday Study Session',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'What is this plan for?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedStyle,
                decoration: InputDecoration(
                  labelText: 'Technique',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'quick_todo',
                    child: Text('Quick To-Do'),
                  ),
                  DropdownMenuItem(
                    value: 'pomodoro',
                    child: Text('Pomodoro'),
                  ),
                  DropdownMenuItem(
                    value: 'eat_the_frog',
                    child: Text('Eat the Frog'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStyle = value ?? 'quick_todo';
                  });
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _scheduledDate == null
                          ? 'No date scheduled'
                          : 'Scheduled: ${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text('Schedule Date'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Select tasks to include',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Consumer<TaskProvider>(
                builder: (context, taskProvider, _) {
                  final tasks = taskProvider.tasks;
                  
                  if (taskProvider.isLoading && tasks.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Filter tasks by status
                  final filteredTasks = tasks.where((task) => 
                    _selectedFilters.contains(task.taskStatus) && !task.taskIsDone
                  ).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: taskStatuses.map((status) {
                            final isSelected = _selectedFilters.contains(status);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(
                                  statusLabels[status] ?? status,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedFilters.add(status);
                                    } else {
                                      _selectedFilters.remove(status);
                                    }
                                  });
                                },
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Task list
                      if (filteredTasks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No Tasks',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredTasks.length,
                          itemBuilder: (context, index) {
                            final task = filteredTasks[index];
                            final isSelected = _selectedTaskIds.contains(task.taskId);
                            final boardLabel = (task.taskBoardTitle ?? '').isNotEmpty
                                ? task.taskBoardTitle!
                                : 'No board';

                            return CheckboxListTile(
                              value: isSelected,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(task.taskTitle),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    boardLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    task.taskStatus.replaceAll('_', ' '),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedTaskIds.add(task.taskId);
                                  } else {
                                    _selectedTaskIds.remove(task.taskId);
                                  }
                                });
                              },
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _savePlan,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isSaving ? 'Saving...' : 'Create Plan'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _collectTaskIds() {
    return _selectedTaskIds.toList();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _scheduledDate = date;
      });
    }
  }

  Future<void> _savePlan() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a plan title')),
      );
      return;
    }

    final userProvider = context.read<UserProvider>();
    final userId = userProvider.userId;
    final userName = userProvider.currentUser?.userName ?? 'User';

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found. Please sign in again.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final plan = await context.read<PlanProvider>().createPlan(
          userId: userId,
          userName: userName,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          style: _selectedStyle,
          scheduledFor: _scheduledDate,
          taskIds: _collectTaskIds(),
        );

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (plan != null) {
      Navigator.pop<Plan>(context, plan);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create plan. Please try again.')),
      );
    }
  }
}
