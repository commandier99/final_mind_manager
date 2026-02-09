import 'package:flutter/material.dart';
import '../datasources/models/mind_set_session_model.dart';
import '../datasources/services/mind_set_session_service.dart';
import 'mind_set_details.dart';
import 'mind_set_pomodoro_section.dart';
import 'on_the_spot/on_the_spot_section.dart';
import 'follow_through/follow_through_task_stream.dart';
import 'go_with_the_flow/go_with_flow_task_stream.dart';

class MindSetActiveSessionView extends StatefulWidget {
  final MindSetSession session;

  const MindSetActiveSessionView({
    super.key,
    required this.session,
  });

  @override
  State<MindSetActiveSessionView> createState() =>
      _MindSetActiveSessionViewState();
}

class _MindSetActiveSessionViewState extends State<MindSetActiveSessionView> {
  final MindSetSessionService _sessionService = MindSetSessionService();

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final isPomodoroMode = session.sessionMode == 'Pomodoro';
    final isPomodoroRunning =
        session.sessionStats.pomodoroIsRunning == true;
    return Column(
      children: [
        MindSetDetails(
          title: session.sessionTitle,
          description: session.sessionPurpose,
          labelText: _getSessionLabel(session.sessionType),
          selectedMode: session.sessionMode,
          onModeChanged: (value) => _updateSessionMode(session, value),
          timerElapsed: _sessionElapsed(session),
          onTimerPersist: (duration) => _updateSessionTimer(session, duration),
          isTimerEnabled: session.sessionStatus == 'active',
          showTimerControls: false,
          showTimer: !(isPomodoroMode && isPomodoroRunning),
        ),
        if (isPomodoroMode) MindSetPomodoroSection(session: session),
        Expanded(child: _buildSessionBody(session)),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (session.sessionStatus == 'created')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmCancelSession(session.sessionId),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Cancel Session'),
                  ),
                ),
              if (session.sessionStatus == 'created')
                const SizedBox(width: 12),
              if (session.sessionStatus == 'created')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _startSession(session),
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Start Session'),
                  ),
                ),
              if (session.sessionStatus == 'active')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmEndSession(session.sessionId),
                    icon: const Icon(Icons.stop_circle),
                    label: const Text('End Session'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSessionBody(MindSetSession session) {
    switch (session.sessionType) {
      case 'on_the_spot':
        return OnTheSpotSection(
          sessionId: session.sessionId,
          sessionTaskIds: session.sessionTaskIds,
          onCancelSet: () => _confirmEndSession(session.sessionId),
          isSessionActive: session.sessionStatus == 'active',
          mode: session.sessionMode,
          session: session,
        );
      case 'go_with_flow':
        return GoWithFlowTaskStream(
          userId: session.sessionUserId,
          mode: session.sessionMode,
          session: session,
        );
      case 'follow_through':
        return FollowThroughTaskStream(
          taskIds: session.sessionTaskIds,
          mode: session.sessionMode,
          session: session,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _updateSessionMode(
    MindSetSession session,
    String newMode,
  ) async {
    if (newMode == session.sessionMode) return;
    final updatedHistory = [
      ...session.sessionModeHistory,
      MindSetModeChange(mode: newMode, changedAt: DateTime.now()),
    ];
    await _sessionService.updateSession(
      session.copyWith(
        sessionMode: newMode,
        sessionModeHistory: updatedHistory,
      ),
    );
  }

  Duration _sessionElapsed(MindSetSession session) {
    final minutes = session.sessionStats.sessionFocusDurationMinutes ?? 0;
    final seconds = session.sessionStats.sessionFocusDurationSeconds ?? 0;
    return Duration(minutes: minutes, seconds: seconds);
  }

  Future<void> _updateSessionTimer(
    MindSetSession session,
    Duration duration,
  ) async {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    await _sessionService.updateSession(
      session.copyWith(
        sessionStats: session.sessionStats.copyWith(
          sessionFocusDurationMinutes: minutes,
          sessionFocusDurationSeconds: seconds,
        ),
      ),
    );
  }

  Future<void> _startSession(MindSetSession session) async {
    await _sessionService.startSession(session);
  }

  Future<void> _endSession(String sessionId) async {
    await _sessionService.endSession(sessionId, DateTime.now());
  }

  Future<void> _cancelSession(String sessionId) async {
    await _sessionService.cancelSession(sessionId);
  }

  Future<void> _confirmEndSession(String sessionId) async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this session?'),
        content: const Text(
          'You will return to the Mind:Set selection. You can review this session later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (shouldEnd != true) return;
    await _endSession(sessionId);
  }

  Future<void> _confirmCancelSession(String sessionId) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this session?'),
        content: const Text(
          'This will discard the current session and return to Mind:Set selection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Session'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Session'),
          ),
        ],
      ),
    );

    if (shouldCancel != true) return;
    await _cancelSession(sessionId);
  }

  String _getSessionLabel(String sessionType) {
    switch (sessionType) {
      case 'on_the_spot':
        return 'On the Spot';
      case 'go_with_flow':
        return 'Go with the Flow';
      case 'follow_through':
        return 'Follow Through';
      default:
        return 'Mind:Set';
    }
  }
}
