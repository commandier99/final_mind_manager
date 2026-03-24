import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../datasources/models/board_model.dart';
import '../../../../thoughts/datasources/models/thought_model.dart';
import '../../../../thoughts/datasources/services/thought_service.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/presentation/utils/task_assignment_workflow_helper.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../controllers/board_tasks_query_controller.dart';
import '../dialogs/add_task_to_board_dialog.dart';
import '../cards/board_task_card.dart';
import '../cards/suggested_task_card.dart';
import '../../../../thoughts/presentation/widgets/dialogs/create_thought_dialog.dart';

class BoardTasksSection extends StatefulWidget {
  final String boardId;
  final Board board;
  final String selectedLane;

  const BoardTasksSection({
    super.key,
    required this.boardId,
    required this.board,
    this.selectedLane = _BoardTasksSectionState.lanePublished,
  });

  @override
  State<BoardTasksSection> createState() => _BoardTasksSectionState();
}

class _BoardTasksSectionState extends State<BoardTasksSection> {
  static const String laneDrafts = Task.laneDrafts;
  static const String lanePublished = Task.lanePublished;

  final BoardTasksQueryController _queryController =
      BoardTasksQueryController();
  final ThoughtService _thoughtService = ThoughtService();
  late Set<String> _selectedFilters;
  bool _isLoading = true;
  String _sortBy = 'created_desc';
  bool _showTaskSuggestions = false;
  final Set<String> _publishingTaskIds = <String>{};

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
    final canAddTasks = widget.board.isManager(user?.uid);
    if (user == null) return;
    if (!canAddTasks) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only managers can create draft tasks.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddTaskToBoardDialog(
        userId: user.uid,
        board: widget.board,
        asSheet: true,
      ),
    );
  }

  Future<void> _showCreateSuggestionThoughtSheet() async {
    final created = await CreateThoughtDialog.show(
      context,
      initialType: Thought.typeSuggestion,
      initialBoardId: widget.boardId,
      lockType: true,
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suggestion thought created.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final isManager = widget.board.isManager(currentUserId);
        final isSupervisor = widget.board.isSupervisor(currentUserId);
        final canDraftTasks = widget.board.canDraftTasks(currentUserId);
        final canCreateSuggestion = currentUserId != null &&
            currentUserId.isNotEmpty &&
            (widget.board.roleOf(currentUserId) == 'member' || isSupervisor);
        final activeLane = canDraftTasks ? widget.selectedLane : lanePublished;
        final showSuggestionToggle = isManager && activeLane == laneDrafts;

        final visibleTasks = taskProvider.tasks.where((task) {
          final lane = task.taskBoardLane;
          if (!canDraftTasks) return lane != laneDrafts;
          return lane == activeLane;
        }).toList();

        final sortedTasks = _queryController.applyQuery(
          tasks: visibleTasks,
          selectedFilters: _selectedFilters,
          sortBy: _sortBy,
        );

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
                    child: _buildHeaderIcon(Icons.swap_vert),
                    onSelected: (value) => setState(() => _sortBy = value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        enabled: false,
                        child: Text(
                          'Priority',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      _buildSortItem('priority_asc', 'Low -> High'),
                      _buildSortItem('priority_desc', 'High -> Low'),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        enabled: false,
                        child: Text(
                          'Alphabetical',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      _buildSortItem('alphabetical_asc', 'A -> Z'),
                      _buildSortItem('alphabetical_desc', 'Z -> A'),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        enabled: false,
                        child: Text(
                          'Created Date',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      _buildSortItem('created_asc', 'Oldest'),
                      _buildSortItem('created_desc', 'Newest'),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        enabled: false,
                        child: Text(
                          'Deadline',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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
                        final label = _queryController.getFilterLabel(filter);
                        return PopupMenuItem<String>(
                          value: filter,
                          child: Text(label, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList();
                    },
                  ),
                  if (canCreateSuggestion) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Create suggestion thought',
                      child: InkWell(
                        onTap: _showCreateSuggestionThoughtSheet,
                        borderRadius: BorderRadius.circular(4),
                        child: _buildHeaderIcon(Icons.lightbulb_outline),
                      ),
                    ),
                  ],
                  if (showSuggestionToggle) ...[
                    const SizedBox(width: 4),
                    _buildSuggestionToggle(),
                  ],
                  const SizedBox(width: 4),
                  if (isManager)
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
                                _selectedFilters = _queryController.removeFilter(
                                  selectedFilters: _selectedFilters,
                                  filter: filter,
                                );
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
              if (showSuggestionToggle && _showTaskSuggestions) ...[
                _buildTaskSuggestionStream(),
                const SizedBox(height: 6),
              ],
              if (sortedTasks.isEmpty)
                _buildEmptyTasksState(
                  canDraftTasks: canDraftTasks,
                  activeLane: activeLane,
                  canAddTasks: isManager,
                  showingSuggestions: showSuggestionToggle && _showTaskSuggestions,
                ),
              if (sortedTasks.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sortedTasks
                      .map(
                        (task) => BoardTaskCard(
                          key: ValueKey(task.taskId),
                          task: task,
                          board: widget.board,
                          currentUserId: currentUserId,
                          showPublishButton: isManager && activeLane == laneDrafts,
                          isPublishing: _publishingTaskIds.contains(task.taskId),
                          onPublish: () => _publishTask(task),
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

  Future<void> _publishTask(Task task) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (!widget.board.canPublishTasks(currentUserId)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only managers can publish tasks.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_publishingTaskIds.contains(task.taskId)) return;
    setState(() {
      _publishingTaskIds.add(task.taskId);
    });

    try {
      final assignmentAppliedTask = await _applyAssignmentOnPublish(task);
      if (!mounted) return;
      await context.read<TaskProvider>().updateTask(
        assignmentAppliedTask.copyWith(taskBoardLane: lanePublished),
      );
      if (!mounted) return;
      final hasPendingAssignment =
          assignmentAppliedTask.taskAssignmentStatus == 'pending' &&
          (assignmentAppliedTask.taskProposedAssigneeId ?? '').trim().isNotEmpty;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasPendingAssignment
                ? 'Task published. Assignment request sent to member.'
                : 'Task moved to Published.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to publish task: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _publishingTaskIds.remove(task.taskId);
        });
      }
    }
  }

  Future<Task> _applyAssignmentOnPublish(Task task) async {
    final proposedAssigneeId = (task.taskProposedAssigneeId ?? '').trim();
    final proposedAssigneeName = (task.taskProposedAssigneeName ?? '').trim();
    if (proposedAssigneeId.isEmpty ||
        proposedAssigneeId == task.taskOwnerId ||
        proposedAssigneeId == 'None') {
      return task;
    }

    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) {
      throw StateError('No signed-in user found.');
    }
    await TaskAssignmentWorkflowHelper.createAssignmentRequestIfNeeded(
      context: context,
      task: task,
      assigneeId: proposedAssigneeId,
      assigneeName: proposedAssigneeName,
      actorUserId: currentUser.userId,
      actorUserName: currentUser.userName,
    );

    return task.copyWith(
      taskAssignedTo: 'None',
      taskAssignedToName: 'None (Pending)',
      taskAssignmentStatus: 'pending',
      taskProposedAssigneeId: proposedAssigneeId,
      taskProposedAssigneeName:
          proposedAssigneeName.isEmpty ? 'Assigned Member' : proposedAssigneeName,
    );
  }

  Widget _buildEmptyTasksState({
    required bool canDraftTasks,
    required String activeLane,
    required bool canAddTasks,
    bool showingSuggestions = false,
  }) {
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
          if (canDraftTasks && activeLane == laneDrafts) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                canAddTasks
                    ? (showingSuggestions
                        ? 'Press (+) to add a task, or switch off Suggestions.'
                        : 'Press (+) to add a task!')
                    : 'Use the lightbulb icon to create a suggestion.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionToggle() {
    return Tooltip(
      message: _showTaskSuggestions
          ? 'Hide task suggestions'
          : 'Show task suggestions',
      child: InkWell(
        onTap: () {
          setState(() {
            _showTaskSuggestions = !_showTaskSuggestions;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _showTaskSuggestions ? const Color(0xFFFFF7CC) : null,
            border: Border.all(
              color: _showTaskSuggestions
                  ? const Color(0xFFEAB308)
                  : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                Icons.inbox_outlined,
                    size: 16,
                    color: _showTaskSuggestions
                        ? const Color(0xFF854D0E)
                        : Colors.grey[700],
              ),
              const SizedBox(width: 6),
              Text(
                'Suggestions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _showTaskSuggestions
                      ? const Color(0xFF854D0E)
                      : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskSuggestionStream() {
    return StreamBuilder<List<Thought>>(
      stream: _thoughtService.streamThoughtsByBoard(widget.boardId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(minHeight: 3),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Could not load task suggestions.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[400],
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }

        final thoughts = snapshot.data ?? const <Thought>[];
        final taskSuggestions = thoughts.where((thought) {
          if (thought.type != Thought.typeSuggestion) return false;
          if (!thought.isActionable) return false;
          final metadata = thought.metadata ?? const <String, dynamic>{};
          final suggestionTarget = (metadata['suggestionTarget']?.toString() ?? '')
              .trim()
              .toLowerCase();
          return suggestionTarget == 'task';
        }).toList();

        if (taskSuggestions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No task suggestions waiting in Drafts.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Text(
                'Task Suggestions',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[700],
                ),
              ),
            ),
            ...taskSuggestions.map(
              (thought) => SuggestedTaskCard(
                key: ValueKey('suggestion_${thought.thoughtId}'),
                thought: thought,
                board: widget.board,
              ),
            ),
          ],
        );
      },
    );
  }

  PopupMenuItem<String> _buildSortItem(String value, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Text(
        label,
        style: TextStyle(color: _sortBy == value ? Colors.black87 : null),
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
