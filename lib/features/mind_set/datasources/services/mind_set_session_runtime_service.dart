import '../../../../../shared/modes/mind_set_modes.dart';
import '../models/mind_set_session_model.dart';
import 'mind_set_session_service.dart';

class MindSetSessionRuntimeService {
  final MindSetSessionService _sessionService;

  MindSetSessionRuntimeService({MindSetSessionService? sessionService})
    : _sessionService = sessionService ?? MindSetSessionService();

  String normalizeTaskStatus(String status) {
    return status.toUpperCase().replaceAll(' ', '_');
  }

  bool isInProgressStatus(String status) {
    return normalizeTaskStatus(status) == 'IN_PROGRESS';
  }

  Future<void> logSessionAction({
    required MindSetSession session,
    required String type,
    required String taskId,
    String? fromTaskId,
  }) async {
    final latestSession = await _sessionService.getSessionById(
      session.sessionId,
    );
    if (latestSession == null) return;
    if (latestSession.sessionStatus != 'active') return;

    final runtimeMode = MindSetModes.resolveRuntimeMode(
      latestSession.sessionMode,
    );
    final stats = latestSession.sessionStats;
    final workedTaskIds = latestSession.sessionWorkedTaskIds;
    final actions = latestSession.sessionActions;

    var nextStats = stats;
    var nextWorkedTaskIds = workedTaskIds;

    if (type == 'focus' || type == 'switch') {
      final wasWorked = workedTaskIds.contains(taskId);
      if (!wasWorked) {
        nextWorkedTaskIds = [...workedTaskIds, taskId];
        nextStats = nextStats.copyWith(
          tasksWorkedCount: (stats.tasksWorkedCount ?? 0) + 1,
        );
      }
      nextStats = nextStats.copyWith(
        focusCount: (nextStats.focusCount ?? 0) + 1,
      );
    }

    if (type == 'pause') {
      nextStats = nextStats.copyWith(
        pauseCount: (nextStats.pauseCount ?? 0) + 1,
      );
    }

    if (type == 'switch') {
      nextStats = nextStats.copyWith(
        switchCount: (nextStats.switchCount ?? 0) + 1,
      );
    }

    if (type == 'complete') {
      if (runtimeMode == MindSetModes.checklist) {
        nextStats = nextStats.copyWith(
          checklistCompletedCount: (nextStats.checklistCompletedCount ?? 0) + 1,
        );
      } else if (runtimeMode == MindSetModes.pomodoro) {
        nextStats = nextStats.copyWith(
          pomodoroCompletedCount: (nextStats.pomodoroCompletedCount ?? 0) + 1,
        );
      } else if (runtimeMode == MindSetModes.eatTheFrog) {
        nextStats = nextStats.copyWith(
          eatTheFrogCompletedCount:
              (nextStats.eatTheFrogCompletedCount ?? 0) + 1,
        );
      }
    }

    await _sessionService.updateSession(
      latestSession.copyWith(
        sessionWorkedTaskIds: nextWorkedTaskIds,
        sessionActions: [
          ...actions,
          MindSetSessionAction(
            type: type,
            taskId: taskId,
            mode: runtimeMode,
            at: DateTime.now(),
            fromTaskId: fromTaskId,
          ),
        ],
        sessionStats: nextStats,
      ),
    );
  }

  Future<void> startPomodoroIfNeeded(MindSetSession session) async {
    final latestSession = await _sessionService.getSessionById(
      session.sessionId,
    );
    if (latestSession == null) return;
    if (latestSession.sessionStatus != 'active') return;

    final runtimeMode = MindSetModes.resolveRuntimeMode(
      latestSession.sessionMode,
    );
    if (runtimeMode != MindSetModes.pomodoro) return;

    final stats = latestSession.sessionStats;
    final alreadyRunningFocus =
        (stats.pomodoroIsRunning ?? false) &&
        !(stats.pomodoroIsOnBreak ?? false);
    if (alreadyRunningFocus) return;

    final focusMinutes = (stats.pomodoroFocusMinutes ?? 25) > 0
        ? (stats.pomodoroFocusMinutes ?? 25)
        : 25;
    final resumeRemaining =
        (!(stats.pomodoroIsOnBreak ?? false) &&
            (stats.pomodoroRemainingSeconds ?? 0) > 0)
        ? stats.pomodoroRemainingSeconds!
        : focusMinutes * 60;

    await _sessionService.updateSession(
      latestSession.copyWith(
        sessionStats: stats.copyWith(
          pomodoroIsRunning: true,
          pomodoroIsOnBreak: false,
          pomodoroIsLongBreak: false,
          pomodoroRemainingSeconds: resumeRemaining,
          pomodoroLastUpdatedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> pausePomodoroIfNeeded(MindSetSession session) async {
    final latestSession = await _sessionService.getSessionById(
      session.sessionId,
    );
    if (latestSession == null) return;
    if (latestSession.sessionStatus != 'active') return;

    final runtimeMode = MindSetModes.resolveRuntimeMode(
      latestSession.sessionMode,
    );
    if (runtimeMode != MindSetModes.pomodoro) return;

    final stats = latestSession.sessionStats;
    if (!(stats.pomodoroIsRunning ?? false)) return;

    final focusMinutes = (stats.pomodoroFocusMinutes ?? 25) > 0
        ? (stats.pomodoroFocusMinutes ?? 25)
        : 25;
    final breakMinutes = stats.pomodoroBreakMinutes ?? 5;
    final longBreakMinutes = stats.pomodoroLongBreakMinutes ?? 60;

    final fallbackRemaining =
        ((stats.pomodoroIsOnBreak ?? false)
            ? ((stats.pomodoroIsLongBreak ?? false)
                  ? longBreakMinutes
                  : breakMinutes)
            : focusMinutes) *
        60;
    final baseRemaining = (stats.pomodoroRemainingSeconds ?? 0) > 0
        ? stats.pomodoroRemainingSeconds!
        : fallbackRemaining;
    final lastUpdated = stats.pomodoroLastUpdatedAt;
    final elapsed = lastUpdated == null
        ? 0
        : DateTime.now().difference(lastUpdated).inSeconds;
    final nextRemaining = (baseRemaining - elapsed)
        .clamp(0, baseRemaining)
        .toInt();

    await _sessionService.updateSession(
      latestSession.copyWith(
        sessionStats: stats.copyWith(
          pomodoroIsRunning: false,
          pomodoroRemainingSeconds: nextRemaining,
          pomodoroLastUpdatedAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> startBreakNow(MindSetSession session) async {
    final latestSession = await _sessionService.getSessionById(
      session.sessionId,
    );
    if (latestSession == null) return;
    if (latestSession.sessionStatus != 'active') return;

    final runtimeMode = MindSetModes.resolveRuntimeMode(
      latestSession.sessionMode,
    );
    if (runtimeMode != MindSetModes.pomodoro) return;

    final stats = latestSession.sessionStats;
    final breakMinutes = stats.pomodoroBreakMinutes ?? 5;
    final longBreakMinutes = stats.pomodoroLongBreakMinutes ?? 60;
    final targetCount = stats.pomodoroTargetCount ?? 4;
    final completedCount = stats.pomodoroCount ?? 0;

    final nextCompleted = completedCount + 1;
    final isLongBreak = targetCount > 0 && nextCompleted % targetCount == 0;
    final nextBreakMinutes = isLongBreak ? longBreakMinutes : breakMinutes;

    await _sessionService.updateSession(
      latestSession.copyWith(
        sessionStats: stats.copyWith(
          pomodoroCount: nextCompleted,
          pomodoroIsRunning: true,
          pomodoroIsOnBreak: true,
          pomodoroIsLongBreak: isLongBreak,
          pomodoroRemainingSeconds: nextBreakMinutes * 60,
          pomodoroLastUpdatedAt: DateTime.now(),
        ),
      ),
    );
  }
}
