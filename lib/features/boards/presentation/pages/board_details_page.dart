import 'package:flutter/material.dart';
import '../../datasources/models/board_model.dart';
import '../../../../shared/presentation/widgets/app_top_bar.dart';
import '../../../../shared/presentation/widgets/app_bottom_navigation.dart';
import '../../../../shared/presentation/widgets/app_side_menu.dart';
import '../../../../shared/datasources/providers/navigation_provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/sections/board_details_section.dart';
import '../widgets/sections/board_tasks_section.dart';
import '../widgets/sections/board_stats_section.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../datasources/providers/board_stats_provider.dart';
import '../widgets/dialogs/edit_board_dialog.dart';
import '../widgets/dialogs/board_delete_flow_dialog.dart';

class BoardDetailsPage extends StatefulWidget {
  final Board board;

  const BoardDetailsPage({super.key, required this.board});

  @override
  State<BoardDetailsPage> createState() => _BoardDetailsPageState();
}

class _BoardDetailsPageState extends State<BoardDetailsPage> {
  bool _showStats = false;
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().streamTasksByBoard(widget.board.boardId);
      context.read<BoardStatsProvider>().streamStatsForBoard(
        widget.board.boardId,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (!_isSearchExpanded) {
        _searchController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<NavigationProvider>();
    final currentUserId = context.watch<UserProvider>().userId;
    final isManager = currentUserId == widget.board.boardManagerId;

    return Scaffold(
      appBar: AppTopBar(
        title: 'Board Details',
        showBackButton: true,
        onBackPressed: () => Navigator.pop(context),
        showNotificationButton: false,
        isSearchExpanded: _isSearchExpanded,
        searchController: _searchController,
        onSearchPressed: _toggleSearch,
        onSearchChanged: (_) {},
        onSearchClear: () {
          setState(() {
            _searchController.clear();
          });
        },
        customActions: [
          if (!_isSearchExpanded) ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _toggleSearch,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'edit') {
                  showDialog(
                    context: context,
                    builder: (_) => EditBoardDialog(board: widget.board),
                  );
                } else if (value == 'delete') {
                  BoardDeleteFlowDialog.show(context, board: widget.board);
                }
              },
              itemBuilder: (context) => [
                if (isManager)
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Text('Edit'),
                  ),
                if (isManager)
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ],
        ],
      ),
      drawer: AppSideMenu(
        onSelect: (sideMenuIndex) {
          navigation.selectFromSideMenu(sideMenuIndex + 4);
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          context.read<TaskProvider>().streamTasksByBoard(widget.board.boardId);
          context.read<BoardStatsProvider>().streamStatsForBoard(
            widget.board.boardId,
          );
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Board Details Section
              BoardDetailsSection(
                boardId: widget.board.boardId,
                showStats: _showStats,
                onStatsToggle: (value) {
                  setState(() {
                    _showStats = value;
                  });
                },
              ),

              // Conditional rendering - Tasks or Stats
              if (!_showStats) ...[
                // Board Tasks Section
                BoardTasksSection(
                  boardId: widget.board.boardId,
                  board: widget.board,
                ),
              ] else ...[
                // Board Stats Section
                BoardStatsSection(
                  boardId: widget.board.boardId,
                  board: widget.board,
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: navigation.bottomNavIndex ?? 0,
        onTap: (index) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          navigation.selectFromBottomNav(index);
        },
      ),
    );
  }
}
