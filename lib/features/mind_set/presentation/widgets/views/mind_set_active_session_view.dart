import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '../../../datasources/models/mind_set_session_model.dart';
import '../../../datasources/services/mind_set_session_service.dart';
import '../sections/mind_set_details_section.dart';
import '../mind_set_pomodoro_section.dart';
import '../on_the_spot/on_the_spot_task_stream.dart';
import '../follow_through/follow_through_task_stream.dart';
import '../go_with_the_flow/go_with_flow_task_stream.dart';
import '../dialogs/pomodoro_check_in_dialogs.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/presentation/widgets/cards/focused_task_card.dart';

class MindSetActiveSessionView extends StatefulWidget {
  final MindSetSession session;
  final bool showTimer;
  final Function(bool) onTimerToggle;
  final String taskCountMode;

  const MindSetActiveSessionView({
    super.key,
    required this.session,
    required this.showTimer,
    required this.onTimerToggle,
    required this.taskCountMode,
  });

  @override
  State<MindSetActiveSessionView> createState() =>
      _MindSetActiveSessionViewState();
}

class _MindSetActiveSessionViewState extends State<MindSetActiveSessionView>
    with SingleTickerProviderStateMixin {
  final MindSetSessionService _sessionService = MindSetSessionService();
  late AnimationController _sheetController;
  late Animation<double> _sheetAnimation;
  bool _isSheetExpanded = false;
  late ValueNotifier<Duration> _elapsedTimeNotifier;

  @override
  void initState() {
    super.initState();
    _sheetController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _sheetAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _sheetController, curve: Curves.easeInOut),
    );
    _elapsedTimeNotifier = ValueNotifier<Duration>(Duration.zero);
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _elapsedTimeNotifier.dispose();
    super.dispose();
  }

  void _toggleSheet() {
    if (_isSheetExpanded) {
      _sheetController.reverse();
    } else {
      _sheetController.forward();
    }
    setState(() {
      _isSheetExpanded = !_isSheetExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Column(
      children: [
        Consumer<TaskProvider>(
          builder: (context, taskProvider, _) {
            return ValueListenableBuilder<Duration>(
              valueListenable: _elapsedTimeNotifier,
              builder: (context, elapsedTime, _) {
                // Calculate actual task counts based on session type
                int actualTasksDone = 0;
                int actualTasksCount = 0;
                
                if (session.sessionType == 'on_the_spot') {
                  final sessionTasks = taskProvider.tasks
                      .where((task) => session.sessionTaskIds.contains(task.taskId))
                      .toList();
                  actualTasksCount = sessionTasks.length;
                  actualTasksDone = sessionTasks.where((t) => t.taskIsDone).length;
                } else if (session.sessionType == 'follow_through') {
                  final sessionTasks = taskProvider.tasks
                      .where((task) => session.sessionTaskIds.contains(task.taskId))
                      .toList();
                  actualTasksCount = sessionTasks.length;
                  actualTasksDone = sessionTasks.where((t) => t.taskIsDone).length;
                } else if (session.sessionType == 'go_with_flow') {
                  actualTasksCount = taskProvider.tasks.length;
                  actualTasksDone = taskProvider.tasks.where((t) => t.taskIsDone).length;
                }
                
                return MindSetDetails(
                  title: session.sessionTitle,
                  description: session.sessionPurpose,
                  labelText: _getSessionLabel(session.sessionType),
                  sessionStartedAt: session.sessionStartedAt,
                  selectedMode: session.sessionMode,
                  onModeChanged: (value) => _updateSessionMode(session, value),
                  timerElapsed: elapsedTime,
                  onTimerPersist: (elapsed) {
                    _elapsedTimeNotifier.value = elapsed;
                  },
                  isTimerEnabled: session.sessionStatus == 'active',
                  showTimerControls: false,
                  showTimer: widget.showTimer,
                  primaryActionLabel: null,
                  primaryActionIcon: null,
                  onPrimaryAction: null,
                  tasksDoneCount: actualTasksDone,
                  tasksCount: actualTasksCount,
                  taskCountMode: widget.taskCountMode,
                );
              },
            );
          },
        ),
        if (session.sessionMode == 'Pomodoro') MindSetPomodoroSection(
          session: session,
          onPomodoroComplete: () => _handlePomodoroComplete(session),
          onBreakComplete: () => _handleBreakComplete(session),
        ),
        Expanded(child: _buildSessionBody(session)),
        Consumer<TaskProvider>(
          builder: (context, taskProvider, _) {
            final focusedTask = taskProvider.tasks
                .firstWhereOrNull((task) => task.taskStatus == 'In Progress');
            
            if (focusedTask != null) {
                return FocusedTaskCard(
                  task: focusedTask,
                  onPause: () => _pauseTask(taskProvider, focusedTask),
                  onToggleDone: (isDone) => _toggleTaskDone(taskProvider, focusedTask, isDone ?? false),
                );
            }
            return const SizedBox.shrink();
          },
        ),
        if (session.sessionStatus == 'active')
          AnimatedBuilder(
            animation: _sheetAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Drag Handle
                      GestureDetector(
                        onTap: _toggleSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            children: [
                              AnimatedRotation(
                                turns: _isSheetExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  Icons.expand_less,
                                  color: Colors.grey[600],
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // End Session Button - Shows when expanded
                      if (_isSheetExpanded)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _confirmEndSession(session.sessionId),
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: const Text('End Session'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[400],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _handlePomodoroComplete(MindSetSession session) async {
    // Timer done - pause focused task and show check-in
    final taskProvider = context.read<TaskProvider>();
    final focusedTask = taskProvider.tasks
        .firstWhereOrNull((task) => task.taskStatus == 'In Progress');
    
    if (focusedTask == null) return;
    
    // Pause the task
    await taskProvider.updateTask(
      focusedTask.copyWith(taskStatus: 'Paused'),
    );
    
    // Show timer-done check-in
    final availableTasks = taskProvider.tasks
        .where((t) => !t.taskIsDone)
        .toList();
        
    if (!mounted) return;
    
    final result = await showTimerDoneDialog(
      context,
      availableTasks: availableTasks,
      currentTask: focusedTask,
    );
    
    if (result == null || result.preselectedTaskId == null) return;
    
    // Store preselected task ID in session for break-end handler
    await _sessionService.updateSession(
      session.copyWith(
        sessionActiveTaskId: result.preselectedTaskId,
      ),
    );
  }
  
  Future<void> _handleBreakComplete(MindSetSession session) async {
    // Break ended - show confirmation for pre-selected task
    final preselectedTaskId = session.sessionActiveTaskId;
    if (preselectedTaskId == null) return;
    
    final taskProvider = context.read<TaskProvider>();
    final preselectedTask = taskProvider.tasks
        .firstWhereOrNull((t) => t.taskId == preselectedTaskId);
    
    if (preselectedTask == null) {
      // Task was deleted or no longer available
      await _sessionService.updateSession(
        session.copyWith(sessionActiveTaskId: null),
      );
      return;
    }
    
    final allTasks = taskProvider.tasks
        .where((t) => !t.taskIsDone)
        .toList();
    
    if (!mounted) return;
    
    final result = await showBreakEndConfirmationDialog(
      context,
      preselectedTask: preselectedTask,
      allTasks: allTasks,
    );
    
    if (result == null) return;
    
    String? taskIdToFocus;
    if (result.confirmed) {
      taskIdToFocus = preselectedTask.taskId;
    } else if (result.selectedTaskId != null) {
      taskIdToFocus = result.selectedTaskId;
    }
    
    if (taskIdToFocus != null) {
      final taskToFocus = taskProvider.tasks
          .firstWhereOrNull((t) => t.taskId == taskIdToFocus);
      if (taskToFocus != null) {
        await taskProvider.updateTask(
          taskToFocus.copyWith(taskStatus: 'In Progress'),
        );
        // Timer already started by pomodoro section
      }
    }
    
    // Clear the active task ID
    await _sessionService.updateSession(
      session.copyWith(sessionActiveTaskId: null),
    );
  }

  Widget _buildSessionBody(MindSetSession session) {
    switch (session.sessionType) {
      case 'on_the_spot':
        return Padding(
          padding: const EdgeInsets.all(8),
          child: OnTheSpotTaskStream(
            sessionId: session.sessionId,
            sessionTaskIds: session.sessionTaskIds,
            mode: session.sessionMode,
            isSessionActive: session.sessionStatus == 'active',
            session: session,
          ),
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

    final taskProvider = context.read<TaskProvider>();

    // 🔒 Check if any task is currently focused
    final hasFocusedTask = taskProvider.tasks
        .any((task) => task.taskStatus == 'In Progress');

    if (hasFocusedTask) {
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Finish or Pause Task First'),
          content: const Text(
            'You cannot change the session mode while a task is being focused.\n\n'
            'Pause or complete the current task first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Okay'),
            ),
          ],
        ),
      );

      return; // 🚫 Stop mode change
    }

    // ✅ Safe to change mode
    final updatedHistory = [
      ...session.sessionModeHistory,
      MindSetModeChange(
        mode: newMode,
        changedAt: DateTime.now(),
      ),
    ];

    await _sessionService.updateSession(
      session.copyWith(
        sessionMode: newMode,
        sessionModeHistory: updatedHistory,
      ),
    );
  }


  Future<void> _endSession(String sessionId) async {
    final taskProvider = context.read<TaskProvider>();

    // Get session from Firestore
    final session = await _sessionService.streamUserSessions(
      widget.session.sessionUserId,
    ).first.then(
      (sessions) => sessions.firstWhere(
        (s) => s.sessionId == sessionId,
        orElse: () => widget.session,
      ),
    );

    final now = DateTime.now();

    // 1️⃣ Pause all focused tasks
    final focusedTasks = taskProvider.tasks
        .where((task) => task.taskStatus == 'In Progress')
        .toList();

    for (final task in focusedTasks) {
      await taskProvider.updateTask(
        task.copyWith(taskStatus: 'Paused'),
      );
    }

    // 2️⃣ Calculate session duration
    final startedAt = session.sessionStartedAt ?? session.sessionCreatedAt;
    final duration = now.difference(startedAt);

    // 3️⃣ Calculate session task stats
    final sessionTasks = taskProvider.tasks
        .where((task) => session.sessionTaskIds.contains(task.taskId))
        .toList();

    final tasksTotal = sessionTasks.length;
    final tasksDone =
        sessionTasks.where((task) => task.taskIsDone).length;

    // 4️⃣ Update session with computed stats
    await _sessionService.updateSession(
      session.copyWith(
        sessionStatus: 'completed',
        sessionEndedAt: now,
        sessionStats: session.sessionStats.copyWith(
          tasksTotalCount: tasksTotal,
          tasksDoneCount: tasksDone,
          sessionFocusDurationMinutes: duration.inMinutes,
          sessionFocusDurationSeconds: duration.inSeconds,
        ),
      ),
    );

    // 5️⃣ Log completion event properly
    await _sessionService.endSession(sessionId, now);
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

  Future<void> _pauseTask(TaskProvider taskProvider, dynamic focusedTask) async {
    final updatedTask = focusedTask.copyWith(taskStatus: 'Paused');
    await taskProvider.updateTask(updatedTask);
  }

  Future<void> _toggleTaskDone(TaskProvider taskProvider, dynamic focusedTask, bool isDone) async {
    final session = widget.session;
    
    // Handle Pomodoro check-in when task is marked done
    if (session.sessionMode == 'Pomodoro' && isDone && focusedTask.taskStatus == 'In Progress') {
      final stats = session.sessionStats;
      final isTimerRunning = stats.pomodoroIsRunning ?? false;
      
      if (isTimerRunning) {
        // Pause timer before showing dialog
        await _sessionService.updateSession(
          session.copyWith(
            sessionStats: stats.copyWith(
              pomodoroIsRunning: false,
              pomodoroRemainingSeconds: stats.pomodoroRemainingSeconds,
              pomodoroLastUpdatedAt: DateTime.now(),
            ),
          ),
        );
        
        // Show task-done-early check-in
        final availableTasks = taskProvider.tasks
            .where((t) => t.taskId != focusedTask.taskId && !t.taskIsDone)
            .toList();
        
        if (!mounted) return;
        
        final result = await showTaskDoneEarlyDialog(
          context,
          availableTasks: availableTasks,
        );
        
        if (result == null) {
          // User dismissed dialog, resume timer
          await _sessionService.updateSession(
            session.copyWith(
              sessionStats: stats.copyWith(
                pomodoroIsRunning: true,
                pomodoroLastUpdatedAt: DateTime.now(),
              ),
            ),
          );
          return;
        }
        
        // Mark task done
        await taskProvider.updateTask(
          focusedTask.copyWith(
            taskIsDone: true,
            taskStatus: 'COMPLETED',
            taskIsDoneAt: DateTime.now(),
          ),
        );
        
        if (result.continueWithAnother && result.nextTaskId != null) {
          // Continue with another task
          final nextTask = taskProvider.tasks.firstWhereOrNull(
            (t) => t.taskId == result.nextTaskId,
          );
          if (nextTask != null) {
            await taskProvider.updateTask(
              nextTask.copyWith(taskStatus: 'In Progress'),
            );
            await _sessionService.updateSession(
              session.copyWith(
                sessionStats: stats.copyWith(
                  pomodoroIsRunning: true,
                  pomodoroLastUpdatedAt: DateTime.now(),
                ),
              ),
            );
          }
        } else {
          // End pomodoro - handled by timer completion logic in _handlePomodoroComplete
        }
        return;
      }
    }
    
    // Normal toggle
    final updatedTask = focusedTask.copyWith(
      taskIsDone: isDone,
      taskIsDoneAt: isDone ? DateTime.now() : null,
      taskStatus: isDone ? 'COMPLETED' : focusedTask.taskStatus,
    );
    await taskProvider.updateTask(updatedTask);
  }
}
