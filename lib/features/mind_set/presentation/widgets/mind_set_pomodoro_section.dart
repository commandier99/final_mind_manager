import 'dart:async';
import 'package:flutter/material.dart';
import '../../datasources/models/mind_set_session_model.dart';
import '../../datasources/services/mind_set_session_service.dart';

enum PomodoroTransition { startBreak, startNextFocus }

typedef PomodoroCompleteCallback = Future<PomodoroTransition> Function();
typedef BreakCompleteCallback = Future<void> Function();

class _PomodoroPreset {
  final String name;
  final int focusMinutes;
  final int breakMinutes;
  final int longBreakMinutes;
  final int targetCount;
  final bool isCustom;

  const _PomodoroPreset({
    required this.name,
    required this.focusMinutes,
    required this.breakMinutes,
    required this.longBreakMinutes,
    required this.targetCount,
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'focusMinutes': focusMinutes,
    'breakMinutes': breakMinutes,
    'longBreakMinutes': longBreakMinutes,
    'targetCount': targetCount,
  };

  static _PomodoroPreset? fromMap(Map<String, dynamic> map) {
    final name = (map['name'] as String?)?.trim();
    final focus = map['focusMinutes'] as int?;
    final shortBreak = map['breakMinutes'] as int?;
    final longBreak = map['longBreakMinutes'] as int?;
    final target = map['targetCount'] as int?;
    if (name == null ||
        name.isEmpty ||
        focus == null ||
        shortBreak == null ||
        longBreak == null ||
        target == null) {
      return null;
    }
    return _PomodoroPreset(
      name: name,
      focusMinutes: focus,
      breakMinutes: shortBreak,
      longBreakMinutes: longBreak,
      targetCount: target,
      isCustom: true,
    );
  }
}

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

class _MindSetPomodoroSectionState extends State<MindSetPomodoroSection> {
  final MindSetSessionService _sessionService = MindSetSessionService();
  Timer? _ticker;
  int _displayRemainingSeconds = 0;
  bool _isRunning = false;
  bool _isOnBreak = false;
  bool _isLongBreak = false;

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
    _displayRemainingSeconds = _effectiveRemainingSeconds();
  }

  int _effectiveRemainingSeconds() {
    final stats = widget.session.sessionStats;
    final focusMinutes = (stats.pomodoroFocusMinutes ?? 25) > 0
        ? (stats.pomodoroFocusMinutes ?? 25)
        : 25;
    final breakMinutes = stats.pomodoroBreakMinutes ?? 5;
    final longBreakMinutes = stats.pomodoroLongBreakMinutes ?? 60;
    final baseRemaining =
        (stats.pomodoroRemainingSeconds != null &&
            stats.pomodoroRemainingSeconds! > 0)
        ? stats.pomodoroRemainingSeconds!
        : (_isOnBreak
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
      // Break ended - unlock tasks. Next focus starts when user focuses a task.
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
      // Focus session ended - choose whether to break now or continue immediately.
      PomodoroTransition transition = PomodoroTransition.startBreak;
      if (widget.onPomodoroComplete != null) {
        transition = await widget.onPomodoroComplete!();
      }

      final nextCompleted = completedCount + 1;
      final isLongBreak = targetCount > 0 && nextCompleted % targetCount == 0;
      final nextBreakMinutes = isLongBreak ? longBreakMinutes : breakMinutes;
      final shouldBreakNow = transition == PomodoroTransition.startBreak;

      _isRunning = true;
      _isOnBreak = shouldBreakNow;
      _isLongBreak = shouldBreakNow ? isLongBreak : false;
      _displayRemainingSeconds = shouldBreakNow
          ? nextBreakMinutes * 60
          : focusMinutes * 60;

      await _sessionService.updateSession(
        widget.session.copyWith(
          sessionStats: stats.copyWith(
            pomodoroCount: nextCompleted,
            pomodoroIsRunning: true,
            pomodoroIsOnBreak: shouldBreakNow,
            pomodoroIsLongBreak: shouldBreakNow ? isLongBreak : false,
            pomodoroRemainingSeconds: shouldBreakNow
                ? nextBreakMinutes * 60
                : focusMinutes * 60,
            pomodoroLastUpdatedAt: DateTime.now(),
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _updateSettings({
    required int focusMinutes,
    required int breakMinutes,
    required int longBreakMinutes,
    required int targetCount,
    String? motivation,
    List<Map<String, dynamic>>? customPresets,
  }) async {
    if (_isTimerRunningNow()) {
      return;
    }
    final stats = widget.session.sessionStats;
    final currentRemaining = _effectiveRemainingSeconds();
    final safeFocus = focusMinutes < 1 ? 1 : focusMinutes;
    final safeBreak = breakMinutes < 1 ? 1 : breakMinutes;
    final safeLongBreak = longBreakMinutes < 1 ? 1 : longBreakMinutes;
    final safeTarget = targetCount < 1 ? 1 : targetCount;
    final nextRemaining = _isRunning
        ? currentRemaining
        : (_isOnBreak
                  ? (_isLongBreak ? safeLongBreak : safeBreak)
                  : safeFocus) *
              60;

    await _sessionService.updateSession(
      widget.session.copyWith(
        sessionStats: stats.copyWith(
          pomodoroFocusMinutes: safeFocus,
          pomodoroBreakMinutes: safeBreak,
          pomodoroLongBreakMinutes: safeLongBreak,
          pomodoroTargetCount: safeTarget,
          pomodoroMotivation: motivation ?? stats.pomodoroMotivation,
          pomodoroCustomPresets: customPresets ?? stats.pomodoroCustomPresets,
          pomodoroRemainingSeconds: nextRemaining,
          pomodoroLastUpdatedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _showSettingsDialog() async {
    const focusOptions = [5, 10, 15, 25, 45, 60];
    const breakOptions = [3, 5, 10, 15];
    const longBreakOptions = [20, 30, 45, 60];
    const minTarget = 1;
    const maxTarget = 10;
    final builtInPresets = <_PomodoroPreset>[
      const _PomodoroPreset(
        name: 'Classic',
        focusMinutes: 25,
        breakMinutes: 5,
        longBreakMinutes: 30,
        targetCount: 4,
      ),
      const _PomodoroPreset(
        name: 'Sprint',
        focusMinutes: 10,
        breakMinutes: 5,
        longBreakMinutes: 20,
        targetCount: 6,
      ),
      const _PomodoroPreset(
        name: 'Deep Work',
        focusMinutes: 45,
        breakMinutes: 10,
        longBreakMinutes: 30,
        targetCount: 3,
      ),
    ];

    final stats = widget.session.sessionStats;
    int selectedFocus = _closestFromOptions(
      stats.pomodoroFocusMinutes ?? 25,
      focusOptions,
    );
    int selectedBreak = _closestFromOptions(
      stats.pomodoroBreakMinutes ?? 5,
      breakOptions,
    );
    int selectedLongBreak = _closestFromOptions(
      stats.pomodoroLongBreakMinutes ?? 60,
      longBreakOptions,
    );
    int selectedTarget = (stats.pomodoroTargetCount ?? 4).clamp(
      minTarget,
      maxTarget,
    );
    List<_PomodoroPreset> customPresets = stats.pomodoroCustomPresets
        .map(_PomodoroPreset.fromMap)
        .whereType<_PomodoroPreset>()
        .toList();
    final settingsLocked = _isTimerRunningNow();

    bool isPresetSelected(_PomodoroPreset preset) {
      return selectedFocus == preset.focusMinutes &&
          selectedBreak == preset.breakMinutes &&
          selectedLongBreak == preset.longBreakMinutes &&
          selectedTarget == preset.targetCount;
    }

    Future<void> saveCustomPreset(StateSetter setState) async {
      final nameController = TextEditingController();
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save Preset'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Preset name',
              hintText: 'e.g. Finals Week',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final trimmed = nameController.text.trim();
                if (trimmed.isEmpty) return;
                Navigator.pop(context, trimmed);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (name == null || name.trim().isEmpty) return;

      final preset = _PomodoroPreset(
        name: name.trim(),
        focusMinutes: selectedFocus,
        breakMinutes: selectedBreak,
        longBreakMinutes: selectedLongBreak,
        targetCount: selectedTarget,
        isCustom: true,
      );

      setState(() {
        customPresets = [
          ...customPresets.where(
            (p) => p.name.toLowerCase() != preset.name.toLowerCase(),
          ),
          preset,
        ];
      });
    }

    Widget optionGroup({
      required String label,
      required List<int> options,
      required int selectedValue,
      required ValueChanged<int>? onSelected,
      String suffix = 'm',
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map(
                  (value) => ChoiceChip(
                    label: Text('$value$suffix'),
                    selected: selectedValue == value,
                    onSelected: onSelected == null
                        ? null
                        : (_) => onSelected(value),
                  ),
                )
                .toList(),
          ),
        ],
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pomodoro Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Presets',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: settingsLocked
                          ? null
                          : () => saveCustomPreset(setState),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Save current'),
                    ),
                  ],
                ),
                if (settingsLocked) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Timer is running. Settings can be viewed but cannot be changed until the timer stops.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...builtInPresets.map((preset) {
                      final isSelected = isPresetSelected(preset);
                      return FilterChip(
                        label: Text(preset.name),
                        selected: isSelected,
                        showCheckmark: false,
                        onSelected: settingsLocked
                            ? null
                            : (_) {
                          setState(() {
                            selectedFocus = preset.focusMinutes;
                            selectedBreak = preset.breakMinutes;
                            selectedLongBreak = preset.longBreakMinutes;
                            selectedTarget = preset.targetCount;
                          });
                        },
                      );
                    }),
                    ...customPresets.map((preset) {
                      final isSelected = isPresetSelected(preset);
                      return FilterChip(
                        label: Text(preset.name),
                        selected: isSelected,
                        showCheckmark: false,
                        onSelected: settingsLocked
                            ? null
                            : (_) {
                          setState(() {
                            selectedFocus = preset.focusMinutes;
                            selectedBreak = preset.breakMinutes;
                            selectedLongBreak = preset.longBreakMinutes;
                            selectedTarget = preset.targetCount;
                          });
                        },
                        onDeleted: settingsLocked
                            ? null
                            : () {
                          setState(() {
                            customPresets = customPresets
                                .where((p) => p.name != preset.name)
                                .toList();
                          });
                        },
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 12),
                optionGroup(
                  label: 'Focus length',
                  options: focusOptions,
                  selectedValue: selectedFocus,
                  onSelected: settingsLocked
                      ? null
                      : (v) => setState(() => selectedFocus = v),
                ),
                const SizedBox(height: 12),
                optionGroup(
                  label: 'Short break',
                  options: breakOptions,
                  selectedValue: selectedBreak,
                  onSelected: settingsLocked
                      ? null
                      : (v) => setState(() => selectedBreak = v),
                ),
                const SizedBox(height: 12),
                optionGroup(
                  label: 'Long break',
                  options: longBreakOptions,
                  selectedValue: selectedLongBreak,
                  onSelected: settingsLocked
                      ? null
                      : (v) => setState(() => selectedLongBreak = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Long break after',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      onPressed: settingsLocked
                          ? null
                          : selectedTarget > minTarget
                          ? () => setState(() => selectedTarget--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 48),
                      alignment: Alignment.center,
                      child: Text(
                        '$selectedTarget',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: settingsLocked
                          ? null
                          : selectedTarget < maxTarget
                          ? () => setState(() => selectedTarget++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'focus sessions',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: settingsLocked
                        ? null
                        : () {
                      if (_isTimerRunningNow()) {
                        Navigator.pop(context);
                        return;
                      }
                      final motivation = _motivationForMinutes(selectedFocus);
                      _updateSettings(
                        focusMinutes: selectedFocus,
                        breakMinutes: selectedBreak,
                        longBreakMinutes: selectedLongBreak,
                        targetCount: selectedTarget,
                        motivation: motivation,
                        customPresets: customPresets
                            .map((preset) => preset.toMap())
                            .toList(),
                      );
                      Navigator.pop(context);
                    },
                    child: const Text('Save Settings'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  int _closestFromOptions(int value, List<int> options) {
    var closest = options.first;
    var bestDiff = (value - closest).abs();
    for (final candidate in options) {
      final diff = (value - candidate).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        closest = candidate;
      }
    }
    return closest;
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  int _currentPhaseTotalSeconds() {
    final stats = widget.session.sessionStats;
    final focusMinutes = stats.pomodoroFocusMinutes ?? 25;
    final breakMinutes = stats.pomodoroBreakMinutes ?? 5;
    final longBreakMinutes = stats.pomodoroLongBreakMinutes ?? 60;
    if (_isOnBreak) {
      return (_isLongBreak ? longBreakMinutes : breakMinutes) * 60;
    }
    return focusMinutes * 60;
  }

  double _progress() {
    final total = _currentPhaseTotalSeconds();
    if (total <= 0) return 0;
    final remaining = _displayRemainingSeconds.clamp(0, total);
    final elapsed = total - remaining;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Color _phaseColor(ColorScheme scheme) {
    if (_isOnBreak && _isLongBreak) return Colors.teal;
    if (_isOnBreak) return Colors.green;
    return scheme.primary;
  }

  Future<void> _skipCurrentInterval() async {
    if (!_isRunning) return;
    await _handleIntervalComplete();
  }

  bool _isTimerRunningNow() {
    return widget.session.sessionStats.pomodoroIsRunning ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.session.sessionStats;
    final targetCount = stats.pomodoroTargetCount ?? 4;
    final completedCount = stats.pomodoroCount ?? 0;
    final phaseColor = _phaseColor(Theme.of(context).colorScheme);
    final progress = _progress();
    final canSkip = _isRunning;
    final skipLabel = _isOnBreak ? 'Skip to Focus' : 'Skip to Break';

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Pomodoros: $completedCount/$targetCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            const SizedBox(height: 6),
            Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 7,
                        color: phaseColor.withValues(alpha: 0.12),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                        color: phaseColor,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isOnBreak
                              ? (_isLongBreak ? 'Long Break' : 'Break')
                              : 'Focus',
                          style: TextStyle(
                            fontSize: 10,
                            color: phaseColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _displayRemainingSeconds <= 0
                              ? '--:--'
                              : _formatTime(_displayRemainingSeconds),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (canSkip)
                          SizedBox(
                            height: 24,
                            child: FilledButton.tonal(
                              onPressed: _skipCurrentInterval,
                              style: FilledButton.styleFrom(
                                backgroundColor: phaseColor.withValues(
                                  alpha: 0.14,
                                ),
                                foregroundColor: phaseColor,
                                side: BorderSide(
                                  color: phaseColor.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: Text(skipLabel),
                            ),
                          )
                        else
                          const SizedBox(height: 24),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (!canSkip)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Focus on a task to start or resume the timer.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
