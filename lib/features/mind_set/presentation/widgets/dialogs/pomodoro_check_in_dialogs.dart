import 'package:flutter/material.dart';
import '../../../../tasks/datasources/models/task_model.dart';

/// Result from task-done-early check-in
class TaskDoneEarlyResult {
  final bool continueWithAnother;
  final String? nextTaskId;
  final int? productivityRating;
  final String? moodFeedback;

  TaskDoneEarlyResult({
    required this.continueWithAnother,
    this.nextTaskId,
    this.productivityRating,
    this.moodFeedback,
  });
}

/// Result from timer-done check-in
class TimerDoneResult {
  final String? preselectedTaskId;
  final int? productivityRating;
  final String? moodFeedback;

  TimerDoneResult({
    this.preselectedTaskId,
    this.productivityRating,
    this.moodFeedback,
  });
}

/// Result from break-end confirmation
class BreakEndResult {
  final bool confirmed;
  final String? selectedTaskId;

  BreakEndResult({
    required this.confirmed,
    this.selectedTaskId,
  });
}

/// Shows dialog when task is done before timer ends
Future<TaskDoneEarlyResult?> showTaskDoneEarlyDialog(
  BuildContext context, {
  required List<Task> availableTasks,
}) async {
  int? productivityRating;
  String? moodFeedback;

  return showDialog<TaskDoneEarlyResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('🎉 Task Completed!'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Great job finishing that task! The timer is still running.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'How productive was this pomodoro?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final rating = index + 1;
                  return GestureDetector(
                    onTap: () => setState(() => productivityRating = rating),
                    child: Icon(
                      Icons.star,
                      size: 32,
                      color: productivityRating != null && productivityRating! >= rating
                          ? Colors.amber
                          : Colors.grey[300],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              const Text(
                'How are you feeling?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['😊 Great', '😐 Okay', '😓 Tired', '😤 Stressed']
                    .map((mood) => ChoiceChip(
                          label: Text(mood),
                          selected: moodFeedback == mood,
                          onSelected: (selected) =>
                              setState(() => moodFeedback = selected ? mood : null),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              TaskDoneEarlyResult(
                continueWithAnother: false,
                productivityRating: productivityRating,
                moodFeedback: moodFeedback,
              ),
            ),
            child: const Text('End Pomodoro'),
          ),
          ElevatedButton(
            onPressed: () {
              // Show task selection dialog
              showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Select Next Task'),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: availableTasks.isEmpty
                        ? const Text('No tasks available.')
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: availableTasks.length,
                            itemBuilder: (ctx, index) {
                              final task = availableTasks[index];
                              return ListTile(
                                title: Text(task.taskTitle),
                                subtitle: Text(task.taskPriorityLevel),
                                onTap: () => Navigator.pop(ctx, task.taskId),
                              );
                            },
                          ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ).then((taskId) {
                if (taskId != null) {
                  Navigator.pop(
                    context,
                    TaskDoneEarlyResult(
                      continueWithAnother: true,
                      nextTaskId: taskId,
                      productivityRating: productivityRating,
                      moodFeedback: moodFeedback,
                    ),
                  );
                }
              });
            },
            child: const Text('Continue with Another'),
          ),
        ],
      ),
    ),
  );
}

/// Shows dialog when timer ends before task is done
Future<TimerDoneResult?> showTimerDoneDialog(
  BuildContext context, {
  required List<Task> availableTasks,
  required Task currentTask,
}) async {
  int? productivityRating;
  String? moodFeedback;
  String? preselectedTaskId;

  return showDialog<TimerDoneResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('⏰ Pomodoro Complete!'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Time\'s up on "${currentTask.taskTitle}".',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'How productive was this session?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final rating = index + 1;
                  return GestureDetector(
                    onTap: () => setState(() => productivityRating = rating),
                    child: Icon(
                      Icons.star,
                      size: 32,
                      color: productivityRating != null && productivityRating! >= rating
                          ? Colors.amber
                          : Colors.grey[300],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              const Text(
                'How are you feeling?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['😊 Great', '😐 Okay', '😓 Tired', '😤 Stressed']
                    .map((mood) => ChoiceChip(
                          label: Text(mood),
                          selected: moodFeedback == mood,
                          onSelected: (selected) =>
                              setState(() => moodFeedback = selected ? mood : null),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'What would you like to work on after the break?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: preselectedTaskId,
                decoration: const InputDecoration(
                  labelText: 'Choose task',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  DropdownMenuItem(
                    value: currentTask.taskId,
                    child: Text('Continue: ${currentTask.taskTitle}'),
                  ),
                  ...availableTasks
                      .where((t) => t.taskId != currentTask.taskId && !t.taskIsDone)
                      .map((task) => DropdownMenuItem(
                            value: task.taskId,
                            child: Text(task.taskTitle),
                          )),
                ],
                onChanged: (value) => setState(() => preselectedTaskId = value),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(
              context,
              TimerDoneResult(
                preselectedTaskId: preselectedTaskId,
                productivityRating: productivityRating,
                moodFeedback: moodFeedback,
              ),
            ),
            child: const Text('Start Break'),
          ),
        ],
      ),
    ),
  );
}

/// Shows dialog when break ends to confirm pre-selected task
Future<BreakEndResult?> showBreakEndConfirmationDialog(
  BuildContext context, {
  required Task preselectedTask,
  required List<Task> allTasks,
}) async {
  return showDialog<BreakEndResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('☕ Break Over!'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ready to get back to work?'),
          const SizedBox(height: 12),
          Text(
            'You selected: ${preselectedTask.taskTitle}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Show task picker
            showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Choose Different Task'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: allTasks.isEmpty
                      ? const Text('No tasks available.')
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: allTasks.length,
                          itemBuilder: (ctx, index) {
                            final task = allTasks[index];
                            return ListTile(
                              title: Text(task.taskTitle),
                              subtitle: Text(task.taskPriorityLevel),
                              onTap: () => Navigator.pop(ctx, task.taskId),
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ).then((taskId) {
              if (taskId != null) {
                Navigator.pop(
                  context,
                  BreakEndResult(confirmed: false, selectedTaskId: taskId),
                );
              }
            });
          },
          child: const Text('Choose Different'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(
            context,
            BreakEndResult(confirmed: true, selectedTaskId: preselectedTask.taskId),
          ),
          child: const Text('Start Working'),
        ),
      ],
    ),
  );
}

/// Shows confirmation when user wants to switch focus mid-pomodoro
Future<bool> showSwitchFocusConfirmationDialog(
  BuildContext context, {
  required Task currentTask,
  required Task newTask,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('⚠️ Switch Task?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('The pomodoro timer is still running.'),
          const SizedBox(height: 12),
          Text('Current: ${currentTask.taskTitle}'),
          Text('Switch to: ${newTask.taskTitle}'),
          const SizedBox(height: 12),
          const Text(
            'Switching will keep the timer running on the new task.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text('Switch Task'),
        ),
      ],
    ),
  );
  return result ?? false;
}
