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
        if (session.sessionMode == 'Pomodoro') MindSetPomodoroSection(session: session),
        Expanded(child: _buildSessionBody(session)),
        Consumer<TaskProvider>(
          builder: (context, taskProvider, _) {
            final focusedTask = taskProvider.tasks
                .firstWhereOrNull((task) => task.taskStatus == 'In Progress');
            
            if (focusedTask != null) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: FocusedTaskCard(
                  task: focusedTask,
                  onPause: () => _pauseTask(taskProvider, focusedTask),
                  onToggleDone: (isDone) => _toggleTaskDone(taskProvider, focusedTask, isDone ?? false),
                ),
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

  Future<void> _endSession(String sessionId) async {
    // Timer runs locally, elapsed time is calculated server-side when session ends
    await _sessionService.endSession(sessionId, DateTime.now());
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
    final updatedTask = focusedTask.copyWith(
      taskIsDone: isDone,
      taskIsDoneAt: isDone ? DateTime.now() : null,
    );
    await taskProvider.updateTask(updatedTask);
  }
}
