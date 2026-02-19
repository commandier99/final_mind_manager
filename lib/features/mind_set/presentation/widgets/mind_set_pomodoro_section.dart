import 'dart:async';
import 'package:flutter/material.dart';
import '../../datasources/models/mind_set_session_model.dart';
import '../../datasources/services/mind_set_session_service.dart';

typedef PomodoroCompleteCallback = Future<void> Function();
typedef BreakCompleteCallback = Future<void> Function();

class MindSetPomodoroSection extends StatefulWidget {
  final MindSetSession session;
  final PomodoroCompleteCallback? onPomodoroComplete;
  final BreakCompleteCallback? onBreakComplete;

  const MindSetPomodoroSection({
    super.key,
    required this.session,
    this.onPomodoroComplete,
    this.onBreakComplete,
  });

  @override
  State<MindSetPomodoroSection> createState() => _MindSetPomodoroSectionState();
}

class _DurationOption extends StatelessWidget {
  final String title;
  final String subtitle;

  const _DurationOption({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = TextStyle(
      fontSize: 11,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Text.rich(
      TextSpan(
        text: title,
        style: const TextStyle(fontWeight: FontWeight.w600),
        children: [
          const TextSpan(text: '  •  '),
          TextSpan(text: subtitle, style: subtitleStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _MindSetPomodoroSectionState extends State<MindSetPomodoroSection> {
  final MindSetSessionService _sessionService = MindSetSessionService();
  Timer? _ticker;
  int _displayRemainingSeconds = 0;
  bool _isRunning = false;
  bool _isOnBreak = false;
  bool _isLongBreak = false;
  String _motivation = 'focused';

  @override
  void initState() {
    super.initState();
    _syncFromSession();
    _startTicker();
  }

  @override
  void didUpdateWidget(covariant MindSetPomodoroSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _syncFromSession();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = _effectiveRemainingSeconds();
      if (remaining <= 0 && _isRunning) {
        _handleIntervalComplete();
        return;
      }
      setState(() {
        _displayRemainingSeconds = remaining;
      });
    });
  }

  void _syncFromSession() {
    final stats = widget.session.sessionStats;
    _isRunning = stats.pomodoroIsRunning ?? false;
    _isOnBreak = stats.pomodoroIsOnBreak ?? false;
    _isLongBreak = stats.pomodoroIsLongBreak ?? false;
    _motivation = stats.pomodoroMotivation ?? 'focused';
    _displayRemainingSeconds = _effectiveRemainingSeconds();
  }

  int _effectiveRemainingSeconds() {
    final stats = widget.session.sessionStats;
    final focusMinutes = stats.pomodoroFocusMinutes;
    final breakMinutes = stats.pomodoroBreakMinutes ?? 5;
    final longBreakMinutes = stats.pomodoroLongBreakMinutes ?? 60;
    if (focusMinutes == null || focusMinutes <= 0) {
      return 0;
    }
    final baseRemaining =
      stats.pomodoroRemainingSeconds ??
      (_isOnBreak
          ? (_isLongBreak ? longBreakMinutes : breakMinutes)
          : focusMinutes) *
        60;
    if (!_isRunning) {
      return baseRemaining;
    }
    final lastUpdated = stats.pomodoroLastUpdatedAt;
    if (lastUpdated == null) {
      return baseRemaining;
    }
    final elapsed = DateTime.now().difference(lastUpdated).inSeconds;
    final remaining = baseRemaining - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  Future<void> _handleIntervalComplete() async {
    final stats = widget.session.sessionStats;
    final focusMinutes = stats.pomodoroFocusMinutes ?? 0;
    final breakMinutes = stats.pomodoroBreakMinutes ?? 5;
    final longBreakMinutes = stats.pomodoroLongBreakMinutes ?? 60;
    final targetCount = stats.pomodoroTargetCount ?? 4;
    final completedCount = stats.pomodoroCount ?? 0;

    if (_isOnBreak) {
      // Break ended - trigger callback for break-end confirmation
      if (widget.onBreakComplete != null) {
        await widget.onBreakComplete!();
      }
      
      final resetCount = _isLongBreak;
      _isOnBreak = false;
      _isLongBreak = false;
      _isRunning = false;
      _displayRemainingSeconds = focusMinutes * 60;

      await _sessionService.updateSession(
        widget.session.copyWith(
          sessionStats: stats.copyWith(
            pomodoroIsRunning: false,
            pomodoroIsOnBreak: false,
            pomodoroIsLongBreak: false,
            pomodoroRemainingSeconds: focusMinutes * 60,
            pomodoroLastUpdatedAt: DateTime.now(),
            pomodoroCount: resetCount ? 0 : completedCount,
          ),
        ),
      );
    } else {
      // Focus session ended - trigger callback for timer-done check-in
      if (widget.onPomodoroComplete != null) {
        await widget.onPomodoroComplete!();
      }
      
      final nextCompleted = completedCount + 1;
      final isLongBreak = targetCount > 0 && nextCompleted % targetCount == 0;
      final nextBreakMinutes = isLongBreak ? longBreakMinutes : breakMinutes;

      _isRunning = false;
      _isOnBreak = true;
      _isLongBreak = isLongBreak;
      _displayRemainingSeconds = nextBreakMinutes * 60;

      await _sessionService.updateSession(
        widget.session.copyWith(
          sessionStats: stats.copyWith(
            pomodoroCount: nextCompleted,
            pomodoroIsRunning: false,
            pomodoroIsOnBreak: true,
            pomodoroIsLongBreak: isLongBreak,
            pomodoroRemainingSeconds: nextBreakMinutes * 60,
            pomodoroLastUpdatedAt: DateTime.now(),
          ),
        ),
      );

      if (mounted) {
        await _showMotivationPrompt();
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _updateSettings({
    required int focusMinutes,
    required int targetCount,
    String? motivation,
  }) async {
    final stats = widget.session.sessionStats;
    final currentRemaining = _effectiveRemainingSeconds();
    final safeFocus = focusMinutes < 1 ? 1 : focusMinutes;
    final safeTarget = targetCount < 1 ? 1 : targetCount;

    await _sessionService.updateSession(
      widget.session.copyWith(
        sessionStats: stats.copyWith(
          pomodoroFocusMinutes: safeFocus,
          pomodoroTargetCount: safeTarget,
          pomodoroMotivation: motivation ?? stats.pomodoroMotivation,
          pomodoroRemainingSeconds:
              _isRunning ? currentRemaining : safeFocus * 60,
          pomodoroLastUpdatedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _showSettingsDialog() async {
    final stats = widget.session.sessionStats;
    int? selectedFocus = stats.pomodoroFocusMinutes;
    final targetController = TextEditingController(
      text: (stats.pomodoroTargetCount ?? 4).toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Pomodoro Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: selectedFocus == null
                    ? null
                    : _normalizedFocusMinutes(selectedFocus!),
                decoration: const InputDecoration(
                  labelText: 'Focus duration',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 5,
                    child: _DurationOption(
                      title: '5 minutes',
                      subtitle: 'Low motivation',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 10,
                    child: _DurationOption(
                      title: '10 minutes',
                      subtitle: 'Better focus',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 25,
                    child: _DurationOption(
                      title: '25 minutes',
                      subtitle: 'Focused',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 60,
                    child: _DurationOption(
                      title: '60 minutes',
                      subtitle: 'Flow state',
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedFocus = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Target pomodoros',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedFocus == null
                  ? null
                  : () {
                      final targetCount =
                          int.tryParse(targetController.text) ?? 4;
                      final motivation = _motivationForMinutes(selectedFocus!);
                      _motivation = motivation;
                      _updateSettings(
                        focusMinutes: selectedFocus!,
                        targetCount: targetCount,
                        motivation: motivation,
                      );
                      Navigator.pop(context);
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMotivationPrompt() async {
    final stats = widget.session.sessionStats;
    String selectedMotivation = stats.pomodoroMotivation ?? _motivation;
    int suggestedMinutes = _suggestedFocusMinutes(selectedMotivation);
    final focusController = TextEditingController(
      text: (stats.pomodoroFocusMinutes ?? suggestedMinutes).toString(),
    );

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('How are you feeling?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedMotivation,
                decoration: const InputDecoration(labelText: 'Motivation level'),
                items: const [
                  DropdownMenuItem(
                    value: 'distracted',
                    child: Text('Distracted'),
                  ),
                  DropdownMenuItem(
                    value: 'okay',
                    child: Text('Okay'),
                  ),
                  DropdownMenuItem(
                    value: 'focused',
                    child: Text('Focused'),
                  ),
                  DropdownMenuItem(
                    value: 'flow',
                    child: Text('Flow'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    selectedMotivation = value;
                    suggestedMinutes = _suggestedFocusMinutes(value);
                    focusController.text = suggestedMinutes.toString();
                  });
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: focusController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Focus minutes (suggested $suggestedMinutes)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () {
                final focusMinutes = int.tryParse(focusController.text) ??
                    suggestedMinutes;
                _updateSettings(
                  focusMinutes: focusMinutes,
                  targetCount: stats.pomodoroTargetCount ?? 4,
                  motivation: selectedMotivation,
                );
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  int _suggestedFocusMinutes(String motivation) {
    switch (motivation) {
      case 'distracted':
        return 5;
      case 'okay':
        return 10;
      case 'flow':
        return 60;
      case 'focused':
      default:
        return 25;
    }
  }

  String _motivationForMinutes(int minutes) {
    switch (minutes) {
      case 5:
        return 'distracted';
      case 10:
        return 'okay';
      case 60:
        return 'flow';
      case 25:
      default:
        return 'focused';
    }
  }

  int _normalizedFocusMinutes(int minutes) {
    const allowed = [5, 10, 25, 60];
    if (allowed.contains(minutes)) return minutes;
    var closest = allowed.first;
    var bestDiff = (minutes - closest).abs();
    for (final value in allowed) {
      final diff = (minutes - value).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        closest = value;
      }
    }
    return closest;
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.session.sessionStats;
    final targetCount = stats.pomodoroTargetCount ?? 4;
    final completedCount = stats.pomodoroCount ?? 0;
    final statusText = _isOnBreak
      ? (_isLongBreak ? 'Big Break' : 'Break Time')
      : 'Focus Time';

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _showSettingsDialog,
                  icon: const Icon(Icons.more_horiz),
                  tooltip: 'Pomodoro settings',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            Center(
              child: Text(
                _displayRemainingSeconds <= 0
                    ? '--:--'
                    : _formatTime(_displayRemainingSeconds),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pomodoros: $completedCount/$targetCount',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
