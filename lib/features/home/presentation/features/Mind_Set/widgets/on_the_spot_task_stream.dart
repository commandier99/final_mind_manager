import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../../tasks/presentation/widgets/cards/task_card.dart';
import '../../../../../tasks/datasources/models/task_model.dart';
import '../../../../../tasks/datasources/models/task_stats_model.dart';

class OnTheSpotTaskStream extends StatefulWidget {
  final String mode;
  final bool isSessionActive;

  const OnTheSpotTaskStream({
    super.key,
    required this.mode,
    required this.isSessionActive,
  });

  @override
  State<OnTheSpotTaskStream> createState() => _OnTheSpotTaskStreamState();
}

class _OnTheSpotTaskStreamState extends State<OnTheSpotTaskStream> {
  String? _taskInProgress; // Track which task is currently in progress
  final List<Task> _tasks = []; // Task list
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tasks Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tasks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                _addNewTask();
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (!widget.isSessionActive)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Start the session to begin working on tasks.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
        
        // Tasks List
        Expanded(
          child: _tasks.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Text(
                      'No tasks yet. Tap the + button to create one!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final task = _tasks[index];
                    return TaskCard(
                      task: task,
                      onDelete: () {
                        setState(() {
                          _tasks.removeAt(index);
                          if (_taskInProgress == task.taskId) {
                            _taskInProgress = null;
                          }
                        });
                      },
                      onToggleDone: widget.isSessionActive
                          ? (isDone) {
                              if (widget.mode == 'Checklist' && isDone == true) {
                                setState(() {
                                  _tasks[index] = task.copyWith(
                                    taskIsDone: true,
                                    taskIsDoneAt: DateTime.now(),
                                    taskStatus: 'Completed',
                                  );
                                  _taskInProgress = null;
                                });
                              }
                            }
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _addNewTask() {
    // Create a new task with minimal data for Mind:Set
    final newTask = Task(
      taskId: DateTime.now().millisecondsSinceEpoch.toString(),
      taskBoardId: '', // Personal task, no board
      taskBoardTitle: 'Mind:Set',
      taskOwnerId: _currentUserId,
      taskOwnerName: 'Me',
      taskAssignedBy: _currentUserId,
      taskAssignedTo: _currentUserId,
      taskAssignedToName: 'Me',
      taskPriorityLevel: 'Medium',
      taskCreatedAt: DateTime.now(),
      taskTitle: 'New Task ${_tasks.length + 1}',
      taskDescription: 'Task created in Mind:Set',
      taskStats: TaskStats(
        taskSubtasksCount: 0,
        taskSubtasksDoneCount: 0,
      ),
      taskStatus: 'To Do',
      taskIsDone: false,
    );

    setState(() {
      _tasks.add(newTask);
    });
  }
}
