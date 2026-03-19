import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../datasources/models/board_model.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/models/task_stats_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../../../shared/features/thoughts/datasources/models/thought_model.dart';
import '../../../../../shared/features/thoughts/datasources/providers/thought_provider.dart';
import '../../controllers/board_tasks_query_controller.dart';
import '../dialogs/add_task_to_board_dialog.dart';
import '../cards/board_task_card.dart';

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
  final Set<String> _deletingSuggestionIds = <String>{};
  final Set<String> _publishingTaskIds = <String>{};
  bool _isSuggestionsQueueOpen = false;

  void _showSnackBarSafe(ScaffoldMessengerState? messenger, SnackBar snackBar) {
    if (!mounted) return;
    if (messenger == null || !messenger.mounted) return;
    messenger.showSnackBar(snackBar);
  }

  @override
  void initState() {
    super.initState();
    _selectedFilters = {BoardTasksQueryController.allFilter};
    _loadFilterState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().streamTasksByBoard(widget.boardId);
      if (widget.board.boardType != 'personal') {
        context.read<ThoughtProvider>().streamBoardTaskSuggestions(
          widget.boardId,
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
    final messenger = ScaffoldMessenger.maybeOf(context);
    final userProvider = context.read<UserProvider>();
    final thoughtProvider = context.read<ThoughtProvider>();

    final draft = await showDialog<_SuggestionDraft>(
      context: context,
      builder: (_) => const _SuggestionDialog(),
    );

    if (draft == null) return;

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      _showSnackBarSafe(
        messenger,
        const SnackBar(content: Text('You need to be signed in.')),
      );
      return;
    }

    try {
      final authorName =
          (userProvider.currentUser?.userName.isNotEmpty ?? false)
          ? userProvider.currentUser!.userName
          : (firebaseUser.displayName ?? 'Unknown');

      final now = DateTime.now();
      await thoughtProvider.createTaskSuggestionThought(
        boardId: widget.board.boardId,
        boardTitle: widget.board.boardTitle,
        boardManagerId: widget.board.boardManagerId,
        boardManagerName: widget.board.boardManagerName,
        senderUserId: firebaseUser.uid,
        senderUserName: authorName,
        title: draft.title,
        description: draft.description,
      );
      _showSnackBarSafe(
        messenger,
        const SnackBar(content: Text('Task suggestion submitted to Drafts.')),
      );
    } catch (e) {
      _showSnackBarSafe(
        messenger,
        SnackBar(
          content: Text('Failed to submit thought: $e'),
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

    return Consumer2<TaskProvider, ThoughtProvider>(
      builder: (context, taskProvider, thoughtProvider, _) {
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final isManager = widget.board.isManager(currentUserId);
        final canDraftTasks = widget.board.canDraftTasks(currentUserId);
        final isPersonalBoard = widget.board.boardType == 'personal';
        final activeLane = canDraftTasks ? widget.selectedLane : lanePublished;
        final pendingSuggestions = (isPersonalBoard
                ? const <ThoughtModel>[]
                : thoughtProvider.boardTaskSuggestions)
            .where((thought) => thought.isTaskSuggestion)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
                              content: Text('No task suggestions right now.'),
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
                        (thought) => _BoardThoughtCard(
                          key: ValueKey(thought.thoughtId),
                          title: _thoughtTitle(thought),
                          description: _thoughtDescription(thought),
                          authorName: _thoughtAuthor(thought),
                          isConverting: _processingSuggestionIds.contains(
                            thought.thoughtId,
                          ),
                          isDeleting: _deletingSuggestionIds.contains(
                            thought.thoughtId,
                          ),
                          canDelete:
                              isManager ||
                              thought.senderUserId ==
                                  currentUserId,
                          onConvert: () => _convertSuggestionToTask(thought),
                          onDelete: () => _deleteSuggestion(thought),
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
                          key: ValueKey(task.taskId),
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

  Future<void> _convertSuggestionToTask(ThoughtModel thought) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userProvider = context.read<UserProvider>();
    final taskProvider = context.read<TaskProvider>();
    final thoughtProvider = context.read<ThoughtProvider>();
    final managerName = (userProvider.currentUser?.userName.isNotEmpty ?? false)
        ? userProvider.currentUser!.userName
        : (currentUser.displayName ?? widget.board.boardManagerName);

    setState(() {
      _processingSuggestionIds.add(thought.thoughtId);
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
        taskTitle: _thoughtTitle(thought).trim().isEmpty
            ? 'Untitled Task'
            : _thoughtTitle(thought).trim(),
        taskDescription: _thoughtDescription(thought).trim(),
        taskIsDone: false,
        taskIsDoneAt: null,
        taskIsDeleted: false,
        taskDeletedAt: null,
        taskStats: TaskStats(),
        taskStatus: 'To Do',
        taskRequiresApproval: false,
        taskAssignmentStatus: null,
        taskBoardLane: laneDrafts,
      );

      await taskProvider.addTask(newTask);
      await thoughtProvider.updateSuggestionOutcome(
        thoughtId: thought.thoughtId,
        status: ThoughtModel.statusResolved,
        convertedTaskId: newTask.taskId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task suggestion converted to Draft task.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to convert thought: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingSuggestionIds.remove(thought.thoughtId);
        });
      }
    }
  }

  Future<void> _deleteSuggestion(ThoughtModel thought) async {
    if (_deletingSuggestionIds.contains(thought.thoughtId)) return;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final canDelete =
        currentUserId != null &&
        (widget.board.isManager(currentUserId) ||
            thought.senderUserId == currentUserId);
    if (!canDelete) {
      _showSnackBarSafe(
        ScaffoldMessenger.maybeOf(context),
        const SnackBar(
          content: Text(
            'Only the board manager or suggestion author can delete this task suggestion.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Task Suggestion'),
        content: const Text(
          'Are you sure you want to delete this task suggestion?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    final thoughtProvider = context.read<ThoughtProvider>();
    setState(() {
      _deletingSuggestionIds.add(thought.thoughtId);
    });

    try {
      await thoughtProvider.updateThoughtStatus(
        thoughtId: thought.thoughtId,
        status: ThoughtModel.statusDeleted,
      );
      _showSnackBarSafe(
        messenger,
        const SnackBar(content: Text('Task suggestion deleted.')),
      );
    } catch (e) {
      _showSnackBarSafe(
        messenger,
        SnackBar(
          content: Text('Failed to delete thought: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingSuggestionIds.remove(thought.thoughtId);
        });
      }
    }
  }

  String _thoughtTitle(ThoughtModel thought) {
    final metadata = thought.metadata ?? const <String, dynamic>{};
    final subject = (metadata['suggestionTitle']?.toString() ?? thought.title ?? '')
        .trim();
    if (subject.isNotEmpty) return subject;
    return 'Untitled Task Suggestion';
  }

  String _thoughtDescription(ThoughtModel thought) {
    final metadata = thought.metadata ?? const <String, dynamic>{};
    final description =
        (metadata['suggestionDescription']?.toString() ?? thought.message).trim();
    return description;
  }

  String _thoughtAuthor(ThoughtModel thought) {
    return thought.senderUserName.trim().isEmpty
        ? 'Unknown'
        : thought.senderUserName.trim();
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
      title: const Text('Task Suggestion'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Send a task suggestion to the board manager for review.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                maxLength: 80,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Task title',
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
          label: const Text('Send'),
        ),
      ],
    );
  }
}

class _BoardThoughtCard extends StatelessWidget {
  final String title;
  final String description;
  final String authorName;
  final VoidCallback? onConvert;
  final VoidCallback? onDelete;
  final bool isConverting;
  final bool isDeleting;
  final bool canDelete;

  const _BoardThoughtCard({
    super.key,
    required this.title,
    required this.description,
    required this.authorName,
    this.onConvert,
    this.onDelete,
    this.isConverting = false,
    this.isDeleting = false,
    this.canDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedTitle = title.trim().isEmpty ? 'Untitled Thought' : title.trim();
    final normalizedDescription = description.trim();
    final hasDescription = normalizedDescription.isNotEmpty;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    normalizedTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (hasDescription) ...[
              const SizedBox(height: 6),
              Text(
                normalizedDescription,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Suggested by $authorName',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: isConverting ? null : onConvert,
                  icon: Icon(
                    isConverting ? Icons.hourglass_top : Icons.task_alt,
                    size: 16,
                  ),
                  label: Text(isConverting ? 'Converting' : 'Convert'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (canDelete) ...[
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: isDeleting ? null : onDelete,
                    icon: Icon(
                      isDeleting ? Icons.hourglass_top : Icons.delete_outline,
                      size: 16,
                    ),
                    label: Text(isDeleting ? 'Deleting' : 'Delete'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.red.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
