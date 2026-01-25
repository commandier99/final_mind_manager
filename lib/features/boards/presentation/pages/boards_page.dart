import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../datasources/models/board_model.dart';
import '../../datasources/providers/board_provider.dart';
import '../../datasources/providers/board_stats_provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../widgets/cards/board_card.dart';
import '../widgets/dialogs/add_board_button.dart';
import 'board_details_page.dart';

class BoardsPage extends StatefulWidget {
  final void Function(VoidCallback)? onSearchToggleReady;
  final void Function(bool, TextEditingController, ValueChanged<String>, VoidCallback)? onSearchStateChanged;

  const BoardsPage({super.key, this.onSearchToggleReady, this.onSearchStateChanged});

  @override
  State<BoardsPage> createState() => _BoardsPageState();
}

class _BoardsPageState extends State<BoardsPage> {
  String? _userId;
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    widget.onSearchToggleReady?.call(_toggleSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.watch<UserProvider>().userId;
    if (_userId != userId && userId != null) {
      _userId = userId;
      print('[DEBUG] BoardsPage: didChangeDependencies, userId = $_userId');
      // Schedule the board refresh after the frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final boardProvider = Provider.of<BoardProvider>(
          context,
          listen: false,
        );
        final statsProvider = Provider.of<BoardStatsProvider>(
          context,
          listen: false,
        );

        boardProvider.refreshBoards();

        // Stream stats for all boards
        for (var board in boardProvider.boards) {
          statsProvider.streamStatsForBoard(board.boardId);
        }
      });
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (!_isSearchExpanded) {
        _searchController.clear();
        _searchQuery = '';
      }
      widget.onSearchStateChanged?.call(
        _isSearchExpanded,
        _searchController,
        (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        () {
          setState(() {
            _searchController.clear();
            _searchQuery = '';
          });
        },
      );
    });
  }

  Future<void> _handleBoardDeletion(Board board) async {
    final taskProvider = context.read<TaskProvider>();
    final boardProvider = context.read<BoardProvider>();
    
    // Check if board has tasks
    final boardTasks = taskProvider.tasks.where((task) => task.taskBoardId == board.boardId).toList();
    
    if (boardTasks.isEmpty) {
      // No tasks, proceed with deletion
      boardProvider.softDeleteBoard(board);
      return;
    }
    
    // Board has tasks, show dialog with options
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Board with Tasks'),
        content: Text(
          'This board has ${boardTasks.length} task(s). What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showMigrationDialog(board, boardTasks);
            },
            child: const Text('Migrate Tasks'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmDeleteBoardAndTasks(board, boardTasks);
            },
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showMigrationDialog(Board fromBoard, List<dynamic> tasksToMigrate) {
    final boardProvider = context.read<BoardProvider>();
    final otherBoards = boardProvider.boards
        .where((b) => b.boardId != fromBoard.boardId && !b.boardIsDeleted)
        .toList();
    
    if (otherBoards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other boards available to migrate tasks to')),
      );
      return;
    }
    
    Board? selectedBoard;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Destination Board'),
        content: StatefulBuilder(
          builder: (context, setState) => DropdownButton<Board>(
            isExpanded: true,
            hint: const Text('Choose a board'),
            value: selectedBoard,
            items: otherBoards.map((board) {
              return DropdownMenuItem<Board>(
                value: board,
                child: Text(board.boardTitle),
              );
            }).toList(),
            onChanged: (board) {
              setState(() {
                selectedBoard = board;
              });
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: selectedBoard == null
                ? null
                : () {
                    Navigator.pop(context);
                    _performMigration(fromBoard, selectedBoard!, tasksToMigrate);
                  },
            child: const Text('Migrate'),
          ),
        ],
      ),
    );
  }

  Future<void> _performMigration(Board fromBoard, Board toBoard, List<dynamic> tasksToMigrate) async {
    final taskProvider = context.read<TaskProvider>();
    final boardProvider = context.read<BoardProvider>();
    
    try {
      // Migrate each task to the new board
      for (var task in tasksToMigrate) {
        final migratedTask = task.copyWith(taskBoardId: toBoard.boardId);
        await taskProvider.updateTask(migratedTask);
      }
      
      // Delete the board
      boardProvider.softDeleteBoard(fromBoard);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tasksToMigrate.length} task(s) migrated to ${toBoard.boardTitle}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error migrating tasks: $e')),
        );
      }
    }
  }

  void _confirmDeleteBoardAndTasks(Board board, List<dynamic> tasksToDelete) {
    final taskProvider = context.read<TaskProvider>();
    final boardProvider = context.read<BoardProvider>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to delete this board and all ${tasksToDelete.length} task(s)?'
          '\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTasksAndBoard(board, tasksToDelete, taskProvider, boardProvider);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTasksAndBoard(
    Board board,
    List<dynamic> tasksToDelete,
    dynamic taskProvider,
    dynamic boardProvider,
  ) async {
    try {
      // Delete all tasks
      for (var task in tasksToDelete) {
        await taskProvider.deleteTask(task.taskId);
      }
      
      // Delete the board
      boardProvider.softDeleteBoard(board);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Board and ${tasksToDelete.length} task(s) deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting board: $e')),
        );
      }
    }
  }

  List<Board> _filterBoards(List<Board> boards) {
    if (_searchQuery.isEmpty) return boards;
    return boards.where((board) {
      final titleMatch = board.boardTitle.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final descMatch = (board.boardGoalDescription ?? '').toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      return titleMatch || descMatch;
    }).toList();
  }

  List<Board> _sortBoards(List<Board> boards) {
    // Sort so "Personal" is always first (case-insensitive)
    try {
      final personalBoard = boards.firstWhere(
        (b) => b.boardTitle.toLowerCase() == 'personal',
      );
      final otherBoards = boards.where((b) => b.boardTitle.toLowerCase() != 'personal').toList();
      return [personalBoard, ...otherBoards];
    } catch (e) {
      // Personal board doesn't exist, return as is
      return boards;
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[DEBUG] BoardsPage: build called. userId = $_userId');
    if (_userId == null) {
      print('[DEBUG] BoardsPage: User not logged in.');
      return const Center(child: Text('User not logged in.'));
    }

    return Scaffold(
      body: _userId == null
          ? const Center(child: Text('User not logged in.'))
          : Consumer<BoardProvider>(
              builder: (context, boardProvider, child) {
                if (boardProvider.isLoading) {
                  print(
                    '[DEBUG] BoardsPage: BoardProvider is loading boards...',
                  );
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredBoards = _sortBoards(_filterBoards(boardProvider.boards));

                if (filteredBoards.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No boards found',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try a different search term',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                if (boardProvider.boards.isEmpty) {
                  print('[DEBUG] BoardsPage: No boards assigned.');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.dashboard,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'You have no boards!',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Press '),
                            Icon(Icons.add, color: Colors.blue),
                            const Text(' to create a board!'),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredBoards.length,
                  itemBuilder: (context, index) {
                    final board = filteredBoards[index];
                    return Column(
                      children: [
                        BoardCard(
                          board: board,
                          onTap: () {
                            print(
                              '[DEBUG] BoardsPage: BoardCard tapped. boardId = ${board.boardId}',
                            );
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    BoardDetailsPage(board: board),
                              ),
                            );
                          },
                          onDelete: () {
                            print(
                              '[DEBUG] BoardsPage: Deleting board. boardId = ${board.boardId}',
                            );
                            _handleBoardDeletion(board);
                          },
                        ),
                        // Add divider after Personal board
                        if (board.boardTitle.toLowerCase() == 'personal')
                          Divider(
                            height: 16,
                            thickness: 1,
                            color: Colors.grey[300],
                          ),
                      ],
                    );
                  },
                );
              },
            ),
      floatingActionButton: AddBoardButton(userId: _userId!),
    );
  }
}
