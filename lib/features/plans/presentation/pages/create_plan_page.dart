import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/shared/features/users/datasources/providers/user_provider.dart';
import '../../datasources/providers/plan_provider.dart';
import '../../datasources/models/plans_model.dart';
import '../../../tasks/datasources/providers/task_provider.dart';

class CreatePlanPage extends StatefulWidget {
  const CreatePlanPage({super.key});

  @override
  State<CreatePlanPage> createState() => _CreatePlanPageState();
}

class _CreatePlanPageState extends State<CreatePlanPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _benefitController = TextEditingController();
  DateTime? _scheduledDate;
  bool _isSaving = false;
  final Set<String> _selectedTaskIds = {};
  late Set<String> _selectedFilters;
  String? _lastStreamedUserId;
  String _sortBy = 'created_desc';
  
  // Special filter
  static const String allFilter = 'All';
  
  // Define available task statuses for filtering
  static const List<String> taskStatuses = [
    'To Do',
    'In Progress',
    'Paused',
    'COMPLETED',
  ];
  
  // Deadline filter options
  static const List<String> deadlineFilters = [
    'Overdue',
    'Today',
    'Upcoming',
    'None',
  ];
  
  static final List<String> allFilters = [
    allFilter,
    ...taskStatuses,
    ...deadlineFilters,
  ];
  
  static const Map<String, String> statusLabels = {
    'To Do': 'To Do',
    'In Progress': 'In Progress',
    'Paused': 'Paused',
    'COMPLETED': 'Completed',
  };
  
  static const Map<String, String> deadlineLabels = {
    'Overdue': 'Overdue',
    'Today': 'Today',
    'Upcoming': 'Upcoming',
    'None': 'None',
  };

  @override
  void initState() {
    super.initState();
    _selectedFilters = {allFilter}; // Show all by default
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<UserProvider>().userId;
    if (userId != null && _lastStreamedUserId != userId) {
      _lastStreamedUserId = userId;
      context.read<TaskProvider>().streamUserActiveTasks(userId);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _benefitController.dispose();
    super.dispose();
  }
  
  bool _matchesDeadlineFilter(dynamic task, String filter) {
    switch (filter) {
      case 'Overdue':
        if (task.taskDeadline == null) return false;
        final now = DateTime.now();
        return task.taskDeadline!.isBefore(now) && !task.taskIsDone;
      case 'Today':
        if (task.taskDeadline == null) return false;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final deadlineDate = DateTime(
          task.taskDeadline!.year,
          task.taskDeadline!.month,
          task.taskDeadline!.day,
        );
        return deadlineDate == today;
      case 'Upcoming':
        if (task.taskDeadline == null) return false;
        final now = DateTime.now();
        return task.taskDeadline!.isAfter(now);
      case 'None':
        return task.taskDeadline == null;
      default:
        return true;
    }
  }
  
  String _getFilterLabel(String filter) {
    return statusLabels[filter] ?? deadlineLabels[filter] ?? filter;
  }
  
  int _priorityToInt(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }
  
  List<dynamic> _applySorting(List<dynamic> tasks) {
    final sortedTasks = List.from(tasks);
    
    switch (_sortBy) {
      case 'priority_asc':
        sortedTasks.sort((a, b) => _priorityToInt(a.taskPriorityLevel ?? 'low')
            .compareTo(_priorityToInt(b.taskPriorityLevel ?? 'low')));
        break;
      case 'priority_desc':
        sortedTasks.sort((a, b) => _priorityToInt(b.taskPriorityLevel ?? 'low')
            .compareTo(_priorityToInt(a.taskPriorityLevel ?? 'low')));
        break;
      case 'alphabetical_asc':
        sortedTasks.sort((a, b) => a.taskTitle.compareTo(b.taskTitle));
        break;
      case 'alphabetical_desc':
        sortedTasks.sort((a, b) => b.taskTitle.compareTo(a.taskTitle));
        break;
      case 'created_asc':
        sortedTasks.sort((a, b) => a.taskCreatedAt.compareTo(b.taskCreatedAt));
        break;
      case 'created_desc':
        sortedTasks.sort((a, b) => b.taskCreatedAt.compareTo(a.taskCreatedAt));
        break;
      case 'deadline_asc':
        sortedTasks.sort((a, b) {
          if (a.taskDeadline == null && b.taskDeadline == null) return 0;
          if (a.taskDeadline == null) return 1;
          if (b.taskDeadline == null) return -1;
          return a.taskDeadline!.compareTo(b.taskDeadline!);
        });
        break;
      case 'deadline_desc':
        sortedTasks.sort((a, b) {
          if (a.taskDeadline == null && b.taskDeadline == null) return 0;
          if (a.taskDeadline == null) return 1;
          if (b.taskDeadline == null) return -1;
          return b.taskDeadline!.compareTo(a.taskDeadline!);
        });
        break;
      default:
        break;
    }
    
    return sortedTasks;
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
                  hintText: 'e.g., Monday study session for Algebra II',
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
                  hintText: 'What will you focus on?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _benefitController,
                decoration: InputDecoration(
                  labelText: 'Benefit',
                  hintText: 'Why is this important?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_scheduledDate != null)
                    Expanded(
                      child: Text(
                        'Scheduled: ${_scheduledDate!.day}/${_scheduledDate!.month}/${_scheduledDate!.year}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_scheduledDate == null ? 'Schedule Date' : 'Change Date'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Consumer<TaskProvider>(
                builder: (context, taskProvider, _) {
                  final tasks = taskProvider.tasks;
                  
                  if (taskProvider.isLoading && tasks.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Filter tasks
                  List<dynamic> filteredTasks;
                  if (_selectedFilters.contains(allFilter)) {
                    filteredTasks = tasks.where((task) => !task.taskIsDone).toList();
                  } else {
                    final selectedStatuses = _selectedFilters
                        .where((f) => taskStatuses.contains(f))
                        .toSet();
                    final selectedDeadlineFilters = _selectedFilters
                        .where((f) => deadlineFilters.contains(f))
                        .toSet();

                    filteredTasks = tasks.where((task) {
                      if (task.taskIsDone) return false;
                      
                      if (selectedStatuses.isEmpty) {
                        return false;
                      }

                      final statusMatch = selectedStatuses.contains(task.taskStatus);

                      if (selectedDeadlineFilters.isEmpty) {
                        return statusMatch;
                      }

                      final deadlineMatch = selectedDeadlineFilters.any((filter) {
                        return _matchesDeadlineFilter(task, filter);
                      });

                      return statusMatch && deadlineMatch;
                    }).toList();
                  }
                  
                  // Apply sorting
                  final sortedTasks = _applySorting(filteredTasks);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with sort and filter buttons
                      Row(
                        children: [
                          const Text(
                            'Select tasks to include',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: Colors.grey[300],
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Sort Button
                          PopupMenuButton<String>(
                            tooltip: 'Sort tasks',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.sort, size: 16, color: Colors.grey[700]),
                            ),
                            onSelected: (value) {
                              setState(() {
                                _sortBy = value;
                              });
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                enabled: false,
                                child: Text(
                                  'Priority',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'priority_asc',
                                child: Text(
                                  'Low → High',
                                  style: TextStyle(
                                    color: _sortBy == 'priority_asc' ? Colors.blue : null,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'priority_desc',
                                child: Text(
                                  'High → Low',
                                  style: TextStyle(
                                    color: _sortBy == 'priority_desc' ? Colors.blue : null,
                                  ),
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                enabled: false,
                                child: Text(
                                  'Alphabetical',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'alphabetical_asc',
                                child: Text(
                                  'A → Z',
                                  style: TextStyle(
                                    color: _sortBy == 'alphabetical_asc' ? Colors.blue : null,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'alphabetical_desc',
                                child: Text(
                                  'Z → A',
                                  style: TextStyle(
                                    color: _sortBy == 'alphabetical_desc' ? Colors.blue : null,
                                  ),
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                enabled: false,
                                child: Text(
                                  'Created Date',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'created_asc',
                                child: Text(
                                  'Oldest',
                                  style: TextStyle(
                                    color: _sortBy == 'created_asc' ? Colors.blue : null,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'created_desc',
                                child: Text(
                                  'Newest',
                                  style: TextStyle(
                                    color: _sortBy == 'created_desc' ? Colors.blue : null,
                                  ),
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                enabled: false,
                                child: Text(
                                  'Deadline',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'deadline_asc',
                                child: Text(
                                  'Soonest',
                                  style: TextStyle(
                                    color: _sortBy == 'deadline_asc' ? Colors.blue : null,
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'deadline_desc',
                                child: Text(
                                  'Latest',
                                  style: TextStyle(
                                    color: _sortBy == 'deadline_desc' ? Colors.blue : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            tooltip: 'Add filters',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.filter_list, size: 16, color: Colors.grey[700]),
                            ),
                            onSelected: (filter) {
                              setState(() {
                                if (filter == allFilter) {
                                  _selectedFilters = {allFilter};
                                } else {
                                  _selectedFilters.remove(allFilter);
                                  _selectedFilters.add(filter);
                                  
                                  if (_selectedFilters.isEmpty) {
                                    _selectedFilters.add(filter);
                                  }
                                }
                              });
                            },
                            itemBuilder: (context) {
                              return allFilters
                                  .where((f) => !_selectedFilters.contains(f))
                                  .map((filter) {
                                final label = _getFilterLabel(filter);
                                return PopupMenuItem<String>(
                                  value: filter,
                                  child: Text(label, style: const TextStyle(fontSize: 12)),
                                );
                              }).toList();
                            },
                          ),
                        ],
                      ),
                      // Active filters as chips
                      if (_selectedFilters.isNotEmpty)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...(_selectedFilters.toList()..sort()).map((filter) {
                                final label = _getFilterLabel(filter);
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8, top: 8),
                                  child: InputChip(
                                    label: Text(
                                      label,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onDeleted: () {
                                      setState(() {
                                        _selectedFilters.remove(filter);
                                        if (_selectedFilters.isEmpty) {
                                          _selectedFilters.add(allFilter);
                                        }
                                      });
                                    },
                                    backgroundColor: Colors.grey[400],
                                    deleteIconColor: Colors.white,
                                    side: BorderSide.none,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      
                      // Task list
                      if (sortedTasks.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No tasks available. Create tasks first, then select at least one to make a plan.',
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
                          itemCount: sortedTasks.length,
                          itemBuilder: (context, index) {
                            final task = sortedTasks[index];
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
                  onPressed: _isSaving || _selectedTaskIds.isEmpty
                      ? null
                      : _savePlan,
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
    if (_selectedTaskIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one task for the plan.')),
      );
      return;
    }

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
          benefit: _benefitController.text.trim(),
          style: 'Checklist',
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
