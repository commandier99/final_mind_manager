import 'package:flutter/material.dart';
import '/shared/modes/mind_set_mode_policy.dart';

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

  String _normalizeTaskCountMode(String mode) {
    switch (mode) {
      case 'tasks completed':
      case 'tasks remaining':
      case 'hide':
        return mode;
      case 'progress':
        return 'tasks completed';
      case 'remaining':
        return 'tasks remaining';
      case 'hidden':
        return 'hide';
      default:
        return 'tasks completed';
    }
  }

  @override
  void initState() {
    super.initState();
    _showTimer = widget.showTimer;
    _taskCountMode = _normalizeTaskCountMode(widget.taskCountMode);
  }

  @override
  void didUpdateWidget(MindSetDetailsSettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskCountMode != widget.taskCountMode) {
      setState(() {
        _taskCountMode = _normalizeTaskCountMode(widget.taskCountMode);
      });
    }
    if (oldWidget.showTimer != widget.showTimer) {
      setState(() {
        _showTimer = widget.showTimer;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final modePolicy = widget.selectedMode != null
        ? MindSetModePolicy.fromMode(widget.selectedMode!)
        : null;
    final timerLocked = modePolicy?.hidesSessionTimer ?? false;

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
                  opacity: timerLocked ? 0.5 : 1.0,
                  child: AbsorbPointer(
                    absorbing: timerLocked,
                    child: SwitchListTile(
                      title: const Text('Show Timer'),
                      subtitle: timerLocked
                          ? const Text('Disabled in Pomodoro mode (uses focus timer)')
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
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'tasks completed',
                            label: Text('Completed'),
                          ),
                          ButtonSegment<String>(
                            value: 'tasks remaining',
                            label: Text('Remaining'),
                          ),
                          ButtonSegment<String>(
                            value: 'hide',
                            label: Text('Hide'),
                          ),
                        ],
                        selected: {_taskCountMode},
                        onSelectionChanged: (selection) {
                          if (selection.isEmpty) return;
                          final value = selection.first;
                          setState(() => _taskCountMode = value);
                          widget.onTaskCountModeChange(value);
                        },
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
