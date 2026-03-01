import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../datasources/models/board_model.dart';
import '../../../../suggestions/datasources/models/suggestion_model.dart';
import '../../../../suggestions/datasources/providers/suggestion_provider.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/models/task_stats_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../controllers/board_tasks_query_controller.dart';
import '../dialogs/add_task_to_board_dialog.dart';
import '../cards/board_task_card.dart';
import '../../../../suggestions/presentation/widgets/suggestion_card.dart';

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
  late Set<String> _selectedFilters;
  bool _isLoading = true;
  String _sortBy = 'created_desc';
  final Set<String> _processingSuggestionIds = <String>{};
  final Set<String> _publishingTaskIds = <String>{};
  bool _isSuggestionsQueueOpen = false;

  bool _isPendingSuggestion(String status) {
    return status.trim().toLowerCase() == 'pending';
  }

  @override
  void initState() {
    super.initState();
    _selectedFilters = {BoardTasksQueryController.allFilter};
    _loadFilterState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().streamTasksByBoard(widget.boardId);
      if (widget.board.boardType != 'personal') {
        context.read<SuggestionProvider>().listenToBoardSuggestions(
          widget.boardId,
          includeResolved: false,
        );
      }
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
    final canDraftTasks = widget.board.canDraftTasks(user?.uid);
    if (user == null) return;
    if (!canDraftTasks) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only managers or supervisors can create draft tasks.'),
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

  Future<void> _showSuggestionsDialog() async {
    final userProvider = context.read<UserProvider>();
    final suggestionProvider = context.read<SuggestionProvider>();

    final draft = await showDialog<_SuggestionDraft>(
      context: context,
      builder: (_) => const _SuggestionDialog(),
    );

    if (draft == null) return;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be signed in.')),
      );
      return;
    }

    try {
      final authorName =
          (userProvider.currentUser?.userName.isNotEmpty ?? false)
          ? userProvider.currentUser!.userName
          : (firebaseUser.displayName ?? 'Unknown');

      final suggestion = Suggestion(
        suggestionId: const Uuid().v4(),
        suggestionBoardId: widget.board.boardId,
        suggestionAuthorId: firebaseUser.uid,
        suggestionAuthorName: authorName,
        suggestionAuthorProfilePicture:
            userProvider.currentUser?.userProfilePicture,
        suggestionTitle: draft.title,
        suggestionDescription: draft.description,
        suggestionCreatedAt: DateTime.now(),
        suggestionStatus: 'pending',
      );

      await suggestionProvider.addSuggestion(suggestion);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suggestion submitted to Drafts.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit suggestion: $e'),
          backgroundColor: Colors.red,
        ),
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
        final canDraftTasks = widget.board.canDraftTasks(currentUserId);
        final isPersonalBoard = widget.board.boardType == 'personal';
        final activeLane = canDraftTasks ? widget.selectedLane : lanePublished;
        final suggestions = isPersonalBoard
            ? const <Suggestion>[]
            : context.watch<SuggestionProvider>().suggestions;
        final pendingSuggestions = suggestions
            .where((s) => _isPendingSuggestion(s.suggestionStatus))
            .toList();

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
        final canAddTask = canDraftTasks;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!isPersonalBoard) ...[
                    const Text(
                      'Tasks',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
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
                  if (canAddTask && activeLane == laneDrafts) ...[
                    InkWell(
                      onTap: () {
                        if (pendingSuggestions.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No suggestions right now.'),
                            ),
                          );
                          return;
                        }
                        _toggleSuggestionsQueue();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: _buildMailboxSuggestionButton(
                        unreadCount: pendingSuggestions.length,
                        isOpen: _isSuggestionsQueueOpen,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: _showAddTaskDialog,
                      borderRadius: BorderRadius.circular(4),
                      child: _buildHeaderIcon(Icons.add),
                    ),
                  ] else if (canAddTask && isPersonalBoard)
                    InkWell(
                      onTap: _showAddTaskDialog,
                      borderRadius: BorderRadius.circular(4),
                      child: _buildHeaderIcon(Icons.add),
                    )
                  else if (!isPersonalBoard && activeLane == lanePublished)
                    InkWell(
                      onTap: _showSuggestionsDialog,
                      borderRadius: BorderRadius.circular(4),
                      child: _buildHeaderIcon(Icons.post_add),
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
              if (!isPersonalBoard &&
                  canDraftTasks &&
                  activeLane == laneDrafts &&
                  _isSuggestionsQueueOpen &&
                  pendingSuggestions.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: pendingSuggestions
                      .map(
                        (suggestion) => SuggestionCard(
                          suggestion: suggestion,
                          isConverting: _processingSuggestionIds.contains(
                            suggestion.suggestionId,
                          ),
                          onConvert: () => _convertSuggestionToTask(suggestion),
                        ),
                      )
                      .toList(),
                ),
              if (sortedTasks.isEmpty)
                _buildEmptyTasksState(
                  canDraftTasks: canDraftTasks,
                  activeLane: activeLane,
                ),
              if (sortedTasks.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sortedTasks
                      .map(
                        (task) => BoardTaskCard(
                          task: task,
                          board: widget.board,
                          currentUserId: FirebaseAuth.instance.currentUser?.uid,
                          showPublishButton:
                              isManager && activeLane == laneDrafts,
                          isPublishing: _publishingTaskIds.contains(
                            task.taskId,
                          ),
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

  Future<void> _convertSuggestionToTask(Suggestion suggestion) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userProvider = context.read<UserProvider>();
    final taskProvider = context.read<TaskProvider>();
    final suggestionProvider = context.read<SuggestionProvider>();
    final managerName = (userProvider.currentUser?.userName.isNotEmpty ?? false)
        ? userProvider.currentUser!.userName
        : (currentUser.displayName ?? widget.board.boardManagerName);

    setState(() {
      _processingSuggestionIds.add(suggestion.suggestionId);
    });

    try {
      final newTask = Task(
        taskId: const Uuid().v4(),
        taskBoardId: widget.board.boardId,
        taskBoardTitle: widget.board.boardTitle,
        taskOwnerId: currentUser.uid,
        taskOwnerName: managerName,
        taskAssignedBy: currentUser.uid,
        taskAssignedTo: 'None',
        taskAssignedToName: 'Unassigned',
        taskPriorityLevel: 'Low',
        taskCreatedAt: DateTime.now(),
        taskTitle: suggestion.suggestionTitle.trim().isEmpty
            ? 'Untitled Task'
            : suggestion.suggestionTitle.trim(),
        taskDescription: suggestion.suggestionDescription.trim(),
        taskIsDone: false,
        taskIsDoneAt: null,
        taskIsDeleted: false,
        taskDeletedAt: null,
        taskStats: TaskStats(),
        taskStatus: 'To Do',
        taskRequiresApproval: false,
        taskAcceptanceStatus: null,
        taskBoardLane: laneDrafts,
      );

      await taskProvider.addTask(newTask);
      await suggestionProvider.reviewSuggestion(
        suggestionId: suggestion.suggestionId,
        status: 'converted',
        reviewerId: currentUser.uid,
        reviewNote: 'Converted into drafts task',
        convertedTaskId: newTask.taskId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suggestion converted to Draft task.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to convert suggestion: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingSuggestionIds.remove(suggestion.suggestionId);
        });
      }
    }
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
      await context.read<TaskProvider>().updateTask(
        task.copyWith(taskBoardLane: lanePublished),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task moved to Published.')));
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

  Widget _buildEmptyTasksState({
    required bool canDraftTasks,
    required String activeLane,
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
                'Press (+) to add a task!',
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

  Widget _buildMailboxSuggestionButton({
    required int unreadCount,
    required bool isOpen,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
        color: isOpen ? Colors.grey.shade100 : null,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.mail_outline, size: 16, color: Colors.grey[700]),
          if (unreadCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleSuggestionsQueue() {
    setState(() {
      _isSuggestionsQueueOpen = !_isSuggestionsQueueOpen;
    });
  }
}

class _SuggestionDraft {
  final String title;
  final String description;

  const _SuggestionDraft({required this.title, required this.description});
}

class _SuggestionDialog extends StatefulWidget {
  const _SuggestionDialog();

  @override
  State<_SuggestionDialog> createState() => _SuggestionDialogState();
}

class _SuggestionDialogState extends State<_SuggestionDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      setState(() {
        _titleError = 'Please enter a title.';
      });
      return;
    }

    Navigator.of(
      context,
    ).pop(_SuggestionDraft(title: title, description: description));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Drop a Suggestion'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Suggest a task to the manager for the board.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                maxLength: 80,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Suggestion title',
                  border: const OutlineInputBorder(),
                  errorText: _titleError,
                ),
                onChanged: (_) {
                  if (_titleError != null) {
                    setState(() => _titleError = null);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLength: 500,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.send, size: 16),
          label: const Text('Submit'),
        ),
      ],
    );
  }
}
