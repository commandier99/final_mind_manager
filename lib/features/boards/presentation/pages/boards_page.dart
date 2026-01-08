import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../datasources/models/board_model.dart';
import '../../datasources/providers/board_provider.dart';
import '../../datasources/providers/board_stats_provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../../shared/features/search/providers/search_provider.dart';
import '../widgets/cards/board_card.dart';
import '../widgets/dialogs/add_board_button.dart';
import '../widgets/board_search_bar.dart';
import 'board_details_page.dart';

class BoardsPage extends StatefulWidget {
  const BoardsPage({super.key});

  @override
  State<BoardsPage> createState() => _BoardsPageState();
}

class _BoardsPageState extends State<BoardsPage> {
  String? _userId;

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

  @override
  Widget build(BuildContext context) {
    print('[DEBUG] BoardsPage: build called. userId = $_userId');
    if (_userId == null) {
      print('[DEBUG] BoardsPage: User not logged in.');
      return const Center(child: Text('User not logged in.'));
    }

    return Scaffold(
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: _userId != null
                ? BoardSearchBar(userId: _userId!)
                : const SizedBox.shrink(),
          ),
          // All Boards
          Expanded(
            child: _userId == null
                ? const Center(child: Text('User not logged in.'))
                : Consumer2<BoardProvider, SearchProvider>(
                    builder: (context, boardProvider, searchProvider, child) {
                      // Determine which boards to display
                      List<Board> boardsToDisplay = [];

                      if (searchProvider.query.isNotEmpty) {
                        // Use search results if searching
                        boardsToDisplay = searchProvider.boardResults;
                      } else {
                        // Use all boards from provider
                        boardsToDisplay = boardProvider.boards;
                      }

                      if (boardProvider.isLoading) {
                        print(
                          '[DEBUG] BoardsPage: BoardProvider is loading boards...',
                        );
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (boardsToDisplay.isEmpty) {
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
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
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
                        '[DEBUG] BoardsPage: Building ListView with ${boardsToDisplay.length} boards.',
                      );
                      return ListView.builder(
                        itemCount: boardsToDisplay.length,
                        itemBuilder: (context, index) {
                          final board = boardsToDisplay[index];
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
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AddBoardButton(userId: _userId!),
        ],
      ),
    );
  }
}
