import 'package:flutter/material.dart';
import '../features/mind_set/widgets/mind_set_timer.dart';

class MindSetDetails extends StatelessWidget {
  final String title;
  final String description;
  final String? selectedMode;
  final ValueChanged<String>? onModeChanged;
  final String labelText;
  final TextEditingController? titleController;
  final String? titleHint;
  final Duration? timerElapsed;
  final ValueChanged<Duration>? onTimerPersist;
  final bool isTimerEnabled;

  const MindSetDetails({
    super.key,
    required this.title,
    required this.description,
    this.selectedMode,
    this.onModeChanged,
    this.labelText = 'Session Title',
    this.titleController,
    this.titleHint,
    this.timerElapsed,
    this.onTimerPersist,
    this.isTimerEnabled = true,
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
              const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Purpose:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description.isEmpty ? 'No purpose set' : description,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          const Divider(thickness: 1),
          if (selectedMode != null && onModeChanged != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: MindSetTimer(
                    initialElapsed: timerElapsed ?? Duration.zero,
                    onPersist: onTimerPersist,
                    isEnabled: isTimerEnabled,
                    autoStart: isTimerEnabled,
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Mode',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        value: selectedMode,
                        isDense: true,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Checklist',
                            child: Text('Checklist'),
                          ),
                          DropdownMenuItem(
                            value: 'Pomodoro',
                            child: Text('Pomodoro'),
                          ),
                          DropdownMenuItem(
                            value: 'Eat the Frog',
                            child: Text('Eat the Frog'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            onModeChanged!(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
