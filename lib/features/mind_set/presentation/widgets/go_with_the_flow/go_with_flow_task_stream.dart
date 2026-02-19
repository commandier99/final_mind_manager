import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/providers/task_provider.dart';
import '../../../../tasks/presentation/widgets/cards/task_card.dart';
import '../../../datasources/models/mind_set_session_model.dart';
import '../../../datasources/services/mind_set_session_service.dart';
import '/features/plans/datasources/models/plans_model.dart';
import '/features/plans/datasources/providers/plan_provider.dart';

class GoWithFlowTaskStream extends StatefulWidget {
  final String userId;
  final String mode;
  final MindSetSession? session;

  const GoWithFlowTaskStream({
    super.key,
    required this.userId,
    required this.mode,
    this.session,
  });

  @override
  State<GoWithFlowTaskStream> createState() =>
      _GoWithFlowTaskStreamState();
}

class _GoWithFlowTaskStreamState
    extends State<GoWithFlowTaskStream> {
  final MindSetSessionService _sessionService =
      MindSetSessionService();

  Task? _currentFlowTask;
  final Set<String> _rejectedTaskIds = {};
  late String _currentFlowStyle;

  @override
  void initState() {
    super.initState();
    _currentFlowStyle =
        widget.session?.sessionFlowStyle ?? 'list';
    _streamTasks();
  }

  void _streamTasks() {
    final taskProvider = context.read<TaskProvider>();
    taskProvider.streamUserActiveTasks(widget.userId);
  }

  String _normalizeStatus(String status) =>
      status.toUpperCase().replaceAll(' ', '_');

  bool _isInProgressStatus(String status) =>
      _normalizeStatus(status) == 'IN_PROGRESS';

  void _pickRandomFlowTask(List<Task> tasks) {
    final available = tasks
        .where((t) =>
            !_rejectedTaskIds.contains(t.taskId) &&
            !t.taskIsDone &&
            !_isInProgressStatus(t.taskStatus))
        .toList();

    if (available.isEmpty) {
      _currentFlowTask = null;
      return;
    }

    available.shuffle();
    _currentFlowTask = available.first;
  }

  Future<void> _focusTask(Task task) async {
    if (task.taskIsDone) return;

    final taskProvider = context.read<TaskProvider>();

    // Pause any currently focused task
    for (final t in taskProvider.tasks) {
      if (_isInProgressStatus(t.taskStatus)) {
        await taskProvider.updateTask(
          t.copyWith(taskStatus: 'Paused'),
        );
      }
    }

    await taskProvider.updateTask(
      task.copyWith(taskStatus: 'In Progress'),
    );
  }

  Future<void> _pauseTask(Task task) async {
    final taskProvider = context.read<TaskProvider>();
    await taskProvider.updateTask(
      task.copyWith(taskStatus: 'Paused'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// HEADER
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Text(
                'Tasks',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.grey[300],
                ),
              ),
              const SizedBox(width: 4),

              /// FILTER BUTTON (placeholder)
              Icon(Icons.filter_list,
                  size: 18, color: Colors.grey[700]),

              const SizedBox(width: 12),

              /// FLOW STYLE TOGGLE
              InkWell(
                onTap: () async {
                  final newStyle =
                      _currentFlowStyle == 'shuffle'
                          ? 'list'
                          : 'shuffle';

                  setState(() {
                    _currentFlowStyle = newStyle;
                    _currentFlowTask = null;
                    _rejectedTaskIds.clear();
                  });

                  if (widget.session != null) {
                    await _sessionService.updateSession(
                      widget.session!
                          .copyWith(sessionFlowStyle: newStyle),
                    );
                  }
                },
                child: Icon(
                  _currentFlowStyle == 'shuffle'
                      ? Icons.shuffle
                      : Icons.view_list,
                  size: 18,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        /// TASK AREA
        Expanded(
          child: Consumer<PlanProvider>(
            builder: (context, planProvider, _) {
              return StreamBuilder<List<Plan>>(
                stream: planProvider
                    .streamUserPlans(widget.userId),
                builder: (context, snapshot) {
                  final plans = snapshot.data ?? [];
                  final plannedTaskIds = <String>{};

                  for (final plan in plans) {
                    plannedTaskIds.addAll(plan.taskIds);
                  }

                  return Consumer<TaskProvider>(
                    builder: (context, taskProvider, _) {
                      final unplannedTasks =
                          taskProvider.tasks
                              .where((task) =>
                                  !plannedTaskIds
                                      .contains(task.taskId))
                              .toList();

                      final visibleTasks =
                          unplannedTasks;

                      /// APPLY FILTERS HERE LATER
                      final filteredTasks =
                          visibleTasks;

                      /// ===== SHUFFLE MODE =====
                      if (_currentFlowStyle ==
                          'shuffle') {
                        Task? focusedTask;

                        for (final t
                            in filteredTasks) {
                          if (_isInProgressStatus(
                              t.taskStatus)) {
                            focusedTask = t;
                            break;
                          }
                        }

                        /// If already focused → show only that
                        if (focusedTask != null) {
                          return Column(
                            children: [
                              const Padding(
                                padding:
                                    EdgeInsets.only(
                                        top: 8,
                                        bottom: 4),
                                child: Text(
                                  '🔥 Currently Working On',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.grey),
                                ),
                              ),
                              Expanded(
                                child: ListView(
                                  children: [
                                    TaskCard(
                                      task:
                                          focusedTask,
                                      showFocusAction:
                                          true,
                                      showFocusInMainRow:
                                          true,
                                      showCheckboxWhenFocusedOnly:
                                          true,
                                      useStatusColor:
                                          true,
                                      isPomodoroMode:
                                          false,
                                      onPause: () =>
                                          _pauseTask(
                                              focusedTask!),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        /// Otherwise → show Yes/No
                        if (_currentFlowTask ==
                                null ||
                            !filteredTasks.any(
                                (t) =>
                                    t.taskId ==
                                    _currentFlowTask!
                                        .taskId)) {
                          _pickRandomFlowTask(
                              filteredTasks);
                        }

                        if (_currentFlowTask ==
                            null) {
                          return const Center(
                            child: Text(
                              'No more tasks available.',
                              style: TextStyle(
                                  color:
                                      Colors.grey),
                            ),
                          );
                        }

                        final task =
                            _currentFlowTask!;

                        return Column(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets
                                      .all(24),
                              child: TaskCard(
                                task: task,
                                showFocusAction:
                                    false,
                                showFocusInMainRow:
                                    false,
                                showCheckboxWhenFocusedOnly:
                                    true,
                                useStatusColor:
                                    true,
                                isPomodoroMode:
                                    false,
                                onToggleDone:
                                    null,
                              ),
                            ),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _rejectedTaskIds
                                          .add(task
                                              .taskId);
                                      _pickRandomFlowTask(
                                          filteredTasks);
                                    });
                                  },
                                  child:
                                      const Text(
                                          'No'),
                                ),
                                const SizedBox(
                                    width: 16),
                                ElevatedButton(
                                  onPressed:
                                      () async {
                                    await _focusTask(
                                        task);
                                    setState(() {
                                      _rejectedTaskIds
                                          .clear();
                                      _currentFlowTask =
                                          null;
                                    });
                                  },
                                  child:
                                      const Text(
                                          'Yes'),
                                ),
                              ],
                            ),
                          ],
                        );
                      }

                      /// ===== LIST MODE =====
                      if (filteredTasks
                          .isEmpty) {
                        return const Center(
                          child: Text(
                            'No tasks available.',
                            style: TextStyle(
                                color:
                                    Colors.grey),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount:
                            filteredTasks.length,
                        itemBuilder:
                            (context, index) {
                          final task =
                              filteredTasks[
                                  index];

                          return TaskCard(
                            task: task,
                            showFocusAction:
                                true,
                            showFocusInMainRow:
                                true,
                            showCheckboxWhenFocusedOnly:
                                true,
                            useStatusColor:
                                true,
                            isPomodoroMode:
                                false,
                            onFocus: () =>
                                _focusTask(
                                    task),
                            onPause: () =>
                                _pauseTask(
                                    task),
                            onToggleDone:
                                (isDone) {},
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
