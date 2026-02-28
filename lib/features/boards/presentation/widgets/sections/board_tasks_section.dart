import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../datasources/models/board_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../controllers/board_tasks_query_controller.dart';
import '../dialogs/add_task_to_board_dialog.dart';
import '../cards/board_task_card.dart';

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
  final BoardTasksQueryController _queryController =
      BoardTasksQueryController();
  late Set<String> _selectedFilters;
  bool _isLoading = true;
  String _sortBy = 'created_desc';

  @override
  void initState() {
    super.initState();
    _selectedFilters = {BoardTasksQueryController.allFilter};
    _loadFilterState();
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
        return;
      }
    } catch (_) {}

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveFilterState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'board_filters_${widget.boardId}';
      await prefs.setStringList(key, _selectedFilters.toList());
    } catch (_) {}
  }

  void _showAddTaskDialog() {
    final user = FirebaseAuth.instance.currentUser;
    final isManager = widget.board.boardManagerId == user?.uid;
    if (user == null) return;
    if (!isManager) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only board managers can create tasks.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) =>
          AddTaskToBoardDialog(userId: user.uid, board: widget.board),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        final sortedTasks = _queryController.applyQuery(
          tasks: taskProvider.tasks,
          selectedFilters: _selectedFilters,
          sortBy: _sortBy,
        );
        final canAddTask =
            widget.board.boardManagerId ==
            FirebaseAuth.instance.currentUser?.uid;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Tasks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(height: 1, color: Colors.grey[300]),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    tooltip: 'Sort tasks',
                    child: _buildHeaderIcon(Icons.sort),
                    onSelected: (value) => setState(() => _sortBy = value),
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
                      _buildSortItem('priority_asc', 'Low -> High'),
                      _buildSortItem('priority_desc', 'High -> Low'),
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
                      _buildSortItem('alphabetical_asc', 'A -> Z'),
                      _buildSortItem('alphabetical_desc', 'Z -> A'),
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
                      _buildSortItem('created_asc', 'Oldest'),
                      _buildSortItem('created_desc', 'Newest'),
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
                      _buildSortItem('deadline_asc', 'Soonest'),
                      _buildSortItem('deadline_desc', 'Latest'),
                    ],
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    tooltip: 'Add filters',
                    child: _buildHeaderIcon(Icons.filter_list),
                    onSelected: (filter) {
                      setState(() {
                        _selectedFilters = _queryController.addFilter(
                          selectedFilters: _selectedFilters,
                          filter: filter,
                        );
                      });
                    },
                    itemBuilder: (context) {
                      return BoardTasksQueryController.allFilters
                          .where((f) => !_selectedFilters.contains(f))
                          .map((filter) {
                            final label = _queryController.getFilterLabel(
                              filter,
                            );
                            return PopupMenuItem<String>(
                              value: filter,
                              child: Text(
                                label,
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          })
                          .toList();
                    },
                  ),
                  const SizedBox(width: 4),
                  if (canAddTask)
                    InkWell(
                      onTap: _showAddTaskDialog,
                      borderRadius: BorderRadius.circular(4),
                      child: _buildHeaderIcon(Icons.add),
                    ),
                ],
              ),
              if (_selectedFilters.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...(_selectedFilters.toList()..sort()).map((filter) {
                        final label = _queryController.getFilterLabel(filter);
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
                                _selectedFilters = _queryController
                                    .removeFilter(
                                      selectedFilters: _selectedFilters,
                                      filter: filter,
                                    );
                              });
                            },
                            backgroundColor: Colors.grey[400],
                            deleteIconColor: Colors.white,
                            side: BorderSide.none,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              if (sortedTasks.isEmpty) _buildEmptyTasksState(),
              if (sortedTasks.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sortedTasks
                      .map(
                        (task) => BoardTaskCard(
                          task: task,
                          board: widget.board,
                          currentUserId: FirebaseAuth.instance.currentUser?.uid,
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyTasksState() {
    return Padding(
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
    );
  }

  PopupMenuItem<String> _buildSortItem(String value, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Text(
        label,
        style: TextStyle(color: _sortBy == value ? Colors.blue : null),
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 16, color: Colors.grey[700]),
    );
  }
}
