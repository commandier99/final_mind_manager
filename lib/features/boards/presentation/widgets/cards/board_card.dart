import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../datasources/models/board_model.dart';
import '../../../datasources/providers/board_stats_provider.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';
import 'package:provider/provider.dart';

class BoardCard extends StatefulWidget {
  final Board board;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const BoardCard({super.key, required this.board, this.onTap, this.onDelete});

  @override
  State<BoardCard> createState() => _BoardCardState();
}

class _BoardCardState extends State<BoardCard> with RouteAware {
  final Map<String, String?> _profilePictureCache = {};

  @override
  void initState() {
    super.initState();
    _loadMemberProfilePictures();
  }

  @override
  void didUpdateWidget(BoardCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.board.memberIds != widget.board.memberIds) {
      _loadMemberProfilePictures();
    }
  }

  Future<void> _loadMemberProfilePictures() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    for (final memberId in widget.board.memberIds) {
      final profilePicture = await userProvider.getUserProfilePicture(memberId);
      if (mounted) {
        setState(() {
          _profilePictureCache[memberId] = profilePicture;
        });
      }
    }
  }

  @override
  void didPushNext() {
    // Close slidable when navigating to another page
    Slidable.of(context)?.close();
    super.didPushNext();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BoardStatsProvider>(
      builder: (context, statsProvider, _) {
        // Try to get stats from provider first, fallback to board.stats
        final stats =
            statsProvider.getStatsForBoard(widget.board.boardId) ?? widget.board.stats;

        final taskDone = stats.boardTasksDoneCount;
        final taskTotal = stats.boardTasksCount;
        final progress = taskTotal > 0 ? taskDone / taskTotal : 0.0;
        final percent = taskTotal > 0 ? (progress * 100).round() : 0;

        print(
          '[BoardCard] boardId: ${widget.board.boardId}, taskDone: $taskDone, taskTotal: $taskTotal, progress: $progress',
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Slidable(
            key: ValueKey(widget.board.boardId),
            endActionPane: widget.board.boardTitle == 'Personal'
                ? null // Personal board cannot be deleted
                : ActionPane(
              motion: const ScrollMotion(),
              extentRatio: 0.25,
              children: [
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onDelete,
                          borderRadius: BorderRadius.circular(8),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete, color: Colors.white, size: 20),
                              SizedBox(height: 2),
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: () {
                  // Close slidable before tapping on the card
                  Slidable.of(context)?.close();
                  widget.onTap?.call();
                },
                child: Card(
                margin: EdgeInsets.zero,
                elevation: 4,
                shadowColor: Colors.blue.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                  side: BorderSide(
                    color: Colors.blue.shade400,
                    width: 1,
                  ),
                ),
                child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with board name
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          color: Colors.blue.shade700,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.board.boardTitle,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "by ${widget.board.boardManagerName}",
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Body with description, members, and progress
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Left column: Description and Members
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Description
                                    Text(
                                      widget.board.boardDescription?.isNotEmpty ?? false
                                          ? widget.board.boardDescription!
                                          : "Description: None",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                        height: 1.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    // Members
                                    _buildMembersRow(widget.board),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Right: Circular progress indicator
                              _buildProgressIndicator(stats, progress, percent),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMembersRow(Board board) {
    final visibleMembers = board.memberIds.take(3).toList();

    if (visibleMembers.isEmpty) {
      return Text(
        'No members',
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[600],
        ),
      );
    }

    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        return SizedBox(
          width: 70,
          height: 24,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ...visibleMembers.asMap().entries.map((entry) {
                final index = entry.key;
                final offset = index * 16.0;
                final memberId = entry.value;

                return Positioned(
                  left: offset,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 10,
                      backgroundImage: _profilePictureCache[memberId] != null
                          ? NetworkImage(_profilePictureCache[memberId]!)
                          : null,
                      backgroundColor: Colors.grey[300],
                      child: _profilePictureCache[memberId] == null
                          ? const Icon(
                              Icons.person,
                              size: 8,
                              color: Colors.grey,
                            )
                          : null,
                    ),
                  ),
                );
              }),
              if (board.memberIds.length > 3)
                Positioned(
                  left: 3 * 16.0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.blue.shade600,
                      child: Text(
                        '+${board.memberIds.length - 3}',
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator(
      dynamic stats, double progress, int percent) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            backgroundColor: Colors.grey.shade300,
            color: progress == 1.0 ? Colors.green : Colors.blue,
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "$percent%",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
