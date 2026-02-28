import 'package:flutter/material.dart';
import '../../../datasources/providers/board_stats_provider.dart';
import '../../../datasources/providers/board_provider.dart';
import 'package:provider/provider.dart';
import 'board_members_section.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';

class BoardDetailsSection extends StatefulWidget {
  final String boardId;
  final bool showStats;
  final Function(bool) onStatsToggle;

  const BoardDetailsSection({
    super.key,
    required this.boardId,
    required this.showStats,
    required this.onStatsToggle,
  });

  @override
  State<BoardDetailsSection> createState() => _BoardDetailsSectionState();
}

class _BoardDetailsSectionState extends State<BoardDetailsSection> {
  bool _isGoalExpanded = false;
  bool _isDescriptionExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BoardStatsProvider>().streamStatsForBoard(widget.boardId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final currentUserId = userProvider.userId ?? '';

    return Consumer2<BoardStatsProvider, BoardProvider>(
      builder: (context, statsProvider, boardProvider, _) {
        // Find the board from the provider's board list
        final board = boardProvider.boards.firstWhere(
          (b) => b.boardId == widget.boardId,
          orElse: () => boardProvider.boards.first,
        );

        final stats = statsProvider.getStatsForBoard(board.boardId);
        final taskDone = stats?.boardTasksDoneCount ?? 0;
        final taskTotal = stats?.boardTasksCount ?? 0;
        final progress = taskTotal > 0 ? taskDone / taskTotal : 0.0;
        final percentage = taskTotal > 0
            ? (progress * 100).toStringAsFixed(1)
            : '0.0';

        return Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title with manager and icons
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: GestureDetector(
                            onTap: () {
                              if (board.boardTitle.isNotEmpty) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Board Title'),
                                    content: SingleChildScrollView(
                                      child: Text(board.boardTitle),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                            child: Text(
                              board.boardTitle,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'by ${board.boardManagerName}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      widget.showStats ? Icons.task : Icons.assessment,
                    ),
                    onPressed: () {
                      widget.onStatsToggle(!widget.showStats);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Goal label and content
              Text(
                'Goal:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    board.boardGoal.isEmpty ? 'No goal set' : board.boardGoal,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: _isGoalExpanded ? null : 2,
                    overflow: _isGoalExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                  ),
                  if (board.boardGoal.isNotEmpty && board.boardGoal.length > 80)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isGoalExpanded = !_isGoalExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _isGoalExpanded ? 'See less' : 'See more...',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Description label and content
              Text(
                'Description:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    board.boardGoalDescription.isEmpty
                        ? 'No description'
                        : board.boardGoalDescription,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: _isDescriptionExpanded ? null : 3,
                    overflow: _isDescriptionExpanded
                        ? TextOverflow.visible
                        : TextOverflow.ellipsis,
                  ),
                  if (board.boardGoalDescription.isNotEmpty &&
                      board.boardGoalDescription.length > 120)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isDescriptionExpanded = !_isDescriptionExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _isDescriptionExpanded ? 'See less' : 'See more...',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Progress',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress == 1.0 ? Colors.green : Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Board Members Section
              BoardMembersSection(
                memberIds: board.memberIds,
                boardId: board.boardId,
                currentUserId: currentUserId,
                board: board,
              ),
            ],
          ),
        );
      },
    );
  }
}
