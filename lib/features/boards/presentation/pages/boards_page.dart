import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../datasources/models/board_model.dart';
import '../../datasources/providers/board_provider.dart';
import '../../datasources/providers/board_stats_provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
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

                final filteredBoards = _filterBoards(boardProvider.boards);

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

                print(
                  '[DEBUG] BoardsPage: Building ListView with ${filteredBoards.length} boards.',
                );
                return ListView.builder(
                  itemCount: filteredBoards.length,
                  itemBuilder: (context, index) {
                    final board = filteredBoards[index];
                    return BoardCard(
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
                        boardProvider.softDeleteBoard(board);
                      },
                    );
                  },
                );
              },
            ),
      floatingActionButton: AddBoardButton(userId: _userId!),
    );
  }
}
