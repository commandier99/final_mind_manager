import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/models/board_model.dart';
import '../../../datasources/models/board_stats_model.dart';
import '../../../datasources/providers/board_stats_provider.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../../../shared/features/users/datasources/services/user_services.dart';
import 'board_activity_section.dart';

class BoardStatsSection extends StatefulWidget {
  final String boardId;
  final Board board;

  const BoardStatsSection({
    super.key,
    required this.boardId,
    required this.board,
  });

  @override
  State<BoardStatsSection> createState() => _BoardStatsSectionState();
}

class _BoardStatsSectionState extends State<BoardStatsSection> {
  final UserService _userService = UserService();
  Map<String, String> _memberNamesById = const {};

  @override
  void initState() {
    super.initState();
    _loadMemberNames();
  }

  @override
  void didUpdateWidget(covariant BoardStatsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.board.boardId != widget.board.boardId ||
        oldWidget.board.memberIds.join(',') != widget.board.memberIds.join(',') ||
        oldWidget.board.boardManagerId != widget.board.boardManagerId) {
      _loadMemberNames();
    }
  }

  Future<void> _loadMemberNames() async {
    final ids = <String>{...widget.board.memberIds, widget.board.boardManagerId}
        .where((id) => id.trim().isNotEmpty)
        .toList();
    if (ids.isEmpty) return;

    final resolved = <String, String>{};
    for (final id in ids) {
      try {
        final user = await _userService.getUserById(id);
        final name = user?.userName.trim();
        if (name != null && name.isNotEmpty) {
          resolved[id] = name;
        }
      } catch (_) {
        // Best-effort enrichment only.
      }
    }

    if (!mounted) return;
    setState(() {
      _memberNamesById = resolved;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BoardStatsProvider, TaskProvider>(
      builder: (context, statsProvider, taskProvider, _) {
        final currentUserId = context.watch<UserProvider>().userId;
        final canSeeTeamPanel =
            widget.board.isManager(currentUserId) ||
            widget.board.isSupervisor(currentUserId);
        final stats =
            statsProvider.getStatsForBoard(widget.boardId) ?? BoardStats();
        final boardTasks = taskProvider.tasks
            .where(
              (task) =>
                  task.taskBoardId == widget.boardId && !task.taskIsDeleted,
            )
            .toList();
        final successfulTasks = boardTasks
            .where(
              (task) => task.effectiveTaskOutcome == Task.outcomeSuccessful,
            )
            .length;
        final failedTasks = boardTasks
            .where((task) => task.effectiveTaskOutcome == Task.outcomeFailed)
            .length;

        final totalTasks = stats.boardTasksCount;
        final doneTasks = stats.boardTasksDoneCount;
        final deletedTasks = stats.boardTasksDeletedCount;
        final activeTasks = (totalTasks - deletedTasks).clamp(0, totalTasks);

        final totalSteps = stats.boardStepsCount;
        final doneSteps = stats.boardStepsDoneCount;
        final deletedSteps = stats.boardStepsDeletedCount;

        final completionRate = totalTasks > 0 ? doneTasks / totalTasks : 0.0;
        final completionLabel = '${(completionRate * 100).toStringAsFixed(0)}%';
        final memberPerf = _computeMemberPerformance(boardTasks);
        final myPerf = memberPerf[currentUserId];
        final ranking = memberPerf.values.toList()
          ..sort((a, b) {
            final scoreCompare = b.productivityScore.compareTo(
              a.productivityScore,
            );
            if (scoreCompare != 0) return scoreCompare;
            return b.completionRate.compareTo(a.completionRate);
          });
        final myRank = myPerf == null
            ? null
            : ranking.indexWhere((p) => p.memberId == myPerf.memberId) + 1;
        final overloadedCount = memberPerf.values
            .where(
              (perf) =>
                  perf.taskLimit > 0 && perf.activeTasks >= perf.taskLimit,
            )
            .length;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Board Stats',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Progress snapshot for ${widget.board.boardTitle}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryCard(
                      context: context,
                      completionRate: completionRate,
                      completionLabel: completionLabel,
                      doneTasks: doneTasks,
                      totalTasks: totalTasks,
                      activeTasks: activeTasks,
                    ),
                    const SizedBox(height: 12),
                    if (myPerf != null) ...[
                      _buildMyPerformancePanel(
                        context: context,
                        perf: myPerf,
                        rank: myRank,
                        teamSize: ranking.length,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildMetricTile(
                          label: 'Total Tasks',
                          value: '$totalTasks',
                          icon: Icons.checklist,
                          color: Colors.blue,
                        ),
                        _buildMetricTile(
                          label: 'Completed',
                          value: '$doneTasks',
                          icon: Icons.task_alt,
                          color: Colors.green,
                        ),
                        _buildMetricTile(
                          label: 'Successful',
                          value: '$successfulTasks',
                          icon: Icons.workspace_premium_outlined,
                          color: Colors.teal,
                        ),
                        _buildMetricTile(
                          label: 'Failed',
                          value: '$failedTasks',
                          icon: Icons.cancel_outlined,
                          color: Colors.redAccent,
                        ),
                        _buildMetricTile(
                          label: 'Deleted',
                          value: '$deletedTasks',
                          icon: Icons.delete_outline,
                          color: Colors.red,
                        ),
                        _buildMetricTile(
                          label: 'Steps',
                          value: '$totalSteps',
                          icon: Icons.format_list_bulleted,
                          color: Colors.indigo,
                        ),
                        _buildMetricTile(
                          label: 'Steps Done',
                          value: '$doneSteps',
                          icon: Icons.done_all,
                          color: Colors.teal,
                        ),
                        _buildMetricTile(
                          label: 'Steps Deleted',
                          value: '$deletedSteps',
                          icon: Icons.remove_done,
                          color: Colors.deepOrange,
                        ),
                        _buildMetricTile(
                          label: 'Messages',
                          value: '${stats.boardMessageCount}',
                          icon: Icons.forum_outlined,
                          color: Colors.purple,
                        ),
                        _buildMetricTile(
                          label: 'Overloaded',
                          value: '$overloadedCount',
                          icon: Icons.balance_outlined,
                          color: Colors.deepOrange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (canSeeTeamPanel) ...[
                      _buildTeamRankingPanel(
                        context: context,
                        ranking: ranking,
                      ),
                    ] else if (myPerf != null) ...[
                      _buildMemberRankHint(
                        context: context,
                        rank: myRank ?? 0,
                        teamSize: ranking.length,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Divider(color: Colors.grey[300], height: 1),
              ),
              const SizedBox(height: 8),
              BoardActivitySection(boardId: widget.boardId),
            ],
          ),
        );
      },
    );
  }

  Map<String, _MemberPerformance> _computeMemberPerformance(List<Task> tasks) {
    final memberIds = <String>{
      ...widget.board.memberIds,
      widget.board.boardManagerId,
    };
    final byMember = <String, _MemberPerformance>{};

    for (final memberId in memberIds) {
      final assigned = tasks
          .where(
            (task) => task.taskAssignedTo == memberId && !task.taskIsDeleted,
          )
          .toList();
      final completed = assigned.where((task) => task.taskIsDone).length;
      final active = assigned.where((task) => !task.taskIsDone).length;
      final successful = assigned
          .where((task) => task.effectiveTaskOutcome == Task.outcomeSuccessful)
          .length;
      final failed = assigned
          .where((task) => task.effectiveTaskOutcome == Task.outcomeFailed)
          .length;
      final onTimeDone = assigned.where((task) {
        if (!task.taskIsDone) return false;
        if (task.taskDeadline == null || task.taskIsDoneAt == null) return true;
        return !task.taskIsDoneAt!.isAfter(task.taskDeadline!);
      }).length;
      final completionRate = assigned.isEmpty
          ? 0.0
          : completed / assigned.length;
      final onTimeRate = completed == 0 ? 0.0 : onTimeDone / completed;
      final score =
          (successful * 3) +
          (completed * 2) +
          onTimeDone -
          (failed * 2) -
          active;
      final displayName = _resolveMemberDisplayName(memberId, tasks);

      byMember[memberId] = _MemberPerformance(
        memberId: memberId,
        displayName: displayName,
        assignedTasks: assigned.length,
        activeTasks: active,
        completedTasks: completed,
        successfulTasks: successful,
        failedTasks: failed,
        onTimeDoneTasks: onTimeDone,
        completionRate: completionRate,
        onTimeRate: onTimeRate,
        productivityScore: score,
        taskLimit: widget.board.taskLimitForUser(memberId),
      );
    }

    return byMember;
  }

  String _resolveMemberDisplayName(String memberId, List<Task> tasks) {
    final resolvedName = _memberNamesById[memberId];
    if (memberId == widget.board.boardManagerId) {
      final managerName = (resolvedName ?? widget.board.boardManagerName).trim();
      return '${managerName.isEmpty ? 'Manager' : managerName} (Manager)';
    }
    if (resolvedName != null && resolvedName.isNotEmpty) {
      return resolvedName;
    }
    for (final task in tasks) {
      if (task.taskAssignedTo == memberId &&
          task.taskAssignedToName.trim().isNotEmpty) {
        return task.taskAssignedToName;
      }
    }
    final shortId = memberId.length >= 6 ? memberId.substring(0, 6) : memberId;
    return 'Member $shortId';
  }

  Widget _buildMyPerformancePanel({
    required BuildContext context,
    required _MemberPerformance perf,
    required int? rank,
    required int teamSize,
  }) {
    final overload = perf.taskLimit > 0 && perf.activeTasks >= perf.taskLimit;
    final loadLabel = perf.taskLimit > 0
        ? '${perf.activeTasks}/${perf.taskLimit} active'
        : '${perf.activeTasks} active';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_outlined, size: 18),
              const SizedBox(width: 6),
              Text(
                'My Performance',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (rank != null)
                Text(
                  'Rank #$rank/$teamSize',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMiniChip('Assigned', '${perf.assignedTasks}'),
              _buildMiniChip('Completed', '${perf.completedTasks}'),
              _buildMiniChip(
                'On-time',
                '${(perf.onTimeRate * 100).toStringAsFixed(0)}%',
              ),
              _buildMiniChip('Successful', '${perf.successfulTasks}'),
              _buildMiniChip(
                overload ? 'Load (High)' : 'Load',
                loadLabel,
                color: overload ? Colors.orange : Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String label, String value, {Color? color}) {
    final chipColor = color ?? Colors.blueGrey;
    final textColor = chipColor is MaterialColor
        ? chipColor.shade700
        : chipColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildTeamRankingPanel({
    required BuildContext context,
    required List<_MemberPerformance> ranking,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Member Productivity',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...ranking.take(8).toList().asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final perf = entry.value;
          final overload =
              perf.taskLimit > 0 && perf.activeTasks >= perf.taskLimit;
          final load = perf.taskLimit > 0
              ? '${perf.activeTasks}/${perf.taskLimit}'
              : '${perf.activeTasks}';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '#$rank',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    perf.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  'Score ${perf.productivityScore}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
                const SizedBox(width: 10),
                Text(
                  'Load $load',
                  style: TextStyle(
                    fontSize: 11,
                    color: overload ? Colors.orange.shade700 : Colors.grey[700],
                    fontWeight: overload ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMemberRankHint({
    required BuildContext context,
    required int rank,
    required int teamSize,
  }) {
    if (rank <= 0 || teamSize <= 0) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Current team rank: #$rank of $teamSize',
        style: TextStyle(
          fontSize: 12,
          color: Colors.blueGrey.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required BuildContext context,
    required double completionRate,
    required String completionLabel,
    required int doneTasks,
    required int totalTasks,
    required int activeTasks,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50, Colors.cyan.shade50],
        ),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: completionRate,
                  strokeWidth: 7,
                  backgroundColor: Colors.blue.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    completionRate >= 1.0 ? Colors.green : Colors.blue,
                  ),
                ),
                Text(
                  completionLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Completion',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '$doneTasks of $totalTasks tasks finished',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(height: 2),
                Text(
                  '$activeTasks active tasks in rotation',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 160,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberPerformance {
  final String memberId;
  final String displayName;
  final int assignedTasks;
  final int activeTasks;
  final int completedTasks;
  final int successfulTasks;
  final int failedTasks;
  final int onTimeDoneTasks;
  final double completionRate;
  final double onTimeRate;
  final int productivityScore;
  final int taskLimit;

  const _MemberPerformance({
    required this.memberId,
    required this.displayName,
    required this.assignedTasks,
    required this.activeTasks,
    required this.completedTasks,
    required this.successfulTasks,
    required this.failedTasks,
    required this.onTimeDoneTasks,
    required this.completionRate,
    required this.onTimeRate,
    required this.productivityScore,
    required this.taskLimit,
  });
}

