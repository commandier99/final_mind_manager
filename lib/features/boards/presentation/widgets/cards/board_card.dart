import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../../../datasources/models/board_model.dart';
import '../../../datasources/providers/board_stats_provider.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';

class BoardCard extends StatefulWidget {
  final Board board;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  const BoardCard({
    super.key,
    required this.board,
    this.onTap,
    this.onEdit,
    this.onDuplicate,
    this.onDelete,
  });

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
      if (!mounted) return;
      setState(() {
        _profilePictureCache[memberId] = profilePicture;
      });
    }
  }

  @override
  void didPushNext() {
    Slidable.of(context)?.close();
    super.didPushNext();
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.onEdit != null;
    final canDuplicate = widget.onDuplicate != null;
    final canDelete = widget.onDelete != null;
    final hasActions = canEdit || canDuplicate || canDelete;
    final variant = _BoardVariant.fromBoard(widget.board);
    final colors = _variantColors(variant);

    return Consumer<BoardStatsProvider>(
      builder: (context, statsProvider, _) {
        final stats =
            statsProvider.getStatsForBoard(widget.board.boardId) ??
            widget.board.stats;
        final taskDone = stats.boardTasksDoneCount;
        final taskTotal = stats.boardTasksCount;
        final progress = taskTotal > 0 ? taskDone / taskTotal : 0.0;
        final percent = taskTotal > 0 ? (progress * 100).round() : 0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Slidable(
            key: ValueKey(widget.board.boardId),
            endActionPane: variant == _BoardVariant.defaultPersonal || !hasActions
                ? null
                : ActionPane(
                    motion: const ScrollMotion(),
                    extentRatio:
                        (canEdit ? 0.25 : 0) +
                        (canDuplicate ? 0.25 : 0) +
                        (canDelete ? 0.25 : 0),
                    children: [
                      if (canEdit)
                        Expanded(
                          child: Container(
                            alignment: Alignment.center,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.amber.shade500,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: widget.onEdit,
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.edit, color: Colors.white, size: 20),
                                      SizedBox(height: 2),
                                      Text(
                                        'Edit',
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
                      if (canDuplicate)
                        Expanded(
                          child: Container(
                            alignment: Alignment.center,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade500,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: widget.onDuplicate,
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.copy,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Duplicate',
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
                      if (canDelete)
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
                  Slidable.of(context)?.close();
                  widget.onTap?.call();
                },
                child: Card(
                  margin: EdgeInsets.zero,
                  elevation: 5,
                  shadowColor: colors.primary.withValues(alpha: 0.25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colors.border, width: 1.2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: variant == _BoardVariant.defaultPersonal
                        ? _buildDefaultPersonalBoard(colors, progress, percent)
                        : _buildVariantBoard(variant, colors, progress, percent),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultPersonalBoard(
    _BoardPalette colors,
    double progress,
    int percent,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.header, colors.primary],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Personal HQ',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.board.boardGoalDescription.isNotEmpty
                  ? widget.board.boardGoalDescription
                  : 'Your private command center for daily focus.',
              style: const TextStyle(color: Colors.white, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Default Personal Board',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantBoard(
    _BoardVariant variant,
    _BoardPalette colors,
    double progress,
    int percent,
  ) {
    final isTeam = variant == _BoardVariant.teamProject ||
        variant == _BoardVariant.teamCategory;
    final showProgress = variant == _BoardVariant.teamProject ||
        variant == _BoardVariant.personalProject;

    return Container(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.header, colors.primary],
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _variantIcon(variant),
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.board.boardTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _variantLabel(variant).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'by ${widget.board.boardManagerName}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.board.boardGoal.isNotEmpty &&
                          widget.board.boardPurpose == 'project') ...[
                        Text(
                          widget.board.boardGoal,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        widget.board.boardGoalDescription.isNotEmpty
                            ? widget.board.boardGoalDescription
                            : 'No description',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (isTeam)
                        _buildMembersRow(widget.board)
                      else
                        Text(
                          'Solo board',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (showProgress) ...[
                  const SizedBox(width: 12),
                  _buildProgressRing(progress, percent, colors.primary),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersRow(Board board) {
    final visibleMembers = board.memberIds.take(3).toList();
    if (visibleMembers.isEmpty) {
      return Text(
        'No members',
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      );
    }

    return SizedBox(
      width: 78,
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
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 10,
                  backgroundImage: _profilePictureCache[memberId] != null
                      ? NetworkImage(_profilePictureCache[memberId]!)
                      : null,
                  backgroundColor: Colors.grey[300],
                  child: _profilePictureCache[memberId] == null
                      ? const Icon(Icons.person, size: 8, color: Colors.grey)
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
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.black87,
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
  }

  Widget _buildProgressRing(double progress, int percent, Color color) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            backgroundColor: Colors.grey.shade300,
            color: progress == 1.0 ? Colors.green : color,
          ),
          Text(
            '$percent%',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  IconData _variantIcon(_BoardVariant variant) {
    switch (variant) {
      case _BoardVariant.defaultPersonal:
        return Icons.auto_awesome;
      case _BoardVariant.teamProject:
        return Icons.groups_2_outlined;
      case _BoardVariant.teamCategory:
        return Icons.hub_outlined;
      case _BoardVariant.personalProject:
        return Icons.rocket_launch_outlined;
      case _BoardVariant.personalCategory:
        return Icons.folder_open_outlined;
    }
  }

  String _variantLabel(_BoardVariant variant) {
    switch (variant) {
      case _BoardVariant.defaultPersonal:
        return 'Personal Default';
      case _BoardVariant.teamProject:
        return 'Team Project';
      case _BoardVariant.teamCategory:
        return 'Team Category';
      case _BoardVariant.personalProject:
        return 'Personal Project';
      case _BoardVariant.personalCategory:
        return 'Personal Category';
    }
  }

  _BoardPalette _variantColors(_BoardVariant variant) {
    switch (variant) {
      case _BoardVariant.defaultPersonal:
        return _BoardPalette(
          primary: const Color(0xFF206A5D),
          header: const Color(0xFF2A9D8F),
          border: const Color(0xFF6CB7AD),
          surface: const Color(0xFFE8F4F2),
        );
      case _BoardVariant.teamProject:
        return _BoardPalette(
          primary: const Color(0xFFCC6A00),
          header: const Color(0xFFE07A00),
          border: const Color(0xFFE9B26B),
          surface: const Color(0xFFFFF4E8),
        );
      case _BoardVariant.teamCategory:
        return _BoardPalette(
          primary: const Color(0xFF2E7D32),
          header: const Color(0xFF3FA744),
          border: const Color(0xFF8BCA8E),
          surface: const Color(0xFFEDF8EE),
        );
      case _BoardVariant.personalProject:
        return _BoardPalette(
          primary: const Color(0xFF415A77),
          header: const Color(0xFF4B6A8A),
          border: const Color(0xFF8AA0B8),
          surface: const Color(0xFFEFF3F7),
        );
      case _BoardVariant.personalCategory:
        return _BoardPalette(
          primary: const Color(0xFF7A5C28),
          header: const Color(0xFF92713A),
          border: const Color(0xFFB79C6A),
          surface: const Color(0xFFF8F2E8),
        );
    }
  }
}

class _BoardPalette {
  final Color primary;
  final Color header;
  final Color border;
  final Color surface;

  const _BoardPalette({
    required this.primary,
    required this.header,
    required this.border,
    required this.surface,
  });
}

enum _BoardVariant {
  defaultPersonal,
  teamProject,
  teamCategory,
  personalProject,
  personalCategory;

  static _BoardVariant fromBoard(Board board) {
    final type = board.boardType.toLowerCase();
    final purpose = board.boardPurpose.toLowerCase();
    final isDefaultPersonal =
        type == 'personal' && board.boardTitle.toLowerCase() == 'personal';

    if (isDefaultPersonal) return _BoardVariant.defaultPersonal;
    if (type == 'team' && purpose == 'project') return _BoardVariant.teamProject;
    if (type == 'team') return _BoardVariant.teamCategory;
    if (purpose == 'project') return _BoardVariant.personalProject;
    return _BoardVariant.personalCategory;
  }
}
