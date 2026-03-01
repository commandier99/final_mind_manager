import 'package:flutter/material.dart';
import 'dart:async';

import '../../../datasources/models/task_model.dart';

class FocusedTaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback? onPause;
  final ValueChanged<bool?>? onToggleDone;
  final bool isPomodoroMode;
  final Widget? subtasksContent;
  final DateTime focusedStartedAt;

  const FocusedTaskCard({
    super.key,
    required this.task,
    this.onPause,
    this.onToggleDone,
    this.isPomodoroMode = false,
    this.subtasksContent,
    required this.focusedStartedAt,
  });

  @override
  State<FocusedTaskCard> createState() => _FocusedTaskCardState();
}

class _FocusedTaskCardState extends State<FocusedTaskCard> {
  bool _showSubtasks = false;
  Timer? _elapsedTicker;

  Color _getPriorityColor() {
    switch (widget.task.taskPriorityLevel.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  void initState() {
    super.initState();
    _startElapsedTicker();
  }

  @override
  void didUpdateWidget(covariant FocusedTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.taskId != widget.task.taskId ||
        oldWidget.focusedStartedAt != widget.focusedStartedAt) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _elapsedTicker?.cancel();
    super.dispose();
  }

  void _startElapsedTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  String _formatElapsed() {
    final elapsed = DateTime.now().difference(widget.focusedStartedAt);
    final totalSeconds = elapsed.isNegative ? 0 : elapsed.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor();
    final canPause = widget.onPause != null && !widget.isPomodoroMode;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: scheme.outlineVariant, width: 1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(0),
            topRight: Radius.circular(0),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(0),
            topRight: Radius.circular(0),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 3, color: priorityColor.withAlpha(220)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: Center(
                            child: Transform.scale(
                              scale: 1.12,
                              child: Checkbox(
                                value: widget.task.taskIsDone,
                                onChanged: widget.onToggleDone,
                                activeColor: priorityColor,
                                side: BorderSide(
                                  color: priorityColor.withAlpha(170),
                                  width: 1.8,
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Text(
                              widget.task.taskTitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                  decoration: widget.task.taskIsDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Elapsed ${_formatElapsed()}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                        if (canPause) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: widget.onPause,
                            tooltip: 'Pause task',
                            style: IconButton.styleFrom(
                              backgroundColor: scheme.surfaceContainerHighest,
                              foregroundColor: scheme.onSurface,
                              minimumSize: const Size(34, 34),
                              padding: const EdgeInsets.all(8),
                            ),
                            icon: const Icon(Icons.pause_rounded, size: 18),
                          ),
                        ],
                      ],
                    ),
                    if (widget.subtasksContent != null) ...[
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          setState(() {
                            _showSubtasks = !_showSubtasks;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: scheme.outlineVariant,
                                  height: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Icon(
                                  _showSubtasks
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 18,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: scheme.outlineVariant,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ClipRect(
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          child: _showSubtasks
                              ? ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 220,
                                  ),
                                  child: Scrollbar(
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      padding: EdgeInsets.zero,
                                      child: widget.subtasksContent!,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
