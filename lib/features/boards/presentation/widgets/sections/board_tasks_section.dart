import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/models/board_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../dialogs/add_task_to_board_dialog.dart';
import '../cards/board_task_card.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BoardTasksSection extends StatefulWidget {
  final String boardId;
  final Board board;

  const BoardTasksSection({
    super.key,
    required this.boardId,
    required this.board,
  });

  @override
  State<BoardTasksSection> createState() => _BoardTasksSectionState();
}

class _BoardTasksSectionState extends State<BoardTasksSection> {
  late Set<String> _selectedFilters;

  // Define available task statuses
  static const List<String> taskStatuses = [
    'OVERDUE',
    'TODO',
    'IN_PROGRESS',
    'IN_REVIEW',
    'ON_PAUSE',
    'UNDER_REVISION',
    'COMPLETED'
  ];

  // Status display labels
  static const Map<String, String> statusLabels = {
    'OVERDUE': 'OVERDUE',
    'TODO': 'TO DO',
    'IN_PROGRESS': 'IN PROGRESS',
    'IN_REVIEW': 'IN REVIEW',
    'ON_PAUSE': 'ON PAUSE',
    'UNDER_REVISION': 'UNDER REVISION',
    'COMPLETED': 'COMPLETED'
  };

  @override
  void initState() {
    super.initState();
    // Initialize all statuses as selected (show all)
    _selectedFilters = Set.from(taskStatuses);
    // Stream tasks for this board only
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().streamTasksByBoard(widget.boardId);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showAddTaskDialog() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      showDialog(
        context: context,
        builder: (context) => AddTaskToBoardDialog(
          userId: user.uid,
          board: widget.board,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        // Filter tasks based on selected statuses
        final filteredTasks = taskProvider.tasks
            .where((task) => _selectedFilters.contains(task.taskStatus))
            .toList();

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tasks Header
              Row(
                children: [
                  const Text(
                    'Tasks',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.grey[300],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _showAddTaskDialog,
                    icon: const Icon(Icons.add),
                    iconSize: 20,
                  ),
                ],
              ),
              // Status Filters - Horizontal Scrollable
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
              const SizedBox(height: 4),
              // No tasks message (if empty)
              if (filteredTasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      Center(
                        child: Text(
                          'No tasks match the selected filters',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Press (+) to add a task!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const SizedBox.shrink(),
              // Tasks List
              if (filteredTasks.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: filteredTasks
                      .map((task) => BoardTaskCard(
                            task: task,
                            board: widget.board,
                            currentUserId: FirebaseAuth.instance.currentUser?.uid,
                          ))
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}
