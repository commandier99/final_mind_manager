import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../datasources/providers/board_provider.dart';
import '../../datasources/providers/board_stats_provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../widgets/cards/board_card.dart';
import '../widgets/dialogs/add_board_button.dart';
import '../widgets/dialogs/board_delete_flow_dialog.dart';
import '../controllers/boards_query_controller.dart';
import 'board_details_page.dart';

class BoardsPage extends StatefulWidget {
  final void Function(VoidCallback)? onSearchToggleReady;
  final void Function(
    bool,
    TextEditingController,
    ValueChanged<String>,
    VoidCallback,
  )?
  onSearchStateChanged;
  final void Function(VoidCallback)? onFilterPressedReady;
  final void Function(VoidCallback)? onSortPressedReady;

  const BoardsPage({
    super.key,
    this.onSearchToggleReady,
    this.onSearchStateChanged,
    this.onFilterPressedReady,
    this.onSortPressedReady,
  });

  @override
  State<BoardsPage> createState() => _BoardsPageState();
}

class _BoardsPageState extends State<BoardsPage> {
  final BoardsQueryController _queryController = BoardsQueryController();
  String? _userId;
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _selectedFilters = {BoardsQueryController.allFilter};
  String _sortBy = 'created_desc';

  @override
  void initState() {
    super.initState();
    widget.onSearchToggleReady?.call(_toggleSearch);
    widget.onFilterPressedReady?.call(_showFilterMenu);
    widget.onSortPressedReady?.call(_showSortMenu);
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshBoardsAndStats();
      });
    }
  }

  Future<void> _refreshBoardsAndStats() async {
    final boardProvider = context.read<BoardProvider>();
    final statsProvider = context.read<BoardStatsProvider>();
    await boardProvider.refreshBoards();
    for (final board in boardProvider.boards) {
      statsProvider.streamStatsForBoard(board.boardId);
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
        (value) => setState(() => _searchQuery = value),
        () {
          setState(() {
            _searchController.clear();
            _searchQuery = '';
          });
        },
      );
    });
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        var tempFilters = Set<String>.from(_selectedFilters);

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter boards',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: BoardsQueryController.allFilters.map((filter) {
                        final isSelected = tempFilters.contains(filter);
                        return FilterChip(
                          label: Text(_queryController.getFilterLabel(filter)),
                          selected: isSelected,
                          onSelected: (selected) {
                            setSheetState(() {
                              if (selected) {
                                tempFilters = _queryController.addFilter(
                                  selectedFilters: tempFilters,
                                  filter: filter,
                                );
                              } else {
                                tempFilters = _queryController.removeFilter(
                                  selectedFilters: tempFilters,
                                  filter: filter,
                                );
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedFilters = tempFilters;
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sort boards',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildSortOption('Alphabetical (A-Z)', 'alphabetical_asc'),
                _buildSortOption('Alphabetical (Z-A)', 'alphabetical_desc'),
                _buildSortOption('Created (Newest)', 'created_desc'),
                _buildSortOption('Created (Oldest)', 'created_asc'),
                _buildSortOption('Modified (Newest)', 'modified_desc'),
                _buildSortOption('Modified (Oldest)', 'modified_asc'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String label, String value) {
    final isSelected = _sortBy == value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () {
        setState(() {
          _sortBy = value;
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSelectedFiltersRow() {
    final filters = _selectedFilters
        .where((f) => f != BoardsQueryController.allFilter)
        .toList();
    if (filters.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InputChip(
                label: Text(_queryController.getFilterLabel(filter)),
                onDeleted: () {
                  setState(() {
                    _selectedFilters = _queryController.removeFilter(
                      selectedFilters: _selectedFilters,
                      filter: filter,
                    );
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(body: Center(child: Text('User not logged in.')));
    }

    return Scaffold(
      body: Consumer<BoardProvider>(
        builder: (context, boardProvider, child) {
          Widget wrapWithRefresh(Widget content) {
            if (content is ScrollView) {
              return RefreshIndicator(
                onRefresh: _refreshBoardsAndStats,
                child: content,
              );
            }

            return RefreshIndicator(
              onRefresh: _refreshBoardsAndStats,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: content,
                  ),
                ],
              ),
            );
          }

          if (boardProvider.isLoading) {
            return wrapWithRefresh(
              const Center(child: CircularProgressIndicator()),
            );
          }

          final displayBoards = _queryController.applyQuery(
            boards: boardProvider.boards,
            searchQuery: _searchQuery,
            selectedFilters: _selectedFilters,
            sortBy: _sortBy,
          );

          if (displayBoards.isEmpty && _searchQuery.isNotEmpty) {
            return wrapWithRefresh(
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
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
              ),
            );
          }

          if (boardProvider.boards.isEmpty) {
            return wrapWithRefresh(
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.dashboard, size: 64, color: Colors.grey[400]),
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
                        Icon(Icons.add, color: Colors.blue[600]),
                        const Text(' to create a board!'),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }

          return wrapWithRefresh(
            ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildSelectedFiltersRow(),
                ...displayBoards.map((board) {
                  return Column(
                    children: [
                      BoardCard(
                        board: board,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  BoardDetailsPage(board: board),
                            ),
                          );
                        },
                        onDelete: _userId == board.boardManagerId
                            ? () => BoardDeleteFlowDialog.show(
                                context,
                                board: board,
                              )
                            : null,
                      ),
                      if (board.boardTitle.toLowerCase() == 'personal')
                        Divider(
                          height: 16,
                          thickness: 1,
                          color: Colors.grey[300],
                        ),
                    ],
                  );
                }),
              ],
            ),
          );
        },
      ),
      floatingActionButton: AddBoardButton(userId: _userId!),
    );
  }
}
