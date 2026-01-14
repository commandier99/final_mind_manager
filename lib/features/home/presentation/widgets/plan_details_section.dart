import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../plans/datasources/providers/plan_provider.dart';
import '../../../plans/datasources/models/plans_model.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../../tasks/datasources/models/task_model.dart';

class PlanDetailsSection extends StatefulWidget {
  final Plan plan;

  const PlanDetailsSection({super.key, required this.plan});

  @override
  State<PlanDetailsSection> createState() => _PlanDetailsSectionState();
}

class _PlanDetailsSectionState extends State<PlanDetailsSection> {
  late Plan _currentPlan;

  @override
  void initState() {
    super.initState();
    _currentPlan = widget.plan;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Stream tasks for this plan
    if (_currentPlan.taskIds.isNotEmpty) {
      context.read<TaskProvider>().streamTasksByIds(_currentPlan.taskIds);
    }
  }

  void _refreshPlan() async {
    final planProvider = context.read<PlanProvider>();
    final userId = context.read<UserProvider>().userId;
    if (userId != null) {
      await planProvider.loadUserPlans(userId);
      final updatedPlan = planProvider.userPlans.firstWhere(
        (p) => p.planId == _currentPlan.planId,
        orElse: () => _currentPlan,
      );
      setState(() {
        _currentPlan = updatedPlan;
      });
      // Refresh task stream if needed
      if (_currentPlan.taskIds.isNotEmpty) {
        context.read<TaskProvider>().streamTasksByIds(_currentPlan.taskIds);
      }
    }
  }

  Future<void> _editPlan() async {
    final titleController = TextEditingController(text: _currentPlan.planTitle);
    final descController = TextEditingController(text: _currentPlan.planDescription);
    DateTime? scheduledDate = _currentPlan.planScheduledFor;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        scheduledDate == null
                            ? 'No date scheduled'
                            : 'Scheduled: ${scheduledDate!.day}/${scheduledDate!.month}/${scheduledDate!.year}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: scheduledDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setDialogState(() {
                            scheduledDate = date;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: const Text('Change'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      final updatedPlan = _currentPlan.copyWith(
        planTitle: titleController.text.trim(),
        planDescription: descController.text.trim(),
        planScheduledFor: scheduledDate,
      );

      final success = await context.read<PlanProvider>().updatePlan(updatedPlan);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan updated successfully')),
        );
        _refreshPlan();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update plan')),
        );
      }
    }

    titleController.dispose();
    descController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Plan: ${_currentPlan.planTitle}"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editPlan,
            tooltip: 'Edit Plan',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan Header
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentPlan.planTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentPlan.planDescription,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 12),
                      if (_currentPlan.planScheduledFor != null)
                        Row(
                          children: [
                            Icon(Icons.calendar_today, 
                                 size: 16, 
                                 color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'Scheduled: ${_formatDate(_currentPlan.planScheduledFor!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Progress Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tasks: ${_currentPlan.completedTasks}/${_currentPlan.totalTasks}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Text(
                          '${_currentPlan.completionPercentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _currentPlan.completionPercentage / 100,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blue.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tasks Section
            const Text(
              'Tasks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Consumer<TaskProvider>(
              builder: (context, taskProvider, _) {
                final tasks = taskProvider.tasks;

                if (taskProvider.isLoading && tasks.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (tasks.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No tasks in this plan',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _TaskTile(task: task);
                  },
                );
              },
            ),
          ],
        ),
      ),
    ));
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'Today';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;

  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(
          value: task.taskIsDone,
          onChanged: null, // Make read-only for now
        ),
        title: Text(
          task.taskTitle,
          style: TextStyle(
            decoration: task.taskIsDone ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.taskBoardTitle != null)
              Text(
                task.taskBoardTitle!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            Text(
              task.taskStatus.replaceAll('_', ' '),
              style: TextStyle(
                fontSize: 11,
                color: _getStatusColor(task.taskStatus),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: task.taskDeadline != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(Icons.calendar_today, size: 14),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(task.taskDeadline!),
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'Today';
    } else if (dateToCheck.isBefore(today)) {
      return 'Overdue';
    } else {
      return '${date.day}/${date.month}';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'TODO':
        return Colors.grey;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'IN_REVIEW':
        return Colors.purple;
      case 'COMPLETED':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
