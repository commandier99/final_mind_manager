import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/models/board_model.dart';
import '../../../datasources/models/board_stats_model.dart';
import '../../../datasources/providers/board_stats_provider.dart';
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
  @override
  Widget build(BuildContext context) {
    return Consumer<BoardStatsProvider>(
      builder: (context, statsProvider, _) {
        final stats =
            statsProvider.getStatsForBoard(widget.boardId) ?? BoardStats();

        final totalTasks = stats.boardTasksCount;
        final doneTasks = stats.boardTasksDoneCount;
        final deletedTasks = stats.boardTasksDeletedCount;
        final activeTasks = (totalTasks - deletedTasks).clamp(0, totalTasks);

        final totalSubtasks = stats.boardSubtasksCount;
        final doneSubtasks = stats.boardSubtasksDoneCount;
        final deletedSubtasks = stats.boardSubtasksDeletedCount;

        final completionRate = totalTasks > 0 ? doneTasks / totalTasks : 0.0;
        final completionLabel = '${(completionRate * 100).toStringAsFixed(0)}%';

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
                          label: 'Deleted',
                          value: '$deletedTasks',
                          icon: Icons.delete_outline,
                          color: Colors.red,
                        ),
                        _buildMetricTile(
                          label: 'Subtasks',
                          value: '$totalSubtasks',
                          icon: Icons.format_list_bulleted,
                          color: Colors.indigo,
                        ),
                        _buildMetricTile(
                          label: 'Subtasks Done',
                          value: '$doneSubtasks',
                          icon: Icons.done_all,
                          color: Colors.teal,
                        ),
                        _buildMetricTile(
                          label: 'Subtasks Deleted',
                          value: '$deletedSubtasks',
                          icon: Icons.remove_done,
                          color: Colors.deepOrange,
                        ),
                        _buildMetricTile(
                          label: 'Messages',
                          value: '${stats.boardMessageCount}',
                          icon: Icons.forum_outlined,
                          color: Colors.purple,
                        ),
                      ],
                    ),
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
