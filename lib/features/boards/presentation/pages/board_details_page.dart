import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../widgets/sections/board_submissions_section.dart';
import '../../../tasks/datasources/providers/task_provider.dart';
import '../../datasources/providers/board_provider.dart';
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
  static const String _lastVisitedBoardIdKey = 'home_last_visited_board_id';
  static const String _lastVisitedBoardTitleKey =
      'home_last_visited_board_title';
  static const String _lastVisitedBoardAtKey = 'home_last_visited_board_at';

  static const String _tabDrafts = 'drafts';
  static const String _tabPublished = 'published';
  static const String _tabStats = 'stats';
  static const String _tabSubmissions = 'submissions';

  bool _isSearchExpanded = false;
  bool _isDetailsPanelExpanded = true;
  String _selectedTab = _tabPublished;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _persistLastVisitedBoard();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().streamTasksByBoard(widget.board.boardId);
      context.read<BoardStatsProvider>().streamStatsForBoard(
        widget.board.boardId,
      );
    });
  }

  Future<void> _persistLastVisitedBoard() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null || userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_lastVisitedBoardIdKey}_$userId',
      widget.board.boardId,
    );
    await prefs.setString(
      '${_lastVisitedBoardTitleKey}_$userId',
      widget.board.boardTitle,
    );
    await prefs.setInt(
      '${_lastVisitedBoardAtKey}_$userId',
      DateTime.now().millisecondsSinceEpoch,
    );
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

  void _toggleDetailsPanel() {
    setState(() {
      _isDetailsPanelExpanded = !_isDetailsPanelExpanded;
    });
  }

  Future<void> _duplicateBoard() async {
    if (widget.board.boardType == 'personal') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Personal boards cannot be duplicated.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await context.read<BoardProvider>().duplicateBoard(widget.board);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Duplicated "${widget.board.boardTitle}"')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to duplicate board: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<NavigationProvider>();
    final currentUserId = context.watch<UserProvider>().userId;
    final isManager = widget.board.isManager(currentUserId);
    final canDraftTasks = widget.board.canDraftTasks(currentUserId);
    final canViewSubmissionsTab =
        currentUserId != null &&
        widget.board.canReviewSubmissions(currentUserId);
    final showDraftsTab = canDraftTasks && widget.board.boardType == 'team';
    final showReviewTab =
        canViewSubmissionsTab &&
        widget.board.boardType == 'team' &&
        widget.board.boardPurpose != 'category';

    if (!showDraftsTab && _selectedTab == _tabDrafts) {
      _selectedTab = _tabPublished;
    }
    if (!showReviewTab && _selectedTab == _tabSubmissions) {
      _selectedTab = _tabPublished;
    }

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
            IconButton(
              icon: Icon(
                _isDetailsPanelExpanded ? Icons.expand_less : Icons.expand_more,
              ),
              tooltip: _isDetailsPanelExpanded
                  ? 'Hide board details'
                  : 'Show board details',
              onPressed: _toggleDetailsPanel,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'edit') {
                  showDialog(
                    context: context,
                    builder: (_) => EditBoardDialog(board: widget.board),
                  );
                } else if (value == 'duplicate') {
                  _duplicateBoard();
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
                if (isManager && widget.board.boardType != 'personal')
                  const PopupMenuItem<String>(
                    value: 'duplicate',
                    child: Text('Duplicate'),
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
          navigation.selectFromSideMenu(sideMenuIndex);
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
              Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      child: _isDetailsPanelExpanded
                          ? BoardDetailsSection(boardId: widget.board.boardId)
                          : const SizedBox.shrink(),
                    ),
                    GestureDetector(
                      onTap: _toggleDetailsPanel,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 2,
                          horizontal: 16,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          children: [
                            Expanded(
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: Colors.grey[300],
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Icon(
                                _isDetailsPanelExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                key: ValueKey(_isDetailsPanelExpanded),
                                color: Colors.grey[600],
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: Colors.grey[300],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(
                  children: [
                    if (showDraftsTab)
                      Expanded(
                        child: _buildViewTab(
                          label: 'Drafts',
                          selected: _selectedTab == _tabDrafts,
                          onTap: () =>
                              setState(() => _selectedTab = _tabDrafts),
                        ),
                      ),
                    if (showDraftsTab) const SizedBox(width: 8),
                    Expanded(
                      child: _buildViewTab(
                        label: showDraftsTab ? 'Published' : 'Tasks',
                        selected: _selectedTab == _tabPublished,
                        onTap: () =>
                            setState(() => _selectedTab = _tabPublished),
                      ),
                    ),
                    if (showReviewTab) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildViewTab(
                          label: 'Submissions',
                          selected: _selectedTab == _tabSubmissions,
                          onTap: () =>
                              setState(() => _selectedTab = _tabSubmissions),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildViewTab(
                        label: 'Stats',
                        selected: _selectedTab == _tabStats,
                        onTap: () => setState(() => _selectedTab = _tabStats),
                      ),
                    ),
                  ],
                ),
              ),
              if (_selectedTab == _tabStats)
                BoardStatsSection(
                  boardId: widget.board.boardId,
                  board: widget.board,
                )
              else if (_selectedTab == _tabSubmissions)
                BoardSubmissionsSection(boardId: widget.board.boardId)
              else
                BoardTasksSection(
                  boardId: widget.board.boardId,
                  board: widget.board,
                  selectedLane: _selectedTab,
                ),
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

  Widget _buildViewTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? Colors.blue : Colors.grey[300]!,
              width: selected ? 2 : 1,
            ),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.blue[700] : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}
