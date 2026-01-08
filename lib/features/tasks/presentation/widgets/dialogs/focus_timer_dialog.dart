import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../datasources/models/task_model.dart';
import '../../../datasources/providers/task_focus_session_provider.dart';

class FocusTimerWidget extends StatefulWidget {
  final Task task;
  final int plannedDurationMinutes;
  final VoidCallback onClose;

  const FocusTimerWidget({
    super.key,
    required this.task,
    required this.plannedDurationMinutes,
    required this.onClose,
  });

  @override
  State<FocusTimerWidget> createState() => _FocusTimerWidgetState();
}

class _FocusTimerWidgetState extends State<FocusTimerWidget> {
  late Timer _timer;
  int _elapsedSeconds = 0;
  bool _isRunning = true;
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    print('[DEBUG] FocusTimerWidget: initState called');
    _startFocusSession();
    _startTimer();
  }

  Future<void> _startFocusSession() async {
    try {
      final focusProvider = context.read<TaskFocusSessionProvider>();
      _currentSessionId = await focusProvider.startFocusSession(
        taskId: widget.task.taskId,
        userId: widget.task.taskOwnerId,
        plannedDurationMinutes: widget.plannedDurationMinutes,
      );
      print('[DEBUG] FocusTimerWidget: Focus session started with ID = $_currentSessionId');
    } catch (e) {
      print('⚠️ Error starting focus session: $e');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isRunning) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  double _getProgress() {
    final plannedSeconds = widget.plannedDurationMinutes * 60;
    return (_elapsedSeconds / plannedSeconds).clamp(0.0, 1.0);
  }

  void _togglePause() {
    setState(() {
      _isRunning = !_isRunning;
    });
    print('[DEBUG] FocusTimerWidget: Pause toggled, isRunning = $_isRunning');
    // Update task status in Firestore when pause/resume toggled
    try {
      final taskDoc = FirebaseFirestore.instance.collection('tasks').doc(widget.task.taskId);
      if (!_isRunning) {
        taskDoc.update({'taskStatus': 'ON_PAUSE'});
      } else {
        taskDoc.update({'taskStatus': 'IN_PROGRESS'});
      }
    } catch (e) {
      print('[DEBUG] FocusTimerWidget: Failed to update task status on pause toggle: $e');
    }
  }

  void _addTime(int minutes) {
    print('[DEBUG] FocusTimerWidget: Adding $minutes minutes to focus session');
    setState(() {
      // Session continues with extended duration
    });
  }

  Future<void> _endSession(String endReason) async {
    try {
      _timer.cancel();
      
      if (_currentSessionId == null) {
        throw Exception('No active focus session');
      }

      final focusProvider = context.read<TaskFocusSessionProvider>();
      
      // Show end session dialog
      if (mounted) {
        _showEndSessionDialog(endReason, focusProvider);
      }
    } catch (e) {
      print('⚠️ Error ending focus session: $e');
    }
  }

  void _showEndSessionDialog(String endReason, TaskFocusSessionProvider focusProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End Focus Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You focused for ${_formatTime(_elapsedSeconds)}'),
            const SizedBox(height: 16),
            const Text('How productive were you?'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _confirmEndSession(focusProvider, index + 1, endReason);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmEndSession(
    TaskFocusSessionProvider focusProvider,
    int productivityScore,
    String endReason,
  ) async {
    try {
      await focusProvider.endFocusSession(
        actualDurationMinutes: _elapsedSeconds ~/ 60,
        wasCompleted: _elapsedSeconds >= (widget.plannedDurationMinutes * 60),
        endReason: endReason,
        productivityScore: productivityScore,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onClose();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Focus session ended. Productivity: $productivityScore/5'),
          ),
        );
      }
    } catch (e) {
      print('⚠️ Error confirming end session: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              widget.task.taskTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),

            // Timer display with progress
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _getProgress(),
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.shade300,
                    color: Colors.blue,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatTime(_elapsedSeconds),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'of ${widget.plannedDurationMinutes} min',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pause/Resume
                FloatingActionButton.extended(
                  onPressed: _togglePause,
                  label: Text(_isRunning ? 'Pause' : 'Resume'),
                  icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow),
                ),
                const SizedBox(width: 12),
                // Add time
                FloatingActionButton.extended(
                  onPressed: () => _addTime(5),
                  label: const Text('+5 min'),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // End session buttons
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => _endSession('break'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Break'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _endSession('completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Finish'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _endSession('stopped'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Stop'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
