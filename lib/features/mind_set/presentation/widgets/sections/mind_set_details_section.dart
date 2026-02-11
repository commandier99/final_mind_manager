import 'package:flutter/material.dart';
import '../mind_set_timer.dart';

class MindSetDetails extends StatelessWidget {
  final String title;
  final String description;
  final String? selectedMode;
  final ValueChanged<String>? onModeChanged;
  final String labelText;
  final TextEditingController? titleController;
  final String? titleHint;
  final String? subtitleText;
  final DateTime? sessionStartedAt;
  final Duration? timerElapsed;
  final ValueChanged<Duration>? onTimerPersist;
  final bool isTimerEnabled;
  final bool showTimerControls;
  final bool showTimer;
  final String? primaryActionLabel;
  final IconData? primaryActionIcon;
  final VoidCallback? onPrimaryAction;
  final Widget? headerMenu;
  final int? tasksDoneCount;
  final int? tasksCount;
  final String taskCountMode; // 'progress', 'remaining', 'hidden'

  const MindSetDetails({
    super.key,
    required this.title,
    required this.description,
    this.selectedMode,
    this.onModeChanged,
    this.labelText = 'Session Title',
    this.titleController,
    this.titleHint,
    this.subtitleText,
    this.sessionStartedAt,
    this.timerElapsed,
    this.onTimerPersist,
    this.isTimerEnabled = true,
    this.showTimerControls = true,
    this.showTimer = false,
    this.primaryActionLabel,
    this.primaryActionIcon,
    this.onPrimaryAction,
    this.headerMenu,
    this.tasksDoneCount,
    this.tasksCount,
    this.taskCountMode = 'progress',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labelText,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (titleController == null)
                      Text(
                        title,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          hintText: titleHint ?? title,
                          isDense: true,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (primaryActionLabel != null)
                const SizedBox(width: 12),
              if (primaryActionLabel != null)
                primaryActionIcon != null
                    ? FilledButton.icon(
                        onPressed: onPrimaryAction,
                        icon: Icon(primaryActionIcon),
                        label: Text(primaryActionLabel!),
                      )
                    : FilledButton(
                        onPressed: onPrimaryAction,
                        child: Text(primaryActionLabel!),
                      ),
              if (headerMenu != null) headerMenu!,
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Goal:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description.isEmpty ? 'No goal set' : description,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          const Divider(thickness: 1),
          if (timerElapsed != null || (selectedMode != null && onModeChanged != null) || (tasksDoneCount != null && tasksCount != null && taskCountMode != 'hidden')) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                const sectionWidth = 125.0;

                return SizedBox(
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: sectionWidth,
                          child: (tasksDoneCount != null &&
                                  tasksCount != null &&
                                  taskCountMode != 'hidden')
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      taskCountMode == 'remaining'
                                          ? 'Tasks Remaining'
                                          : 'Tasks Completed',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      taskCountMode == 'remaining'
                                          ? '${(tasksCount ?? 0) - (tasksDoneCount ?? 0)}'
                                          : '$tasksDoneCount',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: sectionWidth,
                          child: (timerElapsed != null)
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'Timer',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Opacity(
                                          opacity: showTimer ? 1.0 : 0.0,
                                          child: MindSetTimer(
                                            initialElapsed: timerElapsed!,
                                            onPersist: onTimerPersist,
                                            isEnabled: isTimerEnabled,
                                            autoStart: isTimerEnabled,
                                            showControls: showTimerControls,
                                            showLabel: false,
                                            centerContent: true,
                                          ),
                                        ),
                                        if (!showTimer)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: TextButton.icon(
                                              onPressed: () => _showElapsedTimeDialog(context, timerElapsed!),
                                              icon: const Icon(Icons.schedule, size: 14),
                                              label: const Text('Check', style: TextStyle(fontSize: 11)),
                                              style: TextButton.styleFrom(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                                visualDensity: VisualDensity.compact,
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    ],
                                  )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: SizedBox(
                          width: sectionWidth,
                          child: (selectedMode != null && onModeChanged != null)
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Mode',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: sectionWidth,
                                      child: DropdownButtonFormField<String>(
                                        value: selectedMode,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          border: OutlineInputBorder(),
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'Checklist',
                                            child: Text(
                                              'Checklist',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'Pomodoro',
                                            child: Text(
                                              'Pomodoro',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                          ),
                                          DropdownMenuItem(
                                            value: 'Eat the Frog',
                                            child: Text(
                                              'Eat the Frog',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) {
                                            onModeChanged!(value);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  } else {
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

void _showElapsedTimeDialog(BuildContext context, Duration elapsed) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Time elapsed: ${_formatDuration(elapsed)}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
