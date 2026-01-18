import 'package:flutter/material.dart';
import '../../datasources/models/board_model.dart';
import '../../../../shared/presentation/widgets/app_top_bar.dart';
import '../../../../shared/presentation/widgets/app_bottom_navigation.dart';
import '../../../../shared/presentation/widgets/app_side_menu.dart';
import '../../../../shared/datasources/providers/navigation_provider.dart';
import 'package:provider/provider.dart';
import '../widgets/sections/board_details_section.dart';
import '../widgets/sections/board_tasks_section.dart';
import '../widgets/sections/board_stats_section.dart';
import '../widgets/sections/volunteer_requests_widget.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../datasources/providers/board_stats_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    print('[DEBUG] BoardDetailsPage: initState called');
    print('[DEBUG] BoardDetailsPage: boardId = ${widget.board.boardId}');
    print('[DEBUG] BoardDetailsPage: boardTitle = ${widget.board.boardTitle}');
    print('[DEBUG] BoardDetailsPage: boardIsDeleted = ${widget.board.boardIsDeleted}');
    print('[DEBUG] BoardDetailsPage: widget.board = $widget.board');

    // Initialize streams after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Start streaming tasks for this board
      print('[DEBUG] BoardDetailsPage: calling streamTasksByBoard with boardId = ${widget.board.boardId}');
      context.read<TaskProvider>().streamTasksByBoard(widget.board.boardId);

      // Start streaming board stats
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
        _searchQuery = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    print(
      '[DEBUG] BoardDetailsPage: build called for boardId = ${widget.board.boardId}',
    );
    final navigation = context.watch<NavigationProvider>();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isManager = widget.board.boardManagerId == currentUserId;

    return Scaffold(
      appBar: AppTopBar(
        title: 'Board Details',
        showBackButton: true,
        onBackPressed: () => Navigator.pop(context),
        showNotificationButton: false,
        isSearchExpanded: _isSearchExpanded,
        searchController: _searchController,
        onSearchPressed: _toggleSearch,
        onSearchChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        onSearchClear: () {
          setState(() {
            _searchController.clear();
            _searchQuery = '';
          });
        },
        customActions: [
          if (!_isSearchExpanded) ...[        
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _toggleSearch,
            ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: const Text('Edit'),
                  onTap: () {
                    // TODO: Navigate to edit board page
                    print('[DEBUG] BoardDetailsPage: Edit tapped for boardId = ${widget.board.boardId}');
                  },
                ),
                PopupMenuItem(
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    // TODO: Implement board deletion
                    print('[DEBUG] BoardDetailsPage: Delete tapped for boardId = ${widget.board.boardId}');
                  },
                ),
              ],
            ),
          ],
        ],
      ),
      drawer: AppSideMenu(
        onSelect: (sideMenuIndex) {
          print(
            '[DEBUG] BoardDetailsPage: SideMenu selected index = $sideMenuIndex',
          );
          navigation.selectFromSideMenu(sideMenuIndex + 4);
        },
      ),
      body: SingleChildScrollView(
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
              // Volunteer Requests Section
              VolunteerRequestsWidget(
                boardId: widget.board.boardId,
                isManager: isManager,
              ),
              
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
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: navigation.bottomNavIndex ?? 0,
        onTap: (index) {
          print('[DEBUG] BoardDetailsPage: BottomNav tapped index = $index');
          // Pop back to main screen first, then navigate
          Navigator.of(context).popUntil((route) => route.isFirst);
          navigation.selectFromBottomNav(index);
        },
      ),
    );
  }
}
