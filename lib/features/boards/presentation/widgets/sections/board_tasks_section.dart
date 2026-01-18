import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/models/board_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../dialogs/add_task_to_board_dialog.dart';
import '../cards/board_task_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
  bool _isLoading = true;

  // Special filter
  static const String allFilter = 'All';

  // Core statuses only
  static const List<String> taskStatuses = [
    'To Do',
    'In Progress',
    'Paused',
    'COMPLETED'
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

  // Status display labels
  static const Map<String, String> statusLabels = {
    'To Do': 'To Do',
    'In Progress': 'In Progress',
    'Paused': 'Paused',
    'COMPLETED': 'Completed'
  };

  static const Map<String, String> deadlineLabels = {
    'Overdue': 'Overdue',
    'Today': 'Today',
    'Upcoming': 'Upcoming',
    'None': 'None',
  };

  static final Map<String, Color> statusColors = {
    'To Do': Colors.grey,
    'In Progress': Colors.blue,
    'Paused': Colors.orange,
    'COMPLETED': Colors.green,
  };

  static final Map<String, Color> deadlineColors = {
    'Overdue': Colors.red,
    'Today': Colors.orange,
    'Upcoming': Colors.amber,
    'None': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    // Initialize with 'All' by default
    _selectedFilters = {allFilter};
    _loadFilterState();
    // Stream tasks for this board only
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().streamTasksByBoard(widget.boardId);
    });
  }

  @override
  void dispose() {
    _saveFilterState();
    super.dispose();
  }

  Future<void> _loadFilterState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'board_filters_${widget.boardId}';
      final savedFilters = prefs.getStringList(key);
      
      if (savedFilters != null && savedFilters.isNotEmpty) {
        setState(() {
          _selectedFilters = savedFilters.toSet();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading filter state: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveFilterState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'board_filters_${widget.boardId}';
      await prefs.setStringList(key, _selectedFilters.toList());
    } catch (e) {
      print('Error saving filter state: $e');
    }
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

  bool _matchesDeadlineFilter(dynamic task, String filter) {
    switch (filter) {
      case 'Overdue':
        return task.isOverdue;
      case 'Today':
        return task.isDueToday;
      case 'Upcoming':
        return task.isDueUpcoming;
      case 'None':
        return task.taskDeadline == null;
      default:
        return false;
    }
  }

  String _getFilterLabel(String filter) {
    if (taskStatuses.contains(filter)) {
      return 'Status: ${statusLabels[filter] ?? filter}';
    } else if (deadlineFilters.contains(filter)) {
      return 'Deadline: ${deadlineLabels[filter] ?? filter}';
    }
    return filter;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        // If 'All' is selected, show all tasks
        final List<dynamic> filteredTasks;
        
        if (_selectedFilters.contains(allFilter)) {
          filteredTasks = taskProvider.tasks;
        } else {
          // Separate selected status and deadline filters
          final selectedStatuses = _selectedFilters
              .where((f) => taskStatuses.contains(f))
              .toSet();
          final selectedDeadlineFilters = _selectedFilters
              .where((f) => deadlineFilters.contains(f))
              .toSet();

          // Filter tasks based on selected statuses and deadline filters
          filteredTasks = taskProvider.tasks
              .where((task) {
            // If no status filters selected, show none (user must select something)
            if (selectedStatuses.isEmpty) {
              return false;
            }

            // Always check if status matches
            final statusMatch = selectedStatuses.contains(task.taskStatus);

            // If no deadline filters are selected, show all tasks with matching status
            if (selectedDeadlineFilters.isEmpty) {
              return statusMatch;
            }

            // If deadline filters ARE selected, task must match status AND at least one deadline filter
            final deadlineMatch = selectedDeadlineFilters.any((filter) {
              return _matchesDeadlineFilter(task, filter);
            });

            return statusMatch && deadlineMatch;
          }).toList();
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tasks Header with Filter Button
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
                          // If 'All' is selected, clear all other filters
                          _selectedFilters = {allFilter};
                        } else {
                          // If any other filter is selected, remove 'All'
                          _selectedFilters.remove(allFilter);
                          _selectedFilters.add(filter);
                          
                          // If no filters remain after removing 'All', add the selected one
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
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showAddTaskDialog,
                        borderRadius: BorderRadius.circular(4),
                        child: const Icon(Icons.add, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
              // Selected Filters as Chips
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
                                // If all filters are removed, default back to 'All'
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
                      }).toList(),
                    ],
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
