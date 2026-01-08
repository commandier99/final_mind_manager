import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/shared/features/users/datasources/providers/user_provider.dart';
import '../../datasources/providers/plan_provider.dart';
import '../../datasources/models/plans_model.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../../tasks/datasources/models/task_model.dart';

class CreatePlanPage extends StatefulWidget {
  final String initialTechnique;

  const CreatePlanPage({super.key, this.initialTechnique = 'custom'});

  @override
  State<CreatePlanPage> createState() => _CreatePlanPageState();
}

class _CreatePlanPageState extends State<CreatePlanPage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  late String _selectedTechnique;
  DateTime? _scheduledDate;
  bool _isSaving = false;
  bool _autoSuggest = false;
  final Set<String> _selectedTaskIds = {};

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
    _selectedTechnique = widget.initialTechnique;
    _titleController.addListener(_triggerRefresh);
    _descriptionController.addListener(_triggerRefresh);
  }

  @override
  void dispose() {
    _titleController.removeListener(_triggerRefresh);
    _descriptionController.removeListener(_triggerRefresh);
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
                value: _selectedTechnique,
                decoration: InputDecoration(
                  labelText: 'Technique',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'custom',
                    child: Text('Custom'),
                  ),
                  DropdownMenuItem(
                    value: 'pomodoro',
                    child: Text('Pomodoro'),
                  ),
                  DropdownMenuItem(
                    value: 'eat_the_frog',
                    child: Text('Eat the Frog'),
                  ),
                  DropdownMenuItem(
                    value: 'timeblocking',
                    child: Text('Time Blocking'),
                  ),
                  DropdownMenuItem(
                    value: 'gtd',
                    child: Text('GTD (Getting Things Done)'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedTechnique = value ?? 'custom';
                  });
                },
              ),
              const SizedBox(height: 16),
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
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Let the system suggest tasks'),
                subtitle: const Text('Uses your title/description to auto-pick tasks'),
                value: _autoSuggest,
                onChanged: (value) {
                  setState(() {
                    _autoSuggest = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              Consumer<TaskProvider>(
                builder: (context, taskProvider, _) {
                  final tasks = taskProvider.tasks;
                  if (taskProvider.isLoading && tasks.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (tasks.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No tasks available to add yet.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    );
                  }

                  final suggested = _getSuggestedTasks(tasks);
                  final suggestedIds = suggested.map((t) => t.taskId).toSet();

                  final visibleList = _autoSuggest
                      ? ([...tasks]
                        ..sort((a, b) {
                          final aSuggested = suggestedIds.contains(a.taskId) ? 1 : 0;
                          final bSuggested = suggestedIds.contains(b.taskId) ? 1 : 0;
                          if (aSuggested != bSuggested) return bSuggested - aSuggested;
                          return a.taskTitle.compareTo(b.taskTitle);
                        }))
                      : tasks;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _autoSuggest
                            ? 'Suggested tasks for this plan'
                            : 'Select tasks to include',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: visibleList.length,
                        itemBuilder: (context, index) {
                          final task = visibleList[index];
                          final isSuggested = suggestedIds.contains(task.taskId);
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
                                  'Board: $boardLabel',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  task.taskDescription.isEmpty
                                      ? 'No description'
                                      : task.taskDescription,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            secondary: isSuggested
                                ? Chip(
                                    label: const Text('Suggested'),
                                    visualDensity: VisualDensity.compact,
                                  )
                                : null,
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
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save Plan'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _triggerRefresh() {
    if (mounted) {
      setState(() {});
    }
  }

  List<Task> _getSuggestedTasks(List<Task> tasks) {
    final query = '${_titleController.text} ${_descriptionController.text}'.toLowerCase();
    if (query.trim().isEmpty) {
      return tasks.take(5).toList();
    }

    int score(Task task) {
      int s = 0;
      final title = task.taskTitle.toLowerCase();
      final desc = task.taskDescription.toLowerCase();
      for (final word in query.split(RegExp(r'\s+')).where((w) => w.length > 2)) {
        if (title.contains(word)) s += 3;
        if (desc.contains(word)) s += 2;
      }
      if (task.taskDeadline != null) {
        final days = task.taskDeadline!.difference(DateTime.now()).inDays;
        if (days <= 0) s += 4;
        else if (days <= 3) s += 3;
        else if (days <= 7) s += 2;
      }
      if (!task.taskIsDone) s += 1;
      return s;
    }

    final sorted = [...tasks]..sort((a, b) => score(b).compareTo(score(a)));
    return sorted.take(5).toList();
  }

  List<String> _collectTaskIds(BuildContext context) {
    if (_autoSuggest) {
      final tasks = context.read<TaskProvider>().tasks;
      return _getSuggestedTasks(tasks).map((t) => t.taskId).toList();
    }
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
          technique: _selectedTechnique,
          scheduledFor: _scheduledDate,
          taskIds: _collectTaskIds(context),
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
