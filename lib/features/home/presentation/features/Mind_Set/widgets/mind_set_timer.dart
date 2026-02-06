import 'dart:async';
import 'package:flutter/material.dart';

class MindSetTimer extends StatefulWidget {
  final Duration initialElapsed;
  final ValueChanged<Duration>? onPersist;
  final Duration persistInterval;
  final bool isEnabled;
  final bool autoStart;

  const MindSetTimer({
    super.key,
    this.initialElapsed = Duration.zero,
    this.onPersist,
    this.persistInterval = const Duration(seconds: 5),
    this.isEnabled = true,
    this.autoStart = false,
  });

  @override
  State<MindSetTimer> createState() => _MindSetTimerState();
}

class _MindSetTimerState extends State<MindSetTimer> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;
  int _lastPersistSecond = 0;

  @override
  void initState() {
    super.initState();
    _elapsed = widget.initialElapsed;
    _lastPersistSecond = _elapsed.inSeconds;
    if (widget.isEnabled && widget.autoStart) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(covariant MindSetTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isRunning && oldWidget.initialElapsed != widget.initialElapsed) {
      _elapsed = widget.initialElapsed;
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
  void dispose() {
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

  void _resetTimer() {
    if (!widget.isEnabled) return;
    _timer?.cancel();
    setState(() {
      _elapsed = Duration.zero;
      _isRunning = false;
    });
    _persistElapsed();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed += const Duration(seconds: 1);
      });
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
    if (mounted) {
      setState(() {
        _isRunning = false;
      });
    } else {
      _isRunning = false;
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timer',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              timeText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: widget.isEnabled ? _toggleTimer : null,
              icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
            ),
            IconButton(
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              onPressed: widget.isEnabled ? _resetTimer : null,
              icon: const Icon(Icons.restart_alt),
            ),
          ],
        ),
      ],
    );
  }
}
