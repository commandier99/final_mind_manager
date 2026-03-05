import 'dart:async';
import 'package:flutter/material.dart';

class MindSetTimer extends StatefulWidget {
  final Duration initialElapsed;
  final ValueChanged<Duration>? onPersist;
  final Duration persistInterval;
  final bool isEnabled;
  final bool autoStart;
  final bool showControls;
  final bool showLabel;
  final bool centerContent;

  const MindSetTimer({
    super.key,
    this.initialElapsed = Duration.zero,
    this.onPersist,
    this.persistInterval = const Duration(seconds: 1),
    this.isEnabled = true,
    this.autoStart = false,
    this.showControls = true,
    this.showLabel = true,
    this.centerContent = false,
  });

  @override
  State<MindSetTimer> createState() => _MindSetTimerState();
}

class _MindSetTimerState extends State<MindSetTimer>
    with WidgetsBindingObserver {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;
  int _lastPersistSecond = 0;
  DateTime? _runningAnchor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _elapsed = widget.initialElapsed;
    _lastPersistSecond = _elapsed.inSeconds;
    if (widget.isEnabled && widget.autoStart) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant MindSetTimer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldInitial = oldWidget.initialElapsed.inSeconds;
    final nextInitial = widget.initialElapsed.inSeconds;
    final elapsedSeconds = _elapsed.inSeconds;

    if (!_isRunning && nextInitial != oldInitial && nextInitial != elapsedSeconds) {
      setState(() {
        _elapsed = widget.initialElapsed;
        _lastPersistSecond = _elapsed.inSeconds;
      });
    } else if (_isRunning && nextInitial > elapsedSeconds + 1) {
      _elapsed = widget.initialElapsed;
      _runningAnchor = DateTime.now().subtract(_elapsed);
      _lastPersistSecond = _elapsed.inSeconds;
    }

    if (!widget.isEnabled && _isRunning) {
      _stopTimer();
      return;
    }
    if (widget.isEnabled && widget.autoStart && !_isRunning) {
      _startTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isRunning) return;
    if (state == AppLifecycleState.resumed) {
      _refreshElapsedFromAnchor();
      _persistElapsed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    if (!widget.isEnabled) return;
    if (_isRunning) {
      _stopTimer();
      _persistElapsed();
      return;
    }
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _runningAnchor = DateTime.now().subtract(_elapsed);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshElapsedFromAnchor();
      _maybePersist();
    });

    if (mounted) {
      setState(() {
        _isRunning = true;
      });
    } else {
      _isRunning = true;
    }
  }

  void _stopTimer() {
    _timer?.cancel();
    _runningAnchor = null;
    if (mounted) {
      setState(() {
        _isRunning = false;
      });
    } else {
      _isRunning = false;
    }
  }

  void _refreshElapsedFromAnchor() {
    final anchor = _runningAnchor;
    if (anchor == null) return;
    final nextElapsed = DateTime.now().difference(anchor);
    final safeElapsed = nextElapsed.isNegative ? Duration.zero : nextElapsed;

    if (!mounted) {
      _elapsed = safeElapsed;
      return;
    }

    if (safeElapsed.inSeconds != _elapsed.inSeconds) {
      setState(() {
        _elapsed = safeElapsed;
      });
    }
  }

  void _maybePersist() {
    if (widget.onPersist == null) return;
    final seconds = _elapsed.inSeconds;
    final interval = widget.persistInterval.inSeconds;
    if (interval <= 0) return;
    if (seconds > 0 && seconds % interval == 0 && seconds != _lastPersistSecond) {
      _lastPersistSecond = seconds;
      widget.onPersist?.call(_elapsed);
    }
  }

  void _persistElapsed() {
    if (widget.onPersist == null) return;
    final seconds = _elapsed.inSeconds;
    if (seconds == _lastPersistSecond) return;
    _lastPersistSecond = seconds;
    widget.onPersist?.call(_elapsed);
  }

  String _formatDuration(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = value.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final timeText = _formatDuration(_elapsed);

    return Column(
      crossAxisAlignment:
          widget.centerContent ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (widget.showLabel) ...[
          Text(
            'Timer',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Row(
          mainAxisAlignment:
              widget.centerContent ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Text(
              timeText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.showControls) ...[
              const SizedBox(width: 8),
              IconButton(
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                onPressed: widget.isEnabled ? _toggleTimer : null,
                icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
