import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../features/boards/datasources/providers/board_provider.dart';
import '../../../../../features/tasks/datasources/providers/task_provider.dart';
import '../../../../features/users/datasources/providers/user_provider.dart';
import '../../../../features/users/datasources/services/user_services.dart';
import '../../datasources/models/poke_model.dart';
import '../../datasources/providers/poke_provider.dart';
import '../../../../../features/boards/datasources/models/board_roles.dart';

class PokePage extends StatefulWidget {
  const PokePage({super.key});

  @override
  State<PokePage> createState() => _PokePageState();
}

class _PokePageState extends State<PokePage> {
  final TextEditingController _messageController = TextEditingController();

  String _timing = PokeModel.timingNow;
  String _targetType = PokeModel.targetUser;
  String? _selectedTargetId;
  List<_TargetOption> _targetOptions = const [];
  bool _loadingTargets = true;

  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTargetOptions();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _scheduledDate = picked);
  }

  Future<void> _pickScheduleTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() => _scheduledTime = picked);
  }

  Future<void> _onTargetTypeChanged(String value) async {
    setState(() {
      _targetType = value;
      _selectedTargetId = null;
      _targetOptions = const [];
      _loadingTargets = true;
    });
    await _loadTargetOptions();
  }

  Future<void> _loadTargetOptions() async {
    if (!mounted) return;
    final userId = context.read<UserProvider>().userId;
    if (userId == null) {
      setState(() {
        _targetOptions = const [];
        _selectedTargetId = null;
        _loadingTargets = false;
      });
      return;
    }

    final boardProvider = context.read<BoardProvider>();
    final taskProvider = context.read<TaskProvider>();
    final userService = UserService();

    List<_TargetOption> options = const [];

    if (_targetType == PokeModel.targetUser) {
      final managedBoards = boardProvider.boards
          .where((board) => board.boardManagerId == userId && !board.boardIsDeleted)
          .toList();

      final allowedUserIds = <String>{userId};
      for (final board in managedBoards) {
        for (final memberId in board.memberIds) {
          final role = BoardRoles.normalize(board.memberRoles[memberId]);
          if (memberId == userId ||
              role == BoardRoles.member ||
              role == BoardRoles.supervisor) {
            allowedUserIds.add(memberId);
          }
        }
      }

      final ids = allowedUserIds.toList()..sort();
      final loaded = <_TargetOption>[];
      for (final id in ids) {
        final user = await userService.getUserById(id);
        final isSelf = id == userId;
        final name = (user?.userName ?? '').trim();
        loaded.add(
          _TargetOption(
            id: id,
            label: name.isEmpty ? (isSelf ? 'You' : 'Unknown User') : name,
            subtitle: isSelf ? 'You' : 'User',
            recipientUserId: id,
            relatedId: id,
          ),
        );
      }
      options = loaded;
    } else if (_targetType == PokeModel.targetBoard) {
      options = boardProvider.boards
          .where((board) => !board.boardIsDeleted)
          .map(
            (board) => _TargetOption(
              id: board.boardId,
              label: board.boardTitle,
              subtitle: board.boardType == 'personal' ? 'Personal' : 'Team',
              relatedId: board.boardId,
            ),
          )
          .toList()
        ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    } else {
      options = taskProvider.tasks
          .where((task) => !task.taskIsDeleted)
          .map(
            (task) => _TargetOption(
              id: task.taskId,
              label: task.taskTitle,
              subtitle: task.taskBoardTitle ?? 'No board',
              recipientUserId:
                  task.taskAssignedTo.isEmpty || task.taskAssignedTo == 'None'
                  ? null
                  : task.taskAssignedTo,
              relatedId: task.taskId,
            ),
          )
          .toList()
        ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    }

    if (!mounted) return;
    setState(() {
      _targetOptions = options;
      _selectedTargetId = options.isNotEmpty ? options.first.id : null;
      _loadingTargets = false;
    });
  }

  Future<void> _submitPoke() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _selectedTargetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a message and choose a target first.'),
        ),
      );
      return;
    }

    if (_timing == PokeModel.timingLater &&
        (_scheduledDate == null || _scheduledTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set both schedule date and time for a later poke.'),
        ),
      );
      return;
    }

    final userProvider = context.read<UserProvider>();
    final creatorId = userProvider.userId;
    if (creatorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found. Please sign in again.')),
      );
      return;
    }

    final selected = _targetOptions.firstWhere(
      (option) => option.id == _selectedTargetId,
      orElse: () => const _TargetOption(id: '', label: 'target'),
    );

    if (_targetType == PokeModel.targetTask &&
        _timing == PokeModel.timingNow &&
        (selected.recipientUserId == null || selected.recipientUserId == 'None')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This task has no assigned member yet.')),
      );
      return;
    }

    DateTime? scheduledAt;
    if (_timing == PokeModel.timingLater &&
        _scheduledDate != null &&
        _scheduledTime != null) {
      scheduledAt = DateTime(
        _scheduledDate!.year,
        _scheduledDate!.month,
        _scheduledDate!.day,
        _scheduledTime!.hour,
        _scheduledTime!.minute,
      );
    }

    final poke = PokeModel(
      pokeId: '',
      createdByUserId: creatorId,
      createdByUserName:
          userProvider.currentUser?.userName.isNotEmpty == true
          ? userProvider.currentUser!.userName
          : 'Unknown',
      targetType: _targetType,
      targetId: selected.id,
      targetLabel: selected.label,
      message: message,
      timing: _timing,
      scheduledAt: scheduledAt,
      status: _timing == PokeModel.timingNow
          ? PokeModel.statusSent
          : PokeModel.statusScheduled,
      recipientUserId: selected.recipientUserId,
      createdAt: DateTime.now(),
    );

    await context.read<PokeProvider>().createPoke(
      poke: poke,
      notificationUserId: _timing == PokeModel.timingNow
          ? selected.recipientUserId
          : null,
      notificationTitle: _targetType == PokeModel.targetTask ? 'Task Poke' : 'Poke',
      relatedId: selected.relatedId ?? selected.id,
      notificationMetadata: {
        'targetType': _targetType,
        'targetId': selected.id,
        'targetLabel': selected.label,
        'pokeTiming': _timing,
      },
    );

    if (!mounted) return;
    final timingLabel = _timing == PokeModel.timingNow ? 'now' : 'for later';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Poke queued $timingLabel for ${selected.label}.'),
      ),
    );
  }

  String get _targetLabel {
    switch (_targetType) {
      case PokeModel.targetBoard:
        return 'Board';
      case PokeModel.targetTask:
        return 'Task';
      default:
        return 'User';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pokeProvider = context.watch<PokeProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Poke',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Send a nudge now or schedule one for later. Target a user, board, or task.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: PokeModel.timingNow,
                    label: Text('Poke Now'),
                    icon: Icon(Icons.bolt_outlined),
                  ),
                  ButtonSegment<String>(
                    value: PokeModel.timingLater,
                    label: Text('Poke Later'),
                    icon: Icon(Icons.schedule),
                  ),
                ],
                selected: {_timing},
                onSelectionChanged: (selected) {
                  setState(() => _timing = selected.first);
                },
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: PokeModel.targetUser,
                    label: Text('User'),
                    icon: Icon(Icons.person_outline),
                  ),
                  ButtonSegment<String>(
                    value: PokeModel.targetBoard,
                    label: Text('Board'),
                    icon: Icon(Icons.view_kanban_outlined),
                  ),
                  ButtonSegment<String>(
                    value: PokeModel.targetTask,
                    label: Text('Task'),
                    icon: Icon(Icons.task_alt_outlined),
                  ),
                ],
                selected: {_targetType},
                onSelectionChanged: (selected) {
                  _onTargetTypeChanged(selected.first);
                },
              ),
              const SizedBox(height: 12),
              if (_loadingTargets)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              DropdownButtonFormField<String>(
                initialValue: _selectedTargetId,
                items: _targetOptions
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option.id,
                        child: Text(
                          option.subtitle == null
                              ? option.label
                              : '${option.label} · ${option.subtitle!}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _loadingTargets || _targetOptions.isEmpty
                    ? null
                    : (value) => setState(() => _selectedTargetId = value),
                decoration: InputDecoration(
                  labelText: 'Select $_targetLabel',
                  border: const OutlineInputBorder(),
                  hintText: _targetOptions.isEmpty
                      ? 'No available $_targetLabel targets'
                      : null,
                ),
              ),
              if (_targetType == PokeModel.targetUser)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'You can poke yourself, supervisors, or members of boards you manage.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                maxLines: 3,
                maxLength: 240,
                decoration: const InputDecoration(
                  labelText: 'Poke Message',
                  hintText: 'Example: Create 5 tasks for Board X',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_timing == PokeModel.timingLater) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickScheduleDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _scheduledDate == null
                              ? 'Set Date'
                              : '${_scheduledDate!.year}-${_scheduledDate!.month.toString().padLeft(2, '0')}-${_scheduledDate!.day.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _pickScheduleTime,
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        _scheduledTime == null
                            ? 'Set Time'
                            : _scheduledTime!.format(context),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: pokeProvider.isSubmitting ? null : _submitPoke,
                  icon: const Icon(Icons.ads_click),
                  label: Text(
                    pokeProvider.isSubmitting ? 'Sending...' : 'Send Poke',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TargetOption {
  final String id;
  final String label;
  final String? subtitle;
  final String? recipientUserId;
  final String? relatedId;

  const _TargetOption({
    required this.id,
    required this.label,
    this.subtitle,
    this.recipientUserId,
    this.relatedId,
  });
}

