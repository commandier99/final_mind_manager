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
  static const String _tabWorkshop = 'workshop';
  static const String _tabBillboard = 'billboard';
  static const String _tabStats = 'stats';

  bool _isSearchExpanded = false;
  bool _isDetailsPanelExpanded = true;
  String _selectedTab = _tabBillboard;
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

  void _toggleDetailsPanel() {
    setState(() {
      _isDetailsPanelExpanded = !_isDetailsPanelExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<NavigationProvider>();
    final currentUserId = context.watch<UserProvider>().userId;
    final isManager = currentUserId == widget.board.boardManagerId;
    final showWorkshopTab = isManager && widget.board.boardType == 'team';

    if (!showWorkshopTab && _selectedTab == _tabWorkshop) {
      _selectedTab = _tabBillboard;
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
                    if (showWorkshopTab)
                      Expanded(
                        child: _buildViewTab(
                          label: 'Drafts',
                          selected: _selectedTab == _tabWorkshop,
                          onTap: () =>
                              setState(() => _selectedTab = _tabWorkshop),
                        ),
                      ),
                    if (showWorkshopTab) const SizedBox(width: 8),
                    Expanded(
                      child: _buildViewTab(
                        label: showWorkshopTab ? 'Published' : 'Tasks',
                        selected: _selectedTab == _tabBillboard,
                        onTap: () =>
                            setState(() => _selectedTab = _tabBillboard),
                      ),
                    ),
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
              if (_selectedTab != _tabStats)
                BoardTasksSection(
                  boardId: widget.board.boardId,
                  board: widget.board,
                  selectedLane: _selectedTab,
                )
              else
                BoardStatsSection(
                  boardId: widget.board.boardId,
                  board: widget.board,
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
