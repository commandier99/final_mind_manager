import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../features/boards/datasources/models/board_request_model.dart';
import '../../../../../features/boards/datasources/models/board_model.dart';
import '../../../../../features/boards/datasources/providers/board_request_provider.dart';
import '../../../../../features/notifications/datasources/models/in_app_notif_model.dart';
import '../../../../../features/notifications/datasources/providers/in_app_notif_provider.dart';
import '../../../../../features/tasks/datasources/models/task_model.dart';
import '../../../../../features/boards/datasources/providers/board_provider.dart';
import '../../../../../features/tasks/datasources/providers/task_provider.dart';
import '../../../../../features/boards/presentation/pages/board_details_page.dart';
import '../../../../../features/tasks/presentation/pages/task_details_page.dart';
import '../../../../datasources/providers/navigation_provider.dart';
import '../../../../features/users/datasources/providers/user_provider.dart';
import '../../../../features/users/datasources/services/user_services.dart';
import '../../datasources/models/memory_model.dart';
import '../../datasources/providers/memory_provider.dart';
import '../../../../../features/boards/datasources/models/board_roles.dart';

class MemoryPage extends StatefulWidget {
  final bool composeOnly;

  const MemoryPage({super.key, this.composeOnly = false});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  static const List<String> _actionNeededOptions = [
    'Reminder',
    'Review and acknowledge',
    'Update progress/status',
    'Submit requirement',
    'Confirm completion',
  ];

  String _targetType = MemoryModel.targetUser;
  String? _selectedActionNeeded = _actionNeededOptions.first;
  String? _selectedTargetId;
  List<_TargetOption> _targetOptions = const [];
  bool _loadingTargets = true;
  String _selectedThought = NavigationProvider.memoryBankThoughtAll;
  final Set<String> _processingInviteIds = <String>{};
  final Set<String> _processingAssignmentNotifIds = <String>{};

  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  String? _subjectFieldError;
  String? _messageFieldError;
  String? _actionNeededFieldError;
  String? _detailsFieldError;
  String? _formErrorText;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _scheduledDate = DateTime(now.year, now.month, now.day);
    _scheduledTime = TimeOfDay.fromDateTime(now);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    await _loadTargetOptions();
    if (!mounted) return;
    final userId = context.read<UserProvider>().userId;
    if (userId != null && userId.isNotEmpty) {
      context.read<MemoryProvider>().streamMailbox(userId);
      context.read<BoardRequestProvider>().streamInvitationsByUser(userId);
      context.read<BoardRequestProvider>().streamInvitationsSentByManager(userId);
      context.read<BoardRequestProvider>().streamJoinRequestsByUser(userId);
    }
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _detailsController.dispose();
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
      _subjectController.clear();
      _messageController.clear();
      _selectedActionNeeded = _actionNeededOptions.first;
      _detailsController.clear();
      _subjectFieldError = null;
      _messageFieldError = null;
      _actionNeededFieldError = null;
      _detailsFieldError = null;
      _formErrorText = null;
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
    final managedBoardIds = boardProvider.boards
        .where((board) => !board.boardIsDeleted && board.boardManagerId == userId)
        .map((board) => board.boardId)
        .toSet();

    List<_TargetOption> options = const [];

    if (_targetType == MemoryModel.targetUser) {
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
    } else if (_targetType == MemoryModel.targetBoard) {
      options = boardProvider.boards
          .where((board) => !board.boardIsDeleted && board.boardManagerId == userId)
          .map(
            (board) => _TargetOption(
              id: board.boardId,
              label: board.boardTitle,
              subtitle: board.boardType == 'personal' ? 'Personal' : 'Team',
              recipientUserId: userId,
              relatedId: board.boardId,
            ),
          )
          .toList()
        ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    } else {
      final myDependencyTaskIds = _collectMyDependencyTaskIds(
        currentUserId: userId,
        tasks: taskProvider.tasks,
      );
      options = taskProvider.tasks
          .where(
            (task) => _canPokeTask(
              task: task,
              currentUserId: userId,
              managedBoardIds: managedBoardIds,
              myDependencyTaskIds: myDependencyTaskIds,
            ),
          )
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

  bool get _isUserTarget => _targetType == MemoryModel.targetUser;

  DateTime _composeScheduledDateTime() {
    final now = DateTime.now();
    final date = _scheduledDate ?? DateTime(now.year, now.month, now.day);
    final time = _scheduledTime ?? TimeOfDay.fromDateTime(now);
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  bool _isScheduledForLater(DateTime scheduledAt) {
    final now = DateTime.now();
    return scheduledAt.isAfter(now.add(const Duration(minutes: 1)));
  }

  Future<bool> _confirmSendNow() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Send Now?'),
          content: const Text('Send this thought now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Send Now'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Set<String> _collectMyDependencyTaskIds({
    required String currentUserId,
    required List<Task> tasks,
  }) {
    final myTasks = tasks.where((task) {
      if (task.taskIsDeleted) return false;
      final assignedToMe = task.taskAssignedTo == currentUserId;
      final ownedByMe = task.taskOwnerId == currentUserId;
      return assignedToMe || ownedByMe;
    });

    final dependencyIds = <String>{};
    for (final task in myTasks) {
      for (final dependencyId in task.taskDependencyIds) {
        final normalized = dependencyId.trim();
        if (normalized.isNotEmpty) {
          dependencyIds.add(normalized);
        }
      }
    }
    return dependencyIds;
  }

  bool _canPokeTask({
    required Task task,
    required String currentUserId,
    required Set<String> managedBoardIds,
    required Set<String> myDependencyTaskIds,
  }) {
    if (task.taskIsDeleted) return false;

    if (task.taskAssignedTo == currentUserId || task.taskOwnerId == currentUserId) {
      return true;
    }

    if (managedBoardIds.contains(task.taskBoardId)) {
      return true;
    }

    return myDependencyTaskIds.contains(task.taskId);
  }

  Future<void> _submitPoke() async {
    final pokeProvider = context.read<MemoryProvider>();
    setState(() {
      _subjectFieldError = null;
      _messageFieldError = null;
      _actionNeededFieldError = null;
      _detailsFieldError = null;
      _formErrorText = null;
    });

    if (_selectedTargetId == null) {
      setState(() => _formErrorText = 'Choose a target first.');
      return;
    }

    final selected = _targetOptions.firstWhere(
      (option) => option.id == _selectedTargetId,
      orElse: () => const _TargetOption(id: '', label: 'target'),
    );

    final userProvider = context.read<UserProvider>();
    final creatorId = userProvider.userId;
    if (creatorId == null) {
      setState(() => _formErrorText = 'User not found. Please sign in again.');
      return;
    }

    final scheduledAt = _composeScheduledDateTime();
    final isLater = _isScheduledForLater(scheduledAt);
    final timing = isLater ? MemoryModel.timingLater : MemoryModel.timingNow;

    if (_targetType == MemoryModel.targetTask &&
        timing == MemoryModel.timingNow &&
        (selected.recipientUserId == null || selected.recipientUserId == 'None')) {
      setState(() => _formErrorText = 'This task has no assigned member yet.');
      return;
    }

    final subject = _isUserTarget
        ? _subjectController.text.trim()
        : _buildStructuredSubject(selected.label);
    final message = _isUserTarget
        ? _messageController.text.trim()
        : _buildStructuredMessage();

    var hasFieldError = false;
    if (_isUserTarget) {
      if (subject.isEmpty) {
        _subjectFieldError = 'Subject is required.';
        hasFieldError = true;
      }
      if (message.isEmpty) {
        _messageFieldError = 'Message is required.';
        hasFieldError = true;
      }
    } else {
      if ((_selectedActionNeeded ?? '').trim().isEmpty) {
        _actionNeededFieldError = 'Action needed is required.';
        hasFieldError = true;
      }
      if (_detailsController.text.trim().length < 15) {
        _detailsFieldError = 'Details must be at least 15 characters.';
        hasFieldError = true;
      }
    }
    if (hasFieldError) {
      setState(() {
        _formErrorText = 'Please complete the required fields.';
      });
      return;
    }

    if (timing == MemoryModel.timingNow) {
      final confirmed = await _confirmSendNow();
      if (!confirmed) return;
    }

    final createdAt = DateTime.now();
    final poke = MemoryModel(
      memoryId: '',
      createdByUserId: creatorId,
      createdByUserName:
          userProvider.currentUser?.userName.isNotEmpty == true
          ? userProvider.currentUser!.userName
          : 'Unknown',
      targetType: _targetType,
      targetId: selected.id,
      targetLabel: selected.label,
      subject: subject,
      message: message,
      timing: timing,
      scheduledAt: isLater ? scheduledAt : null,
      status: timing == MemoryModel.timingNow
          ? MemoryModel.statusSent
          : MemoryModel.statusScheduled,
      recipientUserId: selected.recipientUserId,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    await pokeProvider.createMemoryEntry(
      memory: poke,
      notificationUserId: timing == MemoryModel.timingNow
          ? selected.recipientUserId
          : null,
      notificationTitle: subject,
      relatedId: selected.relatedId ?? selected.id,
      notificationMetadata: {
        'targetType': _targetType,
        'targetId': selected.id,
        'targetLabel': selected.label,
        'pokeTiming': timing,
        if (_isUserTarget) 'subject': subject,
      },
    );

    _subjectController.clear();
    _messageController.clear();
    _selectedActionNeeded = _actionNeededOptions.first;
    _detailsController.clear();
    final now = DateTime.now();
    _scheduledDate = DateTime(now.year, now.month, now.day);
    _scheduledTime = TimeOfDay.fromDateTime(now);
    _subjectFieldError = null;
    _messageFieldError = null;
    _actionNeededFieldError = null;
    _detailsFieldError = null;
    _formErrorText = null;

    if (!mounted) return;
    final timingLabel = timing == MemoryModel.timingNow ? 'now' : 'for later';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Thought queued $timingLabel for ${selected.label}.')),
    );
  }

  String _buildStructuredSubject(String targetLabel) {
    final normalizedTarget = _targetType == MemoryModel.targetTask ? 'Task' : 'Board';
    return '$normalizedTarget Reminder: $targetLabel';
  }

  String _buildStructuredMessage() {
    final action = (_selectedActionNeeded ?? '').trim();
    final details = _detailsController.text.trim();
    return 'Action needed: $action\nDetails: $details';
  }

  Future<void> _openComposeSheet(MemoryProvider pokeProvider) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: _buildComposeSection(
                pokeProvider,
                updater: setState,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openThread(MemoryThreadSummary summary) async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null) return;

    final messages = context.read<MemoryProvider>().getThreadMessages(summary.threadId);
    final latest = summary.latestMessage;
    final isUserThread = latest.targetType == MemoryModel.targetUser;

    final replyTargetUserId = _resolveReplyTargetUserId(messages, userId);
    final canReply = replyTargetUserId != null && replyTargetUserId.isNotEmpty;

    final replySubjectController = TextEditingController(
      text: isUserThread
          ? _buildReplySubject(latest.subject ?? latest.message)
          : '',
    );
    final replyMessageController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _threadTitle(summary),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final poke = messages[index];
                      final mine = poke.createdByUserId == userId;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(10),
                          constraints: const BoxConstraints(maxWidth: 360),
                          decoration: BoxDecoration(
                            color: mine ? Colors.blue.shade50 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: mine ? Colors.blue.shade200 : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mine ? 'You' : poke.createdByUserName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if ((poke.subject ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  poke.subject!.trim(),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(poke.message),
                              const SizedBox(height: 6),
                              Text(
                                timeago.format(poke.createdAt),
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (canReply) ...[
                  const SizedBox(height: 10),
                  if (isUserThread)
                    TextField(
                      controller: replySubjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  if (isUserThread) const SizedBox(height: 8),
                  TextField(
                    controller: replyMessageController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: isUserThread ? 'Reply Message' : 'Reply Reminder',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final msg = replyMessageController.text.trim();
                        final subject = isUserThread
                            ? replySubjectController.text.trim()
                            : latest.subject ?? _threadTitle(summary);
                        if (msg.isEmpty) return;
                        if (isUserThread && subject.isEmpty) return;

                        await _sendReply(
                          thread: summary,
                          recipientUserId: replyTargetUserId,
                          subject: subject,
                          message: msg,
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.reply),
                      label: const Text('Reply'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    replySubjectController.dispose();
    replyMessageController.dispose();
  }

  String _buildReplySubject(String seed) {
    final cleaned = seed.trim();
    if (cleaned.toLowerCase().startsWith('re:')) return cleaned;
    return 'Re: $cleaned';
  }

  String? _resolveReplyTargetUserId(List<MemoryModel> messages, String currentUserId) {
    if (messages.isEmpty) return null;
    final latest = messages.last;
    if ((latest.recipientUserId ?? '').trim().isNotEmpty &&
        latest.createdByUserId == currentUserId) {
      return latest.recipientUserId;
    }
    if (latest.createdByUserId != currentUserId) {
      return latest.createdByUserId;
    }

    for (final poke in messages.reversed) {
      if (poke.createdByUserId != currentUserId) return poke.createdByUserId;
    }
    return null;
  }

  Future<void> _sendReply({
    required MemoryThreadSummary thread,
    required String recipientUserId,
    required String subject,
    required String message,
  }) async {
    final userProvider = context.read<UserProvider>();
    final creatorId = userProvider.userId;
    if (creatorId == null) return;

    final latest = thread.latestMessage;
    final now = DateTime.now();
    final reply = MemoryModel(
      memoryId: '',
      createdByUserId: creatorId,
      createdByUserName:
          userProvider.currentUser?.userName.isNotEmpty == true
          ? userProvider.currentUser!.userName
          : 'Unknown',
      targetType: latest.targetType,
      targetId: latest.targetId,
      targetLabel: latest.targetLabel,
      subject: subject,
      message: message,
      threadId: thread.threadId,
      inReplyToMemoryId: latest.memoryId,
      timing: MemoryModel.timingNow,
      status: MemoryModel.statusSent,
      recipientUserId: recipientUserId,
      createdAt: now,
      updatedAt: now,
    );

    await context.read<MemoryProvider>().createMemoryEntry(
      memory: reply,
      notificationUserId: recipientUserId,
      notificationTitle: subject,
      relatedId: latest.targetId,
      notificationMetadata: {
        'targetType': latest.targetType,
        'targetId': latest.targetId,
        'targetLabel': latest.targetLabel,
        'threadId': thread.threadId,
        'subject': subject,
      },
    );
  }

  String _threadTitle(MemoryThreadSummary thread) {
    final latest = thread.latestMessage;
    final subject = (latest.subject ?? '').trim();
    if (subject.isNotEmpty) return subject;
    return '${_formatTargetType(latest.targetType)}: ${latest.targetLabel}';
  }

  String _threadSubtitle(MemoryThreadSummary thread) {
    final latest = thread.latestMessage;
    final sender = latest.createdByUserName.trim().isEmpty
        ? 'Unknown'
        : latest.createdByUserName.trim();
    return '$sender: ${latest.message}';
  }

  String _formatTargetType(String value) {
    switch (value) {
      case MemoryModel.targetTask:
        return 'Task';
      case MemoryModel.targetBoard:
        return 'Board';
      default:
        return 'User';
    }
  }

  String _thoughtLabel(String thoughtKey) {
    switch (thoughtKey) {
      case NavigationProvider.memoryBankThoughtBoardInvites:
        return 'Board Invites';
      case NavigationProvider.memoryBankThoughtTaskAssignments:
        return 'Task Assignments';
      case NavigationProvider.memoryBankThoughtSuggestions:
        return 'Suggestions';
      case NavigationProvider.memoryBankThoughtFeedback:
        return 'Feedback';
      case NavigationProvider.memoryBankThoughtReminders:
        return 'Reminders';
      default:
        return 'Thoughts';
    }
  }

  String _notificationThoughtKey(InAppNotification notif) {
    final category = (notif.category ?? '').trim().toLowerCase();
    final metadata = notif.metadata ?? const <String, dynamic>{};
    final kind = (metadata['kind']?.toString() ?? '').trim().toLowerCase();
    final type = (metadata['type']?.toString() ?? '').trim().toLowerCase();
    final title = notif.title.toLowerCase();

    if (category == 'invitation') {
      return NavigationProvider.memoryBankThoughtBoardInvites;
    }
    if (category == 'task_assigned') {
      return NavigationProvider.memoryBankThoughtTaskAssignments;
    }
    if (category == 'approval' && kind == 'task_application') {
      return NavigationProvider.memoryBankThoughtTaskAssignments;
    }
    if (type.startsWith('suggestion_') || title.contains('suggestion')) {
      return NavigationProvider.memoryBankThoughtSuggestions;
    }
    if (category == 'approval') {
      return NavigationProvider.memoryBankThoughtFeedback;
    }
    if (category == 'task_deadline' ||
        category == 'reminder' ||
        kind == 'poke' ||
        kind == 'poke_reminder') {
      return NavigationProvider.memoryBankThoughtReminders;
    }
    return NavigationProvider.memoryBankThoughtFeedback;
  }

  List<InAppNotification> _thoughtNotifications(
    List<InAppNotification> notifications,
    String thoughtKey,
  ) {
    if (thoughtKey == NavigationProvider.memoryBankThoughtAll) {
      return notifications;
    }
    return notifications
        .where((notif) => _notificationThoughtKey(notif) == thoughtKey)
        .toList();
  }

  void _syncThoughtFromNavigation(NavigationProvider navigation) {
    final requestedThought = navigation.memoryBankThoughtKey;
    if (requestedThought == NavigationProvider.memoryBankThoughtAll) {
      _selectedThought = NavigationProvider.memoryBankThoughtBoardInvites;
      return;
    }
    _selectedThought = requestedThought;
  }

  bool _isPendingBoardInvite(BoardRequest request) {
    final isInvite =
        BoardRequest.normalizeType(request.boardReqType) ==
        BoardRequest.typeRecruitment;
    return isInvite && request.boardReqStatus == 'pending';
  }

  Future<void> _acceptBoardInvite(BoardRequest request) async {
    if (_processingInviteIds.contains(request.boardRequestId)) return;
    setState(() => _processingInviteIds.add(request.boardRequestId));
    try {
      await context.read<BoardRequestProvider>().approveRequest(
        request,
        responseMessage: 'Recruitment accepted',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined ${request.boardTitle}.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept invite: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processingInviteIds.remove(request.boardRequestId));
      }
    }
  }

  Future<void> _declineBoardInvite(BoardRequest request) async {
    if (_processingInviteIds.contains(request.boardRequestId)) return;
    setState(() => _processingInviteIds.add(request.boardRequestId));
    try {
      await context.read<BoardRequestProvider>().rejectRequest(
        request,
        responseMessage: 'Recruitment declined',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite declined.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to decline invite: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _processingInviteIds.remove(request.boardRequestId));
      }
    }
  }

  String _taskIdFromNotification(InAppNotification notif) {
    final metadata = notif.metadata ?? const <String, dynamic>{};
    final relatedId = (notif.relatedId ?? '').trim();

    // For task assignment requests, relatedId is the canonical task id.
    final category = (notif.category ?? '').trim().toLowerCase();
    if (category == 'task_assigned' && relatedId.isNotEmpty) {
      return relatedId;
    }

    final metadataTaskId = (metadata['taskId']?.toString() ?? '').trim();
    if (metadataTaskId.isNotEmpty) return metadataTaskId;

    // Only treat relatedId as taskId for other task-centric notifications.
    if (category == 'task_assigned' ||
        category == 'task_deadline' ||
        category == 'approval') {
      return relatedId;
    }
    return '';
  }

  bool _isSuggestionNotification(InAppNotification notif) {
    final metadata = notif.metadata ?? const <String, dynamic>{};
    final type = (metadata['type']?.toString() ?? '').trim().toLowerCase();
    final title = notif.title.toLowerCase();
    return type.startsWith('suggestion_') || title.contains('suggestion');
  }

  String _suggestionIdFromNotification(InAppNotification notif) {
    final metadata = notif.metadata ?? const <String, dynamic>{};
    final metadataSuggestionId =
        (metadata['suggestionId']?.toString() ?? '').trim();
    if (metadataSuggestionId.isNotEmpty) return metadataSuggestionId;
    if (_isSuggestionNotification(notif)) {
      return (notif.relatedId ?? '').trim();
    }
    return '';
  }

  Future<Map<String, dynamic>?> _resolveSuggestionById(String suggestionId) async {
    final normalized = suggestionId.trim();
    if (normalized.isEmpty) return null;
    final doc = await FirebaseFirestore.instance
        .collection('suggestions')
        .doc(normalized)
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }

  bool _isTaskAssignmentNotification(InAppNotification notif) {
    return (notif.category ?? '').trim().toLowerCase() == 'task_assigned' &&
        _taskIdFromNotification(notif).isNotEmpty;
  }

  String _assignmentDecision(InAppNotification notif) {
    final metadata = notif.metadata ?? const <String, dynamic>{};
    return (metadata['assignmentDecision']?.toString() ?? '')
        .trim()
        .toLowerCase();
  }

  Future<void> _markAssignmentDecision({
    required String notificationId,
    required String decision,
  }) async {
    await FirebaseFirestore.instance
        .collection('in_app_notifications')
        .doc(notificationId)
        .update({
      'metadata.assignmentDecision': decision,
      'metadata.assignmentRespondedAt': Timestamp.now(),
      'isRead': true,
      'readAt': Timestamp.now(),
    });
  }

  Future<void> _acceptTaskAssignment(InAppNotification notif) async {
    final notificationId = notif.notificationId;
    if (_processingAssignmentNotifIds.contains(notificationId)) return;
    final taskId = _taskIdFromNotification(notif);
    if (taskId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task reference is missing for this request.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _processingAssignmentNotifIds.add(notificationId));
    try {
      await context.read<TaskProvider>().acceptTask(taskId);
      await _markAssignmentDecision(
        notificationId: notificationId,
        decision: 'accepted',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task accepted.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept task: $e'),
          backgroundColor: Colors.red,
        ),
      );

      final errorText = e.toString().toLowerCase();
      final alreadyHandled = errorText.contains('no pending assignment');
      if (alreadyHandled) {
        try {
          await _markAssignmentDecision(
            notificationId: notificationId,
            decision: 'accepted',
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assignment already handled. Marked as accepted.'),
              backgroundColor: Colors.orange,
            ),
          );
        } catch (_) {
          // Keep original error feedback if metadata update also fails.
        }
      }
    } finally {
      if (mounted) {
        setState(() => _processingAssignmentNotifIds.remove(notificationId));
      }
    }
  }

  Future<void> _declineTaskAssignment(InAppNotification notif) async {
    final notificationId = notif.notificationId;
    if (_processingAssignmentNotifIds.contains(notificationId)) return;
    final taskId = _taskIdFromNotification(notif);
    if (taskId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task reference is missing for this request.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _processingAssignmentNotifIds.add(notificationId));
    try {
      await context.read<TaskProvider>().declineTask(taskId);
      await _markAssignmentDecision(
        notificationId: notificationId,
        decision: 'declined',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task declined.'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to decline task: $e'),
          backgroundColor: Colors.red,
        ),
      );

      final errorText = e.toString().toLowerCase();
      final alreadyHandled = errorText.contains('no pending assignment');
      if (alreadyHandled) {
        try {
          await _markAssignmentDecision(
            notificationId: notificationId,
            decision: 'declined',
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assignment already handled. Marked as declined.'),
              backgroundColor: Colors.orange,
            ),
          );
        } catch (_) {
          // Keep original error feedback if metadata update also fails.
        }
      }
    } finally {
      if (mounted) {
        setState(() => _processingAssignmentNotifIds.remove(notificationId));
      }
    }
  }

  String _boardIdFromNotification(InAppNotification notif) {
    final metadata = notif.metadata ?? const <String, dynamic>{};
    final metadataBoardId = (metadata['boardId']?.toString() ?? '').trim();
    if (metadataBoardId.isNotEmpty) return metadataBoardId;

    final category = (notif.category ?? '').trim().toLowerCase();
    final relatedId = (notif.relatedId ?? '').trim();
    if (category == 'invitation' && relatedId.isNotEmpty) {
      return relatedId;
    }
    return '';
  }

  Future<Board?> _resolveBoardById(String boardId) async {
    final normalized = boardId.trim();
    if (normalized.isEmpty) return null;

    final providerBoard = context.read<BoardProvider>().getBoardById(normalized);
    if (providerBoard != null) return providerBoard;

    final doc = await FirebaseFirestore.instance.collection('boards').doc(normalized).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return Board.fromMap(data, doc.id);
  }

  Future<Task?> _resolveTaskById(String taskId) async {
    final normalized = taskId.trim();
    if (normalized.isEmpty) return null;

    final localTask = context.read<TaskProvider>().tasks.where((t) => t.taskId == normalized);
    if (localTask.isNotEmpty) return localTask.first;

    final doc = await FirebaseFirestore.instance.collection('tasks').doc(normalized).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;
    return Task.fromMap(data, doc.id);
  }

  Future<void> _openBoardFromInvite(BoardRequest invite) async {
    final status = invite.boardReqStatus.trim().toLowerCase();
    if (status != 'approved') {
      if (!mounted) return;
      final message = status == 'rejected'
          ? 'This invite was declined.'
          : 'Accept this invite first to open the board.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    try {
      final board = await _resolveBoardById(invite.boardId);
      if (!mounted) return;
      if (board == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Board not found.')),
        );
        return;
      }
      context.read<NavigationProvider>().selectFromBottomNav(1);
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BoardDetailsPage(board: board)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open board right now.')),
      );
    }
  }

  Future<void> _openTargetFromThought(InAppNotification notif) async {
    try {
      if (_isSuggestionNotification(notif)) {
        final metadata = notif.metadata ?? const <String, dynamic>{};
        var boardId = (metadata['boardId']?.toString() ?? '').trim();
        var taskId = (metadata['convertedTaskId']?.toString() ?? '').trim();

        if (boardId.isEmpty && taskId.isEmpty) {
          final suggestionId = _suggestionIdFromNotification(notif);
          if (suggestionId.isNotEmpty) {
            final suggestionData = await _resolveSuggestionById(suggestionId);
            if (suggestionData != null) {
              boardId =
                  (suggestionData['suggestionBoardId']?.toString() ?? '').trim();
              taskId = (suggestionData['suggestionConvertedTaskId']?.toString() ??
                      '')
                  .trim();
            }
          }
        }

        if (taskId.isNotEmpty) {
          final task = await _resolveTaskById(taskId);
          if (!mounted) return;
          if (task != null) {
            context.read<NavigationProvider>().selectFromBottomNav(1);
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => TaskDetailsPage(task: task)),
            );
            return;
          }
        }

        if (boardId.isNotEmpty) {
          final board = await _resolveBoardById(boardId);
          if (!mounted) return;
          if (board != null) {
            context.read<NavigationProvider>().selectFromBottomNav(1);
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BoardDetailsPage(
                  board: board,
                  initialTab: 'drafts',
                ),
              ),
            );
            return;
          }
        }
      }

      final taskId = _taskIdFromNotification(notif);
      if (taskId.isNotEmpty) {
        final task = await _resolveTaskById(taskId);
        if (!mounted) return;
        if (task == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task not found.')),
          );
          return;
        }
        context.read<NavigationProvider>().selectFromBottomNav(1);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TaskDetailsPage(task: task)),
        );
        return;
      }

      final boardId = _boardIdFromNotification(notif);
      if (boardId.isNotEmpty) {
        final board = await _resolveBoardById(boardId);
        if (!mounted) return;
        if (board == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Board not found.')),
          );
          return;
        }
        context.read<NavigationProvider>().selectFromBottomNav(1);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BoardDetailsPage(board: board)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this thought target.')),
      );
    }
  }

  Widget _buildSelectCard({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    int unreadCount = 0,
  }) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? Colors.blue.shade700 : Colors.grey.shade700,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.blue.shade700 : Colors.grey.shade800,
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? Colors.blue.shade700 : Colors.grey.shade700,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: selected ? Colors.blue.shade700 : Colors.grey.shade800,
      ),
      selectedColor: Colors.blue.shade50,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(
        color: selected ? Colors.blue.shade400 : Colors.grey.shade300,
        width: selected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildThoughtTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    int unreadCount = 0,
  }) {
    final borderColor = selected ? Colors.blue.shade400 : Colors.grey.shade300;
    final backgroundColor = selected ? Colors.blue.shade50 : Colors.grey.shade100;
    final textColor = selected ? Colors.blue.shade700 : Colors.grey.shade800;
    final iconColor = selected ? Colors.blue.shade700 : Colors.grey.shade700;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: selected ? 1.4 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected ? Colors.blue.shade700 : Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  int _unreadThoughtCount({
    required String thoughtKey,
    required List<InAppNotification> notifications,
    required List<BoardRequest> incomingInvites,
  }) {
    final pendingInviteCount = incomingInvites.where(_isPendingBoardInvite).length;
    final unreadNotifications = notifications.where((notif) => !notif.isRead).toList();

    if (thoughtKey == NavigationProvider.memoryBankThoughtAll) {
      return unreadNotifications.length + pendingInviteCount;
    }

    if (thoughtKey == NavigationProvider.memoryBankThoughtBoardInvites) {
      return pendingInviteCount;
    }

    return unreadNotifications
        .where((notif) => _notificationThoughtKey(notif) == thoughtKey)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<NavigationProvider>();
    _syncThoughtFromNavigation(navigation);
    final pokeProvider = context.watch<MemoryProvider>();
    final boardRequestProvider = context.watch<BoardRequestProvider>();
    final inAppProvider = context.watch<InAppNotificationProvider>();
    final unreadCountByThought = <String, int>{
      NavigationProvider.memoryBankThoughtBoardInvites: _unreadThoughtCount(
        thoughtKey: NavigationProvider.memoryBankThoughtBoardInvites,
        notifications: inAppProvider.notifications,
        incomingInvites: boardRequestProvider.invitations,
      ),
      NavigationProvider.memoryBankThoughtTaskAssignments: _unreadThoughtCount(
        thoughtKey: NavigationProvider.memoryBankThoughtTaskAssignments,
        notifications: inAppProvider.notifications,
        incomingInvites: boardRequestProvider.invitations,
      ),
      NavigationProvider.memoryBankThoughtFeedback: _unreadThoughtCount(
        thoughtKey: NavigationProvider.memoryBankThoughtFeedback,
        notifications: inAppProvider.notifications,
        incomingInvites: boardRequestProvider.invitations,
      ),
      NavigationProvider.memoryBankThoughtSuggestions: _unreadThoughtCount(
        thoughtKey: NavigationProvider.memoryBankThoughtSuggestions,
        notifications: inAppProvider.notifications,
        incomingInvites: boardRequestProvider.invitations,
      ),
      NavigationProvider.memoryBankThoughtReminders: _unreadThoughtCount(
        thoughtKey: NavigationProvider.memoryBankThoughtReminders,
        notifications: inAppProvider.notifications,
        incomingInvites: boardRequestProvider.invitations,
      ),
    };
    if (widget.composeOnly) {
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: _buildComposeSection(
              pokeProvider,
              updater: setState,
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Row(
                    children: [
                      const Icon(Icons.memory_outlined),
                      const SizedBox(width: 8),
                      const Text(
                        'Memory Bank',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Thoughts are grouped by type so actions can happen here.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildThoughtTab(
                          label: 'Board Invites',
                          icon: Icons.mail_outline,
                          selected:
                              _selectedThought ==
                              NavigationProvider.memoryBankThoughtBoardInvites,
                          unreadCount: unreadCountByThought[
                                  NavigationProvider.memoryBankThoughtBoardInvites] ??
                              0,
                          onTap: () {
                            context.read<NavigationProvider>().setMemoryBankThought(
                              NavigationProvider.memoryBankThoughtBoardInvites,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildThoughtTab(
                          label: 'Task Assignments',
                          icon: Icons.assignment_ind_outlined,
                          selected:
                              _selectedThought ==
                              NavigationProvider.memoryBankThoughtTaskAssignments,
                          unreadCount: unreadCountByThought[
                                  NavigationProvider.memoryBankThoughtTaskAssignments] ??
                              0,
                          onTap: () {
                            context.read<NavigationProvider>().setMemoryBankThought(
                              NavigationProvider.memoryBankThoughtTaskAssignments,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildThoughtTab(
                          label: 'Feedback',
                          icon: Icons.feedback_outlined,
                          selected:
                              _selectedThought ==
                              NavigationProvider.memoryBankThoughtFeedback,
                          unreadCount: unreadCountByThought[
                                  NavigationProvider.memoryBankThoughtFeedback] ??
                              0,
                          onTap: () {
                            context.read<NavigationProvider>().setMemoryBankThought(
                              NavigationProvider.memoryBankThoughtFeedback,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildThoughtTab(
                          label: 'Suggestions',
                          icon: Icons.lightbulb_outline,
                          selected:
                              _selectedThought ==
                              NavigationProvider.memoryBankThoughtSuggestions,
                          unreadCount: unreadCountByThought[
                                  NavigationProvider.memoryBankThoughtSuggestions] ??
                              0,
                          onTap: () {
                            context.read<NavigationProvider>().setMemoryBankThought(
                              NavigationProvider.memoryBankThoughtSuggestions,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildThoughtTab(
                          label: 'Reminders',
                          icon: Icons.alarm_outlined,
                          selected:
                              _selectedThought ==
                              NavigationProvider.memoryBankThoughtReminders,
                          unreadCount: unreadCountByThought[
                                  NavigationProvider.memoryBankThoughtReminders] ??
                              0,
                          onTap: () {
                            context.read<NavigationProvider>().setMemoryBankThought(
                              NavigationProvider.memoryBankThoughtReminders,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      final offsetAnimation = Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(animation);
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: offsetAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: KeyedSubtree(
                      key: ValueKey<String>(_selectedThought),
                      child: _buildThoughtsSection(
                        pokeProvider: pokeProvider,
                        boardRequestProvider: boardRequestProvider,
                        inAppProvider: inAppProvider,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton.extended(
            onPressed: () => _openComposeSheet(pokeProvider),
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('New Thought'),
          ),
        ),
      ],
    );
  }

  String _detailedNotificationTitle(InAppNotification notif) {
    final title = notif.title.trim();
    if (title.isNotEmpty) return title;
    return _fallbackThoughtText(notif);
  }

  String _detailedNotificationSubtitle(InAppNotification notif) {
    final message = notif.message.trim();
    if (message.isNotEmpty) return message;
    final metadata = notif.metadata ?? const <String, dynamic>{};
    final taskSummary = (metadata['taskSummary']?.toString() ?? '').trim();
    if (taskSummary.isNotEmpty) return taskSummary;
    return '';
  }

  String _fallbackThoughtText(InAppNotification notif) {
    final category = (notif.category ?? '').trim().toLowerCase();
    final metadata = notif.metadata ?? const <String, dynamic>{};
    final kind = (metadata['kind']?.toString() ?? '').trim().toLowerCase();
    final type = (metadata['type']?.toString() ?? '').trim().toLowerCase();
    final title = notif.title.toLowerCase();

    if (kind == 'poke' || kind == 'poke_reminder') {
      return 'You received a reminder thought.';
    }
    if (type.startsWith('suggestion_') || title.contains('suggestion')) {
      return 'You received feedback.';
    }
    if (category == 'task_assigned') {
      return 'You have a task assignment update.';
    }
    if (category == 'approval') {
      return 'You have a feedback update.';
    }
    if (category == 'invitation') {
      return 'You received a board invitation.';
    }
    if (category == 'task_deadline') {
      return 'You have a task deadline reminder.';
    }
    if (category == 'reminder') {
      return 'You have a reminder.';
    }
    final fallback = notif.message.trim();
    if (fallback.isEmpty) {
      return 'You have a new thought.';
    }
    return fallback;
  }

  Widget _buildThoughtsSection({
    required MemoryProvider pokeProvider,
    required BoardRequestProvider boardRequestProvider,
    required InAppNotificationProvider inAppProvider,
  }) {
    final incomingInvites = boardRequestProvider.invitations.toList()
      ..sort((a, b) => b.boardReqCreatedAt.compareTo(a.boardReqCreatedAt));
    final thoughtNotifs = _thoughtNotifications(
      inAppProvider.notifications,
      _selectedThought,
    )..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (_selectedThought == NavigationProvider.memoryBankThoughtBoardInvites) {
      if (incomingInvites.isEmpty) {
        return Center(
          child: Text(
            'No Board Invites yet.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
        itemCount: incomingInvites.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade300),
        itemBuilder: (context, index) {
          final invite = incomingInvites[index];
          final isPending = _isPendingBoardInvite(invite);
          final isBusy = _processingInviteIds.contains(invite.boardRequestId);
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openBoardFromInvite(invite),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.mail_outline),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Board invite: ${invite.boardTitle}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'From ${invite.boardManagerName}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeago.format(invite.boardReqCreatedAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildRequestStatusChip(invite.boardReqStatus),
                      ],
                    ),
                    if (isPending) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: isBusy ? null : () => _acceptBoardInvite(invite),
                              child: Text(isBusy ? 'Working...' : 'Accept'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isBusy ? null : () => _declineBoardInvite(invite),
                              child: const Text('Decline'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    if (_selectedThought == NavigationProvider.memoryBankThoughtAll &&
        thoughtNotifs.isEmpty &&
        pokeProvider.threadSummaries.isNotEmpty) {
      return _buildMailboxSection(pokeProvider);
    }

    if (thoughtNotifs.isEmpty) {
      return Center(
        child: Text(
          'No ${_thoughtLabel(_selectedThought)} yet.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
      itemCount: thoughtNotifs.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade300),
      itemBuilder: (context, index) {
        final notif = thoughtNotifs[index];
        final isTaskAssignment = _isTaskAssignmentNotification(notif);
        final decision = _assignmentDecision(notif);
        final hasDecision = decision == 'accepted' || decision == 'declined';
        final isBusy = _processingAssignmentNotifIds.contains(notif.notificationId);
        final subtitle = _detailedNotificationSubtitle(notif);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openTargetFromThought(notif),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _detailedNotificationTitle(notif),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              timeago.format(notif.createdAt),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      if (hasDecision)
                        _buildDecisionChip(decision),
                    ],
                  ),
                  if (isTaskAssignment && !hasDecision) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: isBusy ? null : () => _acceptTaskAssignment(notif),
                            child: Text(isBusy ? 'Working...' : 'Accept'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isBusy ? null : () => _declineTaskAssignment(notif),
                            child: const Text('Decline'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestStatusChip(String status) {
    final normalized = status.trim().toLowerCase();
    final (Color color, String label) = switch (normalized) {
      'approved' => (Colors.green, 'Accepted'),
      'rejected' => (Colors.red, 'Declined'),
      _ => (Colors.orange, 'Pending'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDecisionChip(String decision) {
    final isAccepted = decision == 'accepted';
    final color = isAccepted ? Colors.green : Colors.red;
    final label = isAccepted ? 'Accepted' : 'Declined';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMailboxSection(MemoryProvider provider) {
    final threads = provider.threadSummaries;
    if (threads.isEmpty) {
      return Center(
        child: Text(
          'No conversations yet',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
      itemCount: threads.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade300),
      itemBuilder: (context, index) {
        final thread = threads[index];
        final sender = thread.latestMessage.createdByUserName.trim().isEmpty
            ? 'Unknown'
            : thread.latestMessage.createdByUserName.trim();
        final subject = _threadTitle(thread);
        final preview = _threadSubtitle(thread);

        return Material(
          color: Colors.white,
          child: InkWell(
            onTap: () => _openThread(thread),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Text(
                      sender.isEmpty ? '?' : sender[0].toUpperCase(),
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sender,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeago.format(thread.updatedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComposeSection(
    MemoryProvider pokeProvider, {
    required void Function(VoidCallback fn) updater,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'New Thought',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Send reminder-style messages to users, boards, or tasks.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
            const Text(
              'Target Type',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSelectCard(
                  label: 'User',
                  icon: Icons.person_outline,
                  selected: _targetType == MemoryModel.targetUser,
                  onTap: () {
                    _onTargetTypeChanged(MemoryModel.targetUser).then((_) {
                      updater(() {});
                    });
                  },
                ),
                _buildSelectCard(
                  label: 'Board',
                  icon: Icons.view_kanban_outlined,
                  selected: _targetType == MemoryModel.targetBoard,
                  onTap: () {
                    _onTargetTypeChanged(MemoryModel.targetBoard).then((_) {
                      updater(() {});
                    });
                  },
                ),
                _buildSelectCard(
                  label: 'Task',
                  icon: Icons.task_alt_outlined,
                  selected: _targetType == MemoryModel.targetTask,
                  onTap: () {
                    _onTargetTypeChanged(MemoryModel.targetTask).then((_) {
                      updater(() {});
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loadingTargets)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            DropdownButtonFormField<String>(
              initialValue: _selectedTargetId,
              isExpanded: true,
              items: _targetOptions
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option.id,
                      child: Text(
                        option.subtitle == null
                            ? option.label
                            : '${option.label} Â· ${option.subtitle!}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _loadingTargets || _targetOptions.isEmpty
                  ? null
                  : (value) => updater(() => _selectedTargetId = value),
              decoration: InputDecoration(
                labelText: 'Select ${_formatTargetType(_targetType)}',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            if (_isUserTarget) ...[
              TextField(
                controller: _subjectController,
                maxLength: 90,
                onChanged: (_) {
                  if (_subjectFieldError != null || _formErrorText != null) {
                    updater(() {
                      _subjectFieldError = null;
                      _formErrorText = null;
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Subject',
                  hintText: 'Example: Quick follow-up on your task',
                  helperText: 'Required.',
                  errorText: _subjectFieldError,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                maxLines: 4,
                maxLength: 400,
                onChanged: (_) {
                  if (_messageFieldError != null || _formErrorText != null) {
                    updater(() {
                      _messageFieldError = null;
                      _formErrorText = null;
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Message',
                  hintText: 'Share context, what you need, and expected timing.',
                  helperText: 'Required.',
                  errorText: _messageFieldError,
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedActionNeeded,
                isExpanded: true,
                items: _actionNeededOptions
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(
                          option,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => updater(() {
                  _selectedActionNeeded = value;
                  _actionNeededFieldError = null;
                  _formErrorText = null;
                }),
                decoration: InputDecoration(
                  labelText: 'Action Needed',
                  helperText: 'Required.',
                  errorText: _actionNeededFieldError,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _detailsController,
                maxLines: 4,
                maxLength: 400,
                onChanged: (_) {
                  if (_detailsFieldError != null || _formErrorText != null) {
                    updater(() {
                      _detailsFieldError = null;
                      _formErrorText = null;
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Details',
                  hintText: 'State the exact requirement, due date/time, and expected output.',
                  helperText: 'Minimum 15 characters.',
                  errorText: _detailsFieldError,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 4),
            const Text(
              'Schedule',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickScheduleDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      _scheduledDate == null
                          ? 'Set Date (Today)'
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
                        ? 'Set Time (Now)'
                        : _scheduledTime!.format(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Default is now. If you pick a future date/time, it will be scheduled for later.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            if (_formErrorText != null) ...[
              Text(
                _formErrorText!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: pokeProvider.isSubmitting ? null : _submitPoke,
                icon: const Icon(Icons.send),
                label: Text(pokeProvider.isSubmitting ? 'Sending...' : 'Send Thought'),
              ),
            ),
      ],
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


