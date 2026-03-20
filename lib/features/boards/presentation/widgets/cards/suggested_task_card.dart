import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../thoughts/datasources/models/thought_model.dart';
import '../../../../thoughts/datasources/providers/thought_provider.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/models/task_stats_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../datasources/models/board_model.dart';

class SuggestedTaskCard extends StatefulWidget {
  const SuggestedTaskCard({
    super.key,
    required this.thought,
    required this.board,
  });

  final Thought thought;
  final Board board;

  @override
  State<SuggestedTaskCard> createState() => _SuggestedTaskCardState();
}

class _SuggestedTaskCardState extends State<SuggestedTaskCard> {
  bool _isActing = false;

  Future<void> _convertSuggestion() async {
    final messenger = ScaffoldMessenger.of(context);
    final thoughtProvider = context.read<ThoughtProvider>();
    final taskProvider = context.read<TaskProvider>();
    final currentUser = context.read<UserProvider>().currentUser;
    if (currentUser == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No signed-in user found.')),
      );
      return;
    }

    setState(() {
      _isActing = true;
    });

    try {
      final metadata = Map<String, dynamic>.from(
        widget.thought.metadata ?? const <String, dynamic>{},
      );
      final createdTask = Task(
        taskId: const Uuid().v4(),
        taskBoardId: widget.board.boardId,
        taskBoardTitle: widget.board.boardTitle,
        taskOwnerId: currentUser.userId,
        taskOwnerName: currentUser.userName.trim().isEmpty
            ? 'Unknown'
            : currentUser.userName.trim(),
        taskAssignedBy: currentUser.userId,
        taskAssignedTo: 'None',
        taskAssignedToName: 'Unassigned',
        taskCreatedAt: DateTime.now(),
        taskTitle: widget.thought.title.trim().isEmpty
            ? 'Untitled Task'
            : widget.thought.title.trim(),
        taskDescription: widget.thought.message.trim(),
        taskStats: TaskStats(),
        taskBoardLane: Task.laneDrafts,
      );

      await taskProvider.addTask(createdTask);

      metadata['convertedEntityType'] = 'task';
      metadata['convertedTaskId'] = createdTask.taskId;
      metadata['taskTitle'] = createdTask.taskTitle;

      await thoughtProvider.updateThought(
        widget.thought.copyWith(
          status: Thought.statusConverted,
          updatedAt: DateTime.now(),
          actionedAt: DateTime.now(),
          actionedBy: currentUser.userId,
          actionedByName: currentUser.userName,
          metadata: metadata,
        ),
      );

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Suggestion converted into a draft task.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to convert suggestion: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
        });
      }
    }
  }

  Future<void> _deleteSuggestion() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isActing = true;
    });

    try {
      await context.read<ThoughtProvider>().softDeleteThought(widget.thought.thoughtId);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Suggestion deleted.')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to delete suggestion: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorName = widget.thought.authorName.trim().isEmpty
        ? 'Unknown'
        : widget.thought.authorName.trim();
    final description = widget.thought.message.trim();
    final createdAt = widget.thought.createdAt;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        child: Stack(
          children: [
            Container(
              width: 4,
              color: const Color(0xFFEAB308),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 12,
                              color: Colors.grey.shade700,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Suggested by $authorName',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE68A),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Suggestion',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF854D0E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFEAB308),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: const Color(0xFFFFFBEB),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 12,
                              color: Color(0xFF854D0E),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Preview',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF854D0E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.thought.title.trim().isEmpty
                                  ? 'Untitled Suggestion'
                                  : widget.thought.title.trim(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              description.isEmpty
                                  ? 'No task description provided.'
                                  : description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Sent at ${_formatDate(createdAt)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton(
                            onPressed: _isActing ? null : _convertSuggestion,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF854D0E),
                              side: const BorderSide(color: Color(0xFFEAB308)),
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -2,
                              ),
                            ),
                            child: Text(_isActing ? '...' : 'Convert'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: _isActing ? null : _deleteSuggestion,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade400,
                              side: BorderSide(color: Colors.red.shade200),
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -2,
                              ),
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$month/$day/$year';
  }
}
