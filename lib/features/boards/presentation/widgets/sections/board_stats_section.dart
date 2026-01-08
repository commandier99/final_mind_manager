import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/models/board_model.dart';
import '../../../datasources/providers/board_stats_provider.dart';
import '../../../datasources/providers/board_provider.dart';
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
        final stats = statsProvider.getStatsForBoard(widget.boardId);

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Overview
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Board Statistics',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Stats Grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.2,
                      children: [
                        _buildStatCard(
                          context,
                          'Total Tasks',
                          '${stats?.boardTasksCount ?? 0}',
                          Colors.blue,
                        ),
                        _buildStatCard(
                          context,
                          'Completed Tasks',
                          '${stats?.boardTasksDoneCount ?? 0}',
                          Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Board Activity Section
              BoardActivitySection(boardId: widget.boardId),
            ],
          ),
        );
      },
    );
  }

  String _getCompletionPercentage(dynamic stats) {
    if (stats == null || stats.boardTasksCount == 0) {
      return '0%';
    }
    final percentage = (stats.boardTasksDoneCount / stats.boardTasksCount * 100).toStringAsFixed(1);
    return '$percentage%';
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.1),
              color.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
