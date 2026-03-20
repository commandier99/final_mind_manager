import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../steps/datasources/providers/step_provider.dart';
import '../../../../thoughts/datasources/models/thought_model.dart';
import '../../../../thoughts/datasources/services/thought_service.dart';
import '../../../datasources/models/task_model.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';

class SuggestedStepCard extends StatefulWidget {
  const SuggestedStepCard({
    super.key,
    required this.thought,
    required this.task,
  });

  final Thought thought;
  final Task task;

  @override
  State<SuggestedStepCard> createState() => _SuggestedStepCardState();
}

class _SuggestedStepCardState extends State<SuggestedStepCard> {
  final ThoughtService _thoughtService = ThoughtService();
  bool _isActing = false;

  Future<void> _convertSuggestion() async {
    final messenger = ScaffoldMessenger.of(context);
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
      await context.read<StepProvider>().addStep(
        stepTaskId: widget.task.taskId,
        stepBoardId: widget.task.taskBoardId,
        stepTitle: widget.thought.title.trim(),
        stepDescription: widget.thought.message.trim().isEmpty
            ? null
            : widget.thought.message.trim(),
      );

      final metadata = Map<String, dynamic>.from(
        widget.thought.metadata ?? const <String, dynamic>{},
      );
      metadata['convertedEntityType'] = 'step';
      metadata['convertedTaskId'] = widget.task.taskId;
      metadata['stepTitle'] = widget.thought.title.trim();

      await _thoughtService.updateThought(
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
        const SnackBar(content: Text('Suggestion converted into a step.')),
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
      await _thoughtService.softDeleteThought(widget.thought.thoughtId);
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authorName = widget.thought.authorName.trim().isEmpty
        ? 'Unknown'
        : widget.thought.authorName.trim();
    final description = widget.thought.message.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 2,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(
            color: const Color(0xFFEAB308).withValues(alpha: 0.55),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 8,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7CC),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Suggestion',
                  style: TextStyle(
                    color: Color(0xFF854D0E),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Suggested by $authorName',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7CC),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Suggestion',
                          style: TextStyle(
                            color: Color(0xFF854D0E),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            widget.thought.title.trim().isEmpty
                                ? 'Untitled Step Suggestion'
                                : widget.thought.title.trim(),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton(
                            onPressed: _isActing ? null : _convertSuggestion,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
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
                                horizontal: 12,
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
                  const SizedBox(height: 8),
                  if (description.isNotEmpty) ...[
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Sent at ${_formatDate(widget.thought.createdAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
