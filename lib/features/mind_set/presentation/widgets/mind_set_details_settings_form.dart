import 'package:flutter/material.dart';

class MindSetDetailsSettingsForm extends StatefulWidget {
  final bool showTimer;
  final ValueChanged<bool> onTimerToggle;
  final String taskCountMode; // 'tasks completed', 'tasks remaining', 'hide'
  final ValueChanged<String> onTaskCountModeChange;
  final String? selectedMode;

  const MindSetDetailsSettingsForm({
    super.key,
    required this.showTimer,
    required this.onTimerToggle,
    required this.taskCountMode,
    required this.onTaskCountModeChange,
    this.selectedMode,
  });

  @override
  State<MindSetDetailsSettingsForm> createState() =>
      _MindSetDetailsSettingsFormState();
}

class _MindSetDetailsSettingsFormState
    extends State<MindSetDetailsSettingsForm> {
  late bool _showTimer;
  late String _taskCountMode;

  @override
  void initState() {
    super.initState();
    _showTimer = widget.showTimer;
    _taskCountMode = widget.taskCountMode;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Widget Visibility',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          // Settings
          SingleChildScrollView(
            child: Column(
              children: [
                Opacity(
                  opacity: widget.selectedMode == 'Pomodoro' ? 0.5 : 1.0,
                  child: AbsorbPointer(
                    absorbing: widget.selectedMode == 'Pomodoro',
                    child: SwitchListTile(
                      title: const Text('Show Timer'),
                      subtitle: widget.selectedMode == 'Pomodoro'
                          ? const Text('Disabled in Pomodoro mode (uses built-in timer)')
                          : const Text('Display elapsed time during the session'),
                      value: _showTimer,
                      onChanged: (value) {
                        setState(() => _showTimer = value);
                        widget.onTimerToggle(value);
                      },
                    ),
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Task Count Display',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      RadioListTile<String>(
                        title: const Text('Tasks Completed (counts up)'),
                        value: 'tasks completed',
                        groupValue: _taskCountMode,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _taskCountMode = value);
                            widget.onTaskCountModeChange(value);
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<String>(
                        title: const Text('Tasks Remaining (counts down)'),
                        value: 'remaining',
                        groupValue: _taskCountMode,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _taskCountMode = value);
                            widget.onTaskCountModeChange(value);
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      RadioListTile<String>(
                        title: const Text('Hide Task Count'),
                        value: 'hide',
                        groupValue: _taskCountMode,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _taskCountMode = value);
                            widget.onTaskCountModeChange(value);
                          }
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
