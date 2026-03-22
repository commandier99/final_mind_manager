import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../boards/datasources/models/board_model.dart';
import '../../../../boards/datasources/models/board_roles.dart';
import '../../../../boards/datasources/providers/board_provider.dart';
import '../../../../notifications/datasources/models/notification_model.dart';
import '../../../../notifications/datasources/providers/notification_provider.dart';
import '../../../../tasks/datasources/models/task_model.dart';
import '../../../../tasks/datasources/services/task_services.dart';
import '../../../datasources/models/thought_model.dart';
import '../../../datasources/providers/thought_provider.dart';
import '../../../../../shared/features/users/datasources/models/user_model.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../../../shared/features/users/datasources/services/user_services.dart';
import 'package:uuid/uuid.dart';

class CreateThoughtDialog extends StatefulWidget {
  final String initialType;
  final String? initialBoardId;
  final String? initialTaskId;
  final String? initialSuggestionMode;
  final String? initialTaskAssignmentMode;
  final bool lockType;

  const CreateThoughtDialog({
    super.key,
    this.initialType = Thought.typeReminder,
    this.initialBoardId,
    this.initialTaskId,
    this.initialSuggestionMode,
    this.initialTaskAssignmentMode,
    this.lockType = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    String initialType = Thought.typeReminder,
    String? initialBoardId,
    String? initialTaskId,
    String? initialSuggestionMode,
    String? initialTaskAssignmentMode,
    bool lockType = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateThoughtDialog(
        initialType: initialType,
        initialBoardId: initialBoardId,
        initialTaskId: initialTaskId,
        initialSuggestionMode: initialSuggestionMode,
        initialTaskAssignmentMode: initialTaskAssignmentMode,
        lockType: lockType,
      ),
    );
  }

  @override
  State<CreateThoughtDialog> createState() => _CreateThoughtDialogState();
}

class _CreateThoughtDialogState extends State<CreateThoughtDialog> {
  static const String _boardRequestInvite = 'invite_member';
  static const String _boardRequestAccess = 'request_board_access';
  static const String _taskAssignmentManagerToMember = 'manager_to_member';
  static const String _taskAssignmentMemberToManager = 'member_to_manager';
  static const String _taskRequestDeadlineExtension = 'deadline_extension';
  static const String _suggestionTask = 'task';
  static const String _suggestionStep = 'step';
  static const Object _taskPickerCancelled = Object();
  static const Object _taskPickerClearSelection = Object();

  final _formKey = GlobalKey<FormState>();
  final Uuid _uuid = const Uuid();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final TaskService _taskService = TaskService();
  final UserService _userService = UserService();

  late String _selectedType;
  String _selectedBoardRequestMode = _boardRequestInvite;
  String _selectedInvitedRole = BoardRoles.member;
  String _selectedTaskAssignmentMode = _taskAssignmentManagerToMember;
  String _selectedSuggestionMode = _suggestionTask;
  DateTime? _requestedDeadlineDate;
  TimeOfDay? _requestedDeadlineTime;
  Board? _selectedBoard;
  Task? _selectedTask;
  UserModel? _selectedTargetUser;
  bool _isSubmitting = false;
  bool _isLoadingBoardContext = false;

  List<Task> _availableTasks = [];
  List<Task> _reminderTasks = [];
  List<Task> _stepSuggestionTasks = [];
  List<UserModel> _availableMembers = [];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    if (widget.initialSuggestionMode != null &&
        widget.initialSuggestionMode!.trim().isNotEmpty) {
      _selectedSuggestionMode = widget.initialSuggestionMode!.trim();
    }
    if (widget.initialTaskAssignmentMode != null &&
        widget.initialTaskAssignmentMode!.trim().isNotEmpty) {
      _selectedTaskAssignmentMode = widget.initialTaskAssignmentMode!.trim();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_selectedType == Thought.typeReminder ||
          _selectedType == Thought.typeTaskAssignment ||
          _selectedType == Thought.typeTaskRequest) {
        await _loadReminderTaskOptions();
      }
      if (_selectedType == Thought.typeSuggestion &&
          _selectedSuggestionMode == _suggestionStep) {
        await _loadStepSuggestionTaskOptions();
      }
      if (!mounted) return;
      if (widget.initialTaskId != null && widget.initialTaskId!.trim().isNotEmpty) {
        await _handleTaskSelection(widget.initialTaskId);
      } else if (widget.initialBoardId != null) {
        await _onBoardChanged(widget.initialBoardId);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final accent = _sheetAccentColor(context);
    final selectableBoards = _selectableBoardsFromContext(context);
    final suggestionOptions = _suggestionOptions;
    final hasSelectableBoards = selectableBoards.isNotEmpty;
    final hasSelectableMembers = _availableMembers.isNotEmpty;
    if (_selectedType == Thought.typeSuggestion &&
        suggestionOptions.isNotEmpty &&
        !suggestionOptions.any((option) => option.value == _selectedSuggestionMode)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedSuggestionMode = suggestionOptions.first.value;
          if (_selectedSuggestionMode == _suggestionTask) {
            _selectedTask = null;
          } else {
            _selectedBoard = null;
          }
          _selectedTargetUser = null;
        });
        if (_selectedSuggestionMode == _suggestionStep) {
          _loadStepSuggestionTaskOptions();
        }
        _syncDirectionalDefaults();
      });
    }
    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: Material(
            color: const Color(0xFFF7F9FC),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.18),
                        accent.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: accent.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 2,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      widget.lockType &&
                                              _selectedType ==
                                                  Thought.typeSuggestion
                                          ? 'Create Suggestion Thought'
                                          : 'Create Thought',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        _typeLabel(_selectedType),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: accent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                const SizedBox(height: 12),
                if (!widget.lockType)
                InkWell(
                  onTap: _isSubmitting ? null : _showThoughtTypePicker,
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: _fieldDecoration(
                      context,
                      label: 'Thought Type',
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(_typeLabel(_selectedType))),
                        const Icon(Icons.unfold_more_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
                if (widget.lockType)
                  InputDecorator(
                    decoration: _fieldDecoration(
                      context,
                      label: 'Thought Type',
                    ),
                    child: Text(_selectedType == Thought.typeSuggestion
                        ? 'Suggestion'
                        : _selectedType),
                  ),
                if (_selectedType == Thought.typeBoardRequest) ...[
                  const SizedBox(height: 12),
                  _buildChoiceSection(
                    context,
                    label: 'Request Flow',
                    selectedValue: _selectedBoardRequestMode,
                    options: const [
                      _ChoiceOption(_boardRequestInvite, 'Invite Member'),
                      _ChoiceOption(
                        _boardRequestAccess,
                        'Request Board Access',
                      ),
                    ],
                    onSelected: _isSubmitting
                        ? null
                        : (value) {
                            setState(() {
                              _selectedBoardRequestMode = value;
                              _selectedTargetUser = null;
                            });
                            _syncDirectionalDefaults();
                          },
                  ),
                ],
                if (_selectedType == Thought.typeTaskAssignment) ...[
                  const SizedBox(height: 12),
                  _buildChoiceSection(
                    context,
                    label: 'Assignment Flow',
                    selectedValue: _selectedTaskAssignmentMode,
                    options: const [
                      _ChoiceOption(
                        _taskAssignmentManagerToMember,
                        'Assign Member to Task',
                      ),
                      _ChoiceOption(
                        _taskAssignmentMemberToManager,
                        'Apply for Task',
                      ),
                    ],
                    onSelected: _isSubmitting
                        ? null
                        : (value) {
                            setState(() {
                              _selectedTaskAssignmentMode = value;
                              _selectedTargetUser = null;
                            });
                            _syncDirectionalDefaults();
                          },
                  ),
                ],
                if (_selectedType == Thought.typeTaskRequest) ...[
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: _fieldDecoration(
                      context,
                      label: 'Request Type',
                    ),
                    child: const Text('Deadline Extension'),
                  ),
                ],
                if (_selectedType == Thought.typeSuggestion) ...[
                  const SizedBox(height: 12),
                  _buildChoiceSection(
                    context,
                    label: 'Suggestion Type',
                    selectedValue: _selectedSuggestionMode,
                    options: suggestionOptions,
                    onSelected: _isSubmitting
                        ? null
                        : (value) {
                            setState(() {
                              _selectedSuggestionMode = value;
                              if (value == _suggestionTask) {
                                _selectedTask = null;
                              } else {
                                _selectedBoard = null;
                              }
                              _selectedTargetUser = null;
                            });
                            if (value == _suggestionStep) {
                              _loadStepSuggestionTaskOptions();
                            }
                            _syncDirectionalDefaults();
                          },
                  ),
                ],
                if (_selectedType != Thought.typeReminder &&
                    _selectedType != Thought.typeTaskAssignment &&
                    _selectedType != Thought.typeTaskRequest &&
                    !(_selectedType == Thought.typeSuggestion &&
                        _selectedSuggestionMode == _suggestionStep)) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedBoard?.boardId,
                    hint: Text(
                      hasSelectableBoards
                          ? 'Select a board'
                          : 'No boards available',
                    ),
                    decoration: _fieldDecoration(
                      context,
                      label: 'Board',
                    ),
                    items: [
                      ...selectableBoards
                          .map(
                            (board) => DropdownMenuItem<String?>(
                              value: board.boardId,
                              child: Text(board.boardTitle),
                            ),
                          ),
                    ],
                    onChanged: _isSubmitting || !hasSelectableBoards
                        ? null
                        : (boardId) => _onBoardChanged(boardId),
                  ),
                ],
                if ((_selectedType == Thought.typeReminder ||
                        _selectedType == Thought.typeTaskAssignment ||
                        _selectedType == Thought.typeTaskRequest ||
                        _selectedBoard != null ||
                        (_selectedType == Thought.typeSuggestion &&
                            _selectedSuggestionMode == _suggestionStep)) &&
                    _showsTaskSelector) ...[
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: _fieldDecoration(
                      context,
                      label: _taskFieldLabel,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : _showTaskPickerDialog,
                          icon: const Icon(Icons.task_alt_outlined),
                          label: Text(
                            _selectedTask == null
                                ? 'Select Task'
                                : _taskOptionLabel(_selectedTask!),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_selectedTask != null &&
                            !(_selectedType == Thought.typeTaskAssignment &&
                                _selectedTaskAssignmentMode ==
                                    _taskAssignmentMemberToManager &&
                                widget.initialTaskId != null &&
                                widget.initialTaskId!.trim().isNotEmpty)) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => _handleResolvedTaskSelection(null),
                            child: const Text('Clear Task Selection'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (_selectedType == Thought.typeTaskRequest) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : _pickRequestedDate,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            _requestedDeadlineDate == null
                                ? 'Choose Requested Date'
                                : _formatRequestedDate(_requestedDeadlineDate!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting || _requestedDeadlineDate == null
                              ? null
                              : _pickRequestedTime,
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text(
                            _requestedDeadlineTime == null
                                ? 'Choose Time'
                                : _requestedDeadlineTime!.format(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_selectedBoard != null && _showsMemberSelector) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedTargetUser?.userId,
                    hint: Text(
                      hasSelectableMembers
                          ? 'Select a member'
                          : 'No members available',
                    ),
                    decoration: _fieldDecoration(
                      context,
                      label: _memberFieldLabel,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(_noneMemberLabel),
                      ),
                      ..._availableMembers.map(
                        (user) => DropdownMenuItem<String?>(
                          value: user.userId,
                          child: Text(user.userName),
                        ),
                      ),
                    ],
                    onChanged: _isSubmitting || !hasSelectableMembers
                        ? null
                        : (userId) {
                            setState(() {
                              _selectedTargetUser = _findUserById(userId);
                            });
                          },
                  ),
                ],
                if (_selectedType == Thought.typeBoardRequest &&
                    _selectedBoardRequestMode == _boardRequestInvite) ...[
                  const SizedBox(height: 12),
                  _buildChoiceSection(
                    context,
                    label: 'Invited Role',
                    selectedValue: _selectedInvitedRole,
                    options: const [
                      _ChoiceOption(BoardRoles.member, 'Member'),
                      _ChoiceOption(BoardRoles.supervisor, 'Supervisor'),
                    ],
                    onSelected: _isSubmitting
                        ? null
                        : (value) {
                            setState(() {
                              _selectedInvitedRole = BoardRoles.normalize(value);
                            });
                          },
                  ),
                ],
                const SizedBox(height: 12),
                if (_usesAutomaticTitle)
                  InputDecorator(
                    decoration: _fieldDecoration(
                      context,
                      label: _titleFieldLabel,
                    ),
                    child: Text(
                      _resolvedTitleText.isEmpty
                          ? _automaticTitlePlaceholder
                          : _resolvedTitleText,
                      style: TextStyle(
                        color: _resolvedTitleText.isEmpty
                            ? Colors.grey.shade600
                            : Colors.black87,
                      ),
                    ),
                  )
                else
                  TextFormField(
                    controller: _titleController,
                    decoration: _fieldDecoration(
                      context,
                      label: _titleFieldLabel,
                      hint: _titleHintText,
                    ),
                    textInputAction:
                        _showsMessageField ? TextInputAction.next : TextInputAction.done,
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Please enter a title.';
                      }
                      return null;
                    },
                  ),
                if (_showsMessageField) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _messageController,
                    decoration: _fieldDecoration(
                      context,
                      label: _messageFieldLabel,
                      hint: _messageHintText,
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    minLines: 4,
                    validator: (value) {
                      if (_messageIsRequired && (value ?? '').trim().isEmpty) {
                        return 'Please enter a message.';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.tips_and_updates_outlined,
                        size: 18,
                        color: accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _helperText,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoadingBoardContext) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 3),
                ],
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child: Text(_isSubmitting ? 'Creating...' : 'Create'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD6DEE8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD6DEE8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _sheetAccentColor(context), width: 1.5),
      ),
    );
  }

  Widget _buildChoiceSection(
    BuildContext context, {
    required String label,
    required String selectedValue,
    required List<_ChoiceOption> options,
    required ValueChanged<String>? onSelected,
  }) {
    final accent = _sheetAccentColor(context);
    return InputDecorator(
      decoration: _fieldDecoration(context, label: label),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options.map((option) {
          final isSelected = option.value == selectedValue;
          return ChoiceChip(
            label: Text(option.label),
            selected: isSelected,
            onSelected: onSelected == null
                ? null
                : (_) => onSelected(option.value),
            selectedColor: accent.withValues(alpha: 0.16),
            side: BorderSide(
              color: isSelected
                  ? accent.withValues(alpha: 0.28)
                  : const Color(0xFFD6DEE8),
            ),
            labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? accent : Colors.black87,
            ),
            backgroundColor: Colors.white,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          );
        }).toList(),
      ),
    );
  }

  Color _sheetAccentColor(BuildContext context) {
    switch (_selectedType) {
      case Thought.typeBoardRequest:
        return const Color(0xFF2563EB);
      case Thought.typeTaskAssignment:
        return const Color(0xFF0F766E);
      case Thought.typeTaskRequest:
        return const Color(0xFFD97706);
      case Thought.typeSuggestion:
        return const Color(0xFFCA8A04);
      case Thought.typeSubmissionFeedback:
        return const Color(0xFF7C3AED);
      case Thought.typeReminder:
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case Thought.typeBoardRequest:
        return 'Board Request';
      case Thought.typeTaskAssignment:
        return 'Task Assignment';
      case Thought.typeTaskRequest:
        return 'Task Request';
      case Thought.typeSuggestion:
        return 'Suggestion';
      case Thought.typeSubmissionFeedback:
        return 'Submission';
      case Thought.typeReminder:
      default:
        return 'Reminder';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final userProvider = context.read<UserProvider>();
    final thoughtProvider = context.read<ThoughtProvider>();
    final boardProvider = context.read<BoardProvider>();
    final currentUser = userProvider.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No signed-in user found.')));
      return;
    }

    final validationError = _customValidationMessage();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final now = DateTime.now();
      final resolvedTargetUser = _resolvedTargetUser(currentUser);
      final notificationSeed = _uuid.v4();
      final requestedDeadline = _resolvedRequestedDeadline();
      final isBoardInvite =
          _selectedType == Thought.typeBoardRequest &&
          _selectedBoardRequestMode == _boardRequestInvite &&
          _selectedBoard != null &&
          resolvedTargetUser != null;
      final thought = Thought(
        thoughtId: '',
        type: _selectedType,
        status: _defaultStatusForType(_selectedType),
        scopeType: _selectedTask != null
            ? Thought.scopeTask
            : (_selectedBoard != null ? Thought.scopeBoard : Thought.scopeUser),
        boardId: _selectedBoard?.boardId ?? '',
        taskId: _selectedTask?.taskId ?? '',
        authorId: currentUser.userId,
        authorName: currentUser.userName.trim().isEmpty
            ? 'Unknown'
            : currentUser.userName.trim(),
        targetUserId: resolvedTargetUser?.userId ?? currentUser.userId,
        targetUserName: resolvedTargetUser?.userName ?? (
            currentUser.userName.trim().isEmpty ? 'Unknown' : currentUser.userName.trim()),
        title: _resolvedTitleText,
        message: _resolvedMessageText,
        createdAt: now,
        updatedAt: now,
        metadata: {
          'source': 'thoughts_page',
          if (_selectedBoard != null) 'boardTitle': _selectedBoard!.boardTitle,
          if (_selectedTask != null) 'taskTitle': _selectedTask!.taskTitle,
          if (_selectedTargetUser != null)
            'targetUserHandle': _selectedTargetUser!.userHandle,
          if (_selectedType == Thought.typeSuggestion)
            'suggestionTarget': _selectedSuggestionMode,
          if (_selectedType == Thought.typeBoardRequest)
            'requestDirection': _selectedBoardRequestMode,
          if (_selectedType == Thought.typeBoardRequest &&
              _selectedBoardRequestMode == _boardRequestInvite)
            'invitedRole': _selectedInvitedRole,
          if (_selectedType == Thought.typeTaskAssignment) ...{
            'assignmentDirection': _selectedTaskAssignmentMode,
            'assignmentAssigneeId': _resolvedAssignmentAssigneeId(currentUser),
            'assignmentAssigneeName': _resolvedAssignmentAssigneeName(currentUser),
          },
          if (_selectedType == Thought.typeTaskRequest) ...{
            'requestKind': _taskRequestDeadlineExtension,
            'requestedByUserId': currentUser.userId,
            'requestedByUserName': currentUser.userName,
            if (_selectedTask?.taskDeadline != null)
              'currentDeadline': _selectedTask!.taskDeadline!.toIso8601String(),
            if (requestedDeadline != null)
              'requestedDeadline': requestedDeadline.toIso8601String(),
          },
          'notificationSeed': notificationSeed,
          if (_selectedType == Thought.typeBoardRequest &&
              _selectedBoardRequestMode == _boardRequestAccess) ...{
            'requestedMemberId': currentUser.userId,
            'requestedMemberName': currentUser.userName,
          },
        },
      );

      final thoughtId = await thoughtProvider.createThought(thought);
      try {
        if (isBoardInvite) {
          await boardProvider.markPendingBoardInvite(
            boardId: _selectedBoard!.boardId,
            userId: resolvedTargetUser.userId,
            invitationThoughtId: thoughtId,
          );
        }
        await _createNotificationsForThought(
          thought: thought.copyWith(
            thoughtId: thoughtId,
            metadata: {
              ...(thought.metadata ?? const <String, dynamic>{}),
              'notificationSeed': notificationSeed,
            },
          ),
          currentUser: currentUser,
          resolvedTargetUser: resolvedTargetUser,
          notificationSeed: notificationSeed,
        );
      } catch (e) {
        if (_selectedType == Thought.typeBoardRequest &&
            _selectedBoardRequestMode == _boardRequestInvite) {
          await _rollbackBoardInviteIfPossible(
            boardProvider: boardProvider,
            boardId: _selectedBoard?.boardId,
            userId: resolvedTargetUser?.userId,
            thoughtProvider: thoughtProvider,
            thoughtId: thoughtId,
          );
          throw Exception(
            'Invite notifications could not be created, so the invite was cancelled. $e',
          );
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create thought: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _rollbackBoardInviteIfPossible({
    required BoardProvider? boardProvider,
    required String? boardId,
    required String? userId,
    required ThoughtProvider thoughtProvider,
    required String thoughtId,
  }) async {
    if (boardProvider != null &&
        (boardId ?? '').trim().isNotEmpty &&
        (userId ?? '').trim().isNotEmpty) {
      try {
        await boardProvider.clearPendingBoardInvite(
          boardId: boardId!.trim(),
          userId: userId!.trim(),
        );
      } catch (_) {
        // Best effort rollback. The original notification failure is still surfaced.
      }
    }

    try {
      await thoughtProvider.softDeleteThought(thoughtId);
    } catch (_) {
      // Best effort rollback. The original notification failure is still surfaced.
    }
  }

  String _defaultStatusForType(String type) {
    switch (type) {
      case Thought.typeBoardRequest:
      case Thought.typeTaskAssignment:
      case Thought.typeTaskRequest:
        return Thought.statusPending;
      case Thought.typeReminder:
      case Thought.typeSuggestion:
      case Thought.typeSubmissionFeedback:
      default:
        return Thought.statusOpen;
    }
  }

  String? _customValidationMessage() {
    final requiresBoard = {
      Thought.typeBoardRequest,
      Thought.typeSubmissionFeedback,
    }.contains(_selectedType);

    final suggestionNeedsBoard =
        _selectedType == Thought.typeSuggestion &&
        _selectedSuggestionMode == _suggestionTask;

    final requiresTask = {
      Thought.typeTaskAssignment,
      Thought.typeTaskRequest,
      Thought.typeSubmissionFeedback,
    }.contains(_selectedType);

    final suggestionNeedsTask =
        _selectedType == Thought.typeSuggestion &&
        _selectedSuggestionMode == _suggestionStep;

    final needsMemberTarget =
        (_selectedType == Thought.typeBoardRequest &&
            _selectedBoardRequestMode == _boardRequestInvite) ||
        (_selectedType == Thought.typeTaskAssignment &&
            _selectedTaskAssignmentMode == _taskAssignmentManagerToMember);

    if ((requiresBoard || suggestionNeedsBoard) && _selectedBoard == null) {
      return 'Please choose a board for this thought type.';
    }
    if (requiresTask && _selectedTask == null) {
      return 'Please choose a task for this thought type.';
    }
    if (suggestionNeedsTask && _selectedTask == null) {
      return 'Please choose a task for this step suggestion.';
    }
    if (_selectedType == Thought.typeReminder && _selectedTask == null) {
      return 'Please choose a task for this reminder.';
    }
    if (_selectedType == Thought.typeBoardRequest &&
        _selectedBoardRequestMode == _boardRequestInvite &&
        _selectedBoard != null &&
        _selectedBoard!.boardType.trim().toLowerCase() != 'team') {
      return 'Only Team boards can invite members.';
    }
    if (_selectedType == Thought.typeTaskRequest && _resolvedRequestedDeadline() == null) {
      return 'Please choose the requested extended deadline.';
    }
    if (needsMemberTarget && _selectedTargetUser == null) {
      return 'Please choose a target member for this thought type.';
    }
    if (_selectedType == Thought.typeTaskRequest &&
        _selectedTask?.taskDeadline != null &&
        _resolvedRequestedDeadline() != null &&
        !_resolvedRequestedDeadline()!.isAfter(_selectedTask!.taskDeadline!)) {
      return 'Requested deadline must be later than the current deadline.';
    }
    return null;
  }

  String get _taskFieldLabel {
    if (_selectedType == Thought.typeReminder) {
      return 'Related Task';
    }
    if (_selectedType == Thought.typeSubmissionFeedback) {
      return 'Task for Submission';
    }
    if (_selectedType == Thought.typeTaskAssignment) {
      return 'Task Selection';
    }
    if (_selectedType == Thought.typeTaskRequest) {
      return 'Task Selection';
    }
    if (_selectedType == Thought.typeSuggestion) {
      return _selectedSuggestionMode == _suggestionStep
          ? 'Task for Step Suggestion'
          : 'Related Task';
    }
    return 'Task';
  }

  String get _memberFieldLabel {
    switch (_selectedType) {
      case Thought.typeReminder:
        return 'Target User (Auto-filled)';
      case Thought.typeBoardRequest:
        return _selectedBoardRequestMode == _boardRequestAccess
            ? 'Board Manager'
            : 'Invited Member';
      case Thought.typeTaskAssignment:
        return _selectedTaskAssignmentMode == _taskAssignmentMemberToManager
            ? 'Approver'
            : 'Target Member';
      case Thought.typeSuggestion:
        return 'Recipient (Auto-filled)';
      case Thought.typeSubmissionFeedback:
        return 'Submission Recipient';
      default:
        return 'Member';
    }
  }

  String get _noneMemberLabel {
    if (_selectedType == Thought.typeReminder) {
      return 'No user target';
    }
    if (_selectedType == Thought.typeSuggestion ||
        _selectedType == Thought.typeSubmissionFeedback) {
      return 'No specific member';
    }
    if (_selectedType == Thought.typeBoardRequest &&
        _selectedBoardRequestMode == _boardRequestAccess) {
      return 'Board manager will be chosen automatically';
    }
    if (_selectedType == Thought.typeTaskAssignment &&
        _selectedTaskAssignmentMode == _taskAssignmentMemberToManager) {
      return 'Manager will be chosen automatically';
    }
    return 'Select member';
  }

  String get _helperText {
    switch (_selectedType) {
      case Thought.typeReminder:
        return 'Choose a task and the reminder will auto-fill the assigned user for you.';
      case Thought.typeBoardRequest:
        return _selectedBoardRequestMode == _boardRequestAccess
            ? 'Request access sends the thought to the board manager, who can accept or decline.'
            : 'Invite member sends the thought to the selected member and registers a pending board invite.';
      case Thought.typeTaskAssignment:
        return _selectedTaskAssignmentMode == _taskAssignmentMemberToManager
            ? 'Apply for Task sends your application for the selected unassigned task to the board manager.'
            : 'Assign Member to Task sends the selected unassigned task to the chosen member.';
      case Thought.typeTaskRequest:
        return 'Deadline Extension sends the request to the board manager for approval.';
      case Thought.typeSuggestion:
        return _selectedSuggestionMode == _suggestionStep
            ? 'Step suggestions are only available to managers and supervisors, and go to the selected task assignee.'
            : 'Task suggestions go directly to the board manager.';
      case Thought.typeSubmissionFeedback:
        return 'Submissions should be linked to a task. Feedback then becomes the reply that follows the submission.';
      default:
        return 'Create a thought and tie it to the right context.';
    }
  }

  Future<void> _onBoardChanged(String? boardId) async {
    final boardProvider = context.read<BoardProvider>();
    final currentUserId = context.read<UserProvider>().userId;
    final thoughtProvider = context.read<ThoughtProvider>();
    final board = _findBoardById(boardProvider.boards, boardId);

    setState(() {
      _selectedBoard = board;
      _selectedTask = null;
      _selectedTargetUser = null;
      _requestedDeadlineDate = null;
      _requestedDeadlineTime = null;
      _availableTasks = [];
      _availableMembers = [];
      _isLoadingBoardContext = board != null;
    });

    if (board == null) return;

    try {
      final taskSnapshot = await _taskService
          .streamTasksByBoardId(board.boardId)
          .first;
      final members = <UserModel>[];

      if (_selectedType == Thought.typeBoardRequest &&
          _selectedBoardRequestMode == _boardRequestInvite) {
        final pendingInviteIds = await thoughtProvider
            .getPendingBoardInviteTargetUserIds(board.boardId);
        final existingMemberIds = <String>{
          ...board.memberIds,
          board.boardManagerId,
        };
        final publicUsers = await _userService.streamPublicUsers().first;
        for (final user in publicUsers) {
          final userId = user.userId.trim();
          if (userId.isEmpty) continue;
          if (currentUserId != null && userId == currentUserId) continue;
          if (existingMemberIds.contains(userId)) continue;
          if (pendingInviteIds.contains(userId)) continue;
          members.add(user);
        }
      } else {
        final memberIds = <String>{...board.memberIds, board.boardManagerId};
        if (currentUserId != null && currentUserId.isNotEmpty) {
          memberIds.add(currentUserId);
        }

        for (final memberId in memberIds) {
          final user = await _userService.getUserById(memberId);
          if (user != null) {
            members.add(user);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _availableTasks = taskSnapshot
            .where((task) => !task.taskIsDeleted)
            .toList();
        _availableMembers = members
          ..sort(
            (a, b) => a.userName.toLowerCase().compareTo(b.userName.toLowerCase()),
          );
        _isLoadingBoardContext = false;
      });
      _syncDirectionalDefaults();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingBoardContext = false;
      });
    }
  }

  bool get _usesAutomaticTitle =>
      _selectedType == Thought.typeTaskAssignment ||
      _selectedType == Thought.typeTaskRequest;

  bool get _showsMessageField =>
      !(_selectedType == Thought.typeSuggestion &&
          _selectedSuggestionMode == _suggestionStep);

  bool get _messageIsRequired => _showsMessageField;

  String get _titleFieldLabel {
    if (_selectedType == Thought.typeSuggestion) {
      return _selectedSuggestionMode == _suggestionStep
          ? 'Suggested Step Title'
          : 'Suggested Task Title';
    }
    return 'Title';
  }

  String get _titleHintText {
    if (_selectedType == Thought.typeSuggestion &&
        _selectedSuggestionMode == _suggestionTask) {
      return 'Provide a task title';
    }
    if (_selectedType == Thought.typeSuggestion &&
        _selectedSuggestionMode == _suggestionStep) {
      return 'Provide a step title';
    }
    return 'What is this thought about?';
  }

  String get _messageFieldLabel {
    if (_selectedType == Thought.typeSuggestion &&
        _selectedSuggestionMode == _suggestionTask) {
      return 'Suggested Task Description';
    }
    return 'Message';
  }

  String get _messageHintText {
    if (_selectedType == Thought.typeTaskAssignment) {
      return _selectedTaskAssignmentMode == _taskAssignmentMemberToManager
          ? 'Give a reason for why you should be assigned this task...'
          : "Give a reason for why you're assigning them the task...";
    }
    if (_selectedType == Thought.typeTaskRequest) {
      return 'Give a reason for why the deadline should be extended...';
    }
    if (_selectedType == Thought.typeSuggestion &&
        _selectedSuggestionMode == _suggestionTask) {
      return 'Provide a Task Description';
    }
    return 'Add the details for this thought.';
  }

  String get _automaticTitlePlaceholder {
    if (_selectedType == Thought.typeTaskAssignment) {
      return _selectedTaskAssignmentMode == _taskAssignmentMemberToManager
          ? 'Task Application for TaskTitle'
          : 'Task Assignment for TaskTitle from BoardTitle';
    }
    if (_selectedType == Thought.typeTaskRequest) {
      return 'Deadline Extension for TaskTitle';
    }
    return 'Title will be generated automatically';
  }

  String get _resolvedTitleText {
    if (_selectedType == Thought.typeTaskAssignment) {
      final taskTitle = _selectedTask?.taskTitle.trim() ?? '';
      if (taskTitle.isEmpty) return '';
      if (_selectedTaskAssignmentMode == _taskAssignmentMemberToManager) {
        return 'Task Application for $taskTitle';
      }
      final boardTitle = _selectedBoard?.boardTitle.trim() ?? '';
      if (boardTitle.isEmpty) {
        return 'Task Assignment for $taskTitle';
      }
      return 'Task Assignment for $taskTitle from $boardTitle';
    }
    if (_selectedType == Thought.typeTaskRequest) {
      final taskTitle = _selectedTask?.taskTitle.trim() ?? '';
      return taskTitle.isEmpty ? '' : 'Deadline Extension for $taskTitle';
    }
    return _titleController.text.trim();
  }

  String get _resolvedMessageText =>
      _showsMessageField ? _messageController.text.trim() : '';

  Future<void> _loadReminderTaskOptions() async {
    final boards = _selectableBoardsFromProvider(context.read<BoardProvider>());
    if (boards.isEmpty) {
      if (!mounted) return;
      setState(() {
        _reminderTasks = [];
      });
      return;
    }

    final tasks = <Task>[];
    for (final board in boards) {
      try {
        final boardTasks = await _taskService.streamTasksByBoardId(board.boardId).first;
        tasks.addAll(boardTasks.where((task) => !task.taskIsDeleted));
      } catch (_) {
        // Best effort: skip boards we cannot load here.
      }
    }

    if (!mounted) return;
    setState(() {
      _reminderTasks = tasks;
    });
  }

  Future<void> _loadStepSuggestionTaskOptions() async {
    final boardProvider = context.read<BoardProvider>();
    final currentUserId = context.read<UserProvider>().userId;
    final boards = _selectableBoardsFromProvider(boardProvider)
        .where((board) => board.canDraftTasks(currentUserId))
        .toList();

    if (boards.isEmpty) {
      if (!mounted) return;
      setState(() {
        _stepSuggestionTasks = [];
        _selectedTask = null;
        _selectedBoard = null;
        _selectedTargetUser = null;
      });
      return;
    }

    final tasks = <Task>[];
    for (final board in boards) {
      try {
        final boardTasks = await _taskService.streamTasksByBoardId(board.boardId).first;
        tasks.addAll(boardTasks.where((task) => !task.taskIsDeleted));
      } catch (_) {
        // Best effort: skip boards we cannot load here.
      }
    }

    if (!mounted) return;
    setState(() {
      _stepSuggestionTasks = tasks;
      if (_selectedTask != null &&
          !tasks.any((task) => task.taskId == _selectedTask!.taskId)) {
        _selectedTask = null;
        _selectedBoard = null;
        _selectedTargetUser = null;
      }
    });
  }

  Future<void> _handleTaskSelection(String? taskId) async {
    final task = _findTaskById(taskId);
    await _handleResolvedTaskSelection(task);
  }

  Future<void> _handleResolvedTaskSelection(Task? task) async {
    if (_selectedType != Thought.typeReminder) {
      final boards = context.read<BoardProvider>().boards;
      final board = task == null
          ? null
          : _findBoardById(boards, task.taskBoardId);
      if (task == null || board == null) {
        setState(() {
          _selectedTask = task;
          if (_selectedType == Thought.typeTaskAssignment ||
              _selectedType == Thought.typeTaskRequest ||
              (_selectedType == Thought.typeSuggestion &&
                  _selectedSuggestionMode == _suggestionStep)) {
            _selectedBoard = board;
          }
          _availableMembers = [];
          if (_selectedType == Thought.typeSuggestion &&
              _selectedSuggestionMode == _suggestionStep &&
              task == null) {
            _selectedTargetUser = null;
          }
        });
        _syncDirectionalDefaults();
        return;
      }

      final currentUserId = context.read<UserProvider>().userId;
      final memberIds = <String>{...board.memberIds, board.boardManagerId};
      if (currentUserId != null && currentUserId.isNotEmpty) {
        memberIds.add(currentUserId);
      }

      final members = <UserModel>[];
      for (final memberId in memberIds) {
        final user = await _userService.getUserById(memberId);
        if (user != null) {
          members.add(user);
        }
      }

      if (!mounted) return;
      setState(() {
        _selectedTask = task;
        if (_selectedType == Thought.typeTaskAssignment ||
            _selectedType == Thought.typeTaskRequest ||
            (_selectedType == Thought.typeSuggestion &&
                _selectedSuggestionMode == _suggestionStep)) {
          _selectedBoard = board;
        }
        _availableMembers = members
          ..sort((a, b) => a.userName.toLowerCase().compareTo(b.userName.toLowerCase()));
      });
      _syncDirectionalDefaults();
      return;
    }

    if (task == null) {
      setState(() {
        _selectedTask = null;
        _selectedTargetUser = null;
      });
      return;
    }

    final boards = context.read<BoardProvider>().boards;
    final board = _findBoardById(boards, task.taskBoardId);
    if (board == null) {
      setState(() {
        _selectedTask = task;
      });
      return;
    }

    final currentUserId = context.read<UserProvider>().userId;
    final memberIds = <String>{...board.memberIds, board.boardManagerId};
    if (currentUserId != null && currentUserId.isNotEmpty) {
      memberIds.add(currentUserId);
    }

    final members = <UserModel>[];
    for (final memberId in memberIds) {
      final user = await _userService.getUserById(memberId);
      if (user != null) {
        members.add(user);
      }
    }

    if (!mounted) return;
    setState(() {
      _selectedBoard = board;
      _selectedTask = task;
      _availableMembers = members
        ..sort((a, b) => a.userName.toLowerCase().compareTo(b.userName.toLowerCase()));
      _selectedTargetUser = _findUserById(task.taskAssignedTo);
    });
  }

  Future<void> _showTaskPickerDialog() async {
    final selectedTask = await showDialog<Object?>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _taskPickerTitle,
                          style: Theme.of(dialogContext).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(
                          dialogContext,
                        ).pop(_taskPickerCancelled),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: StreamBuilder<List<Task>>(
                    stream: _streamSelectableTasks(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final tasks = snapshot.data ?? const <Task>[];
                      if (tasks.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _emptyTaskPickerMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: tasks.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          final isSelected = _selectedTask?.taskId == task.taskId;
                          final boardTitle = _taskBoardTitle(task);
                          return ListTile(
                            leading: Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                            title: Text(task.taskTitle),
                            subtitle: Text(boardTitle),
                            trailing: task.taskDeadline == null
                                ? null
                                : Text(_formatRequestedDate(task.taskDeadline!)),
                            onTap: () => Navigator.of(dialogContext).pop(task),
                          );
                        },
                      );
                    },
                  ),
                ),
                if (!(_selectedType == Thought.typeSuggestion &&
                    _selectedSuggestionMode == _suggestionStep))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(
                          dialogContext,
                        ).pop(_taskPickerClearSelection),
                        child: const Text('No Task'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted ||
        selectedTask == null ||
        identical(selectedTask, _taskPickerCancelled)) {
      return;
    }
    if (identical(selectedTask, _taskPickerClearSelection)) {
      await _handleResolvedTaskSelection(null);
      return;
    }
    await _handleResolvedTaskSelection(selectedTask as Task);
  }

  Board? _findBoardById(List<Board> boards, String? boardId) {
    if (boardId == null || boardId.isEmpty) return null;
    for (final board in boards) {
      if (board.boardId == boardId) return board;
    }
    return null;
  }

  Task? _findTaskById(String? taskId) {
    if (taskId == null || taskId.isEmpty) return null;
    for (final task in _taskOptions) {
      if (task.taskId == taskId) return task;
    }
    return null;
  }

  List<Task> get _taskOptions =>
      _selectedType == Thought.typeReminder
          ? _reminderTasks
          : _selectedType == Thought.typeTaskAssignment
              ? _reminderTasks.where(_isUnassignedTask).toList()
              : _selectedType == Thought.typeTaskRequest
                  ? _reminderTasks
          : (_selectedType == Thought.typeSuggestion &&
                  _selectedSuggestionMode == _suggestionStep)
              ? _stepSuggestionTasks
              : _availableTasks;

  bool _isUnassignedTask(Task task) {
    final assignedTo = task.taskAssignedTo.trim();
    return assignedTo.isEmpty || assignedTo == 'None';
  }

  String _taskOptionLabel(Task task) {
    final boardTitle = _taskBoardTitle(task);
    return '$boardTitle | ${task.taskTitle}';
  }

  String _taskBoardTitle(Task task) {
    return (task.taskBoardTitle ?? '').trim().isNotEmpty
        ? task.taskBoardTitle!.trim()
        : (_findBoardById(context.read<BoardProvider>().boards, task.taskBoardId)
                  ?.boardTitle ??
              'Board');
  }

  String get _taskPickerTitle {
    if (_selectedType == Thought.typeTaskAssignment &&
        _selectedTaskAssignmentMode == _taskAssignmentMemberToManager) {
      return 'Select Task to Apply For';
    }
    return 'Select Task';
  }

  String get _emptyTaskPickerMessage {
    if (_selectedType == Thought.typeTaskAssignment &&
        _selectedTaskAssignmentMode == _taskAssignmentMemberToManager) {
      return 'No unassigned tasks are available right now.';
    }
    return 'No tasks are available right now.';
  }

  Stream<List<Task>> _streamSelectableTasks() {
    final boards = _taskSelectionBoards;
    if (boards.isEmpty) {
      return Stream<List<Task>>.value(const <Task>[]);
    }

    final controller = StreamController<List<Task>>();
    final latestTasksByBoard = <String, List<Task>>{};
    final subscriptions = <StreamSubscription<List<Task>>>[];

    void emitCombinedTasks() {
      final merged = latestTasksByBoard.values
          .expand((tasks) => tasks)
          .where(_taskMatchesCurrentSelectionRules)
          .toList()
        ..sort((a, b) {
          final boardCompare = _taskBoardTitle(
            a,
          ).toLowerCase().compareTo(_taskBoardTitle(b).toLowerCase());
          if (boardCompare != 0) return boardCompare;
          return a.taskTitle.toLowerCase().compareTo(b.taskTitle.toLowerCase());
        });
      controller.add(merged);
    }

    for (final board in boards) {
      final subscription = _taskService
          .streamTasksByBoardId(board.boardId)
          .listen((tasks) {
            latestTasksByBoard[board.boardId] = tasks
                .where((task) => !task.taskIsDeleted)
                .toList();
            emitCombinedTasks();
          }, onError: (_) {
            latestTasksByBoard[board.boardId] = const <Task>[];
            emitCombinedTasks();
          });
      subscriptions.add(subscription);
    }

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  List<Board> get _taskSelectionBoards {
    final boardProvider = context.read<BoardProvider>();
    final currentUserId = context.read<UserProvider>().userId;

    if (_selectedType == Thought.typeSuggestion &&
        _selectedSuggestionMode == _suggestionStep) {
      return _selectableBoardsFromProvider(boardProvider)
          .where((board) => board.canDraftTasks(currentUserId))
          .toList();
    }

    if (_selectedType == Thought.typeReminder ||
        _selectedType == Thought.typeTaskAssignment ||
        _selectedType == Thought.typeTaskRequest) {
      return _selectableBoardsFromProvider(boardProvider);
    }

    if (_selectedBoard != null) {
      return [_selectedBoard!];
    }

    return const <Board>[];
  }

  bool _taskMatchesCurrentSelectionRules(Task task) {
    if (task.taskIsDeleted) return false;

    if (_selectedType == Thought.typeTaskAssignment) {
      return _isUnassignedTask(task);
    }

    return true;
  }

  Future<void> _showThoughtTypePicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _thoughtTypeOptions.map((option) {
              final isSelected = option.value == _selectedType;
              return ListTile(
                title: Text(option.label),
                trailing: isSelected
                    ? Icon(Icons.check, color: _sheetAccentColor(context))
                    : null,
                onTap: () => Navigator.of(context).pop(option.value),
              );
            }).toList(),
          ),
        );
      },
    );

    if (!mounted || selected == null || selected == _selectedType) return;
    setState(() {
      _selectedType = selected;
      _selectedTargetUser = null;
      _selectedTask = null;
      if (selected != Thought.typeReminder) {
        _selectedBoard = null;
        _availableMembers = [];
      }
    });
    if (selected == Thought.typeReminder ||
        selected == Thought.typeTaskAssignment ||
        selected == Thought.typeTaskRequest) {
      _loadReminderTaskOptions();
    }
    _syncDirectionalDefaults();
  }

  List<Board> _selectableBoardsFromContext(BuildContext context) =>
      _selectableBoardsFromProvider(context.watch<BoardProvider>());

  List<Board> _selectableBoardsFromProvider(BoardProvider boardProvider) =>
      boardProvider.boards.where(_isSelectableBoard).toList();

  bool _isSelectableBoard(Board board) {
    final type = board.boardType.trim().toLowerCase();
    final title = board.boardTitle.trim().toLowerCase();
    return type != 'personal' && title != 'personal' && title != 'personal hq';
  }

  static const List<_ChoiceOption> _thoughtTypeOptions = [
    _ChoiceOption(Thought.typeReminder, 'Reminder'),
    _ChoiceOption(Thought.typeBoardRequest, 'Board Request'),
    _ChoiceOption(Thought.typeTaskAssignment, 'Task Assignment'),
    _ChoiceOption(Thought.typeTaskRequest, 'Task Request'),
    _ChoiceOption(Thought.typeSuggestion, 'Suggestion'),
    _ChoiceOption(Thought.typeSubmissionFeedback, 'Submission'),
  ];

  List<_ChoiceOption> get _suggestionOptions {
    final currentUserId = context.read<UserProvider>().userId;
    final selectableBoards = _selectableBoardsFromProvider(
      context.read<BoardProvider>(),
    );
    final canSuggestTasks = selectableBoards.any(
      (board) =>
          !board.isManager(currentUserId) &&
          (board.roleOf(currentUserId) == 'member' ||
              board.roleOf(currentUserId) == 'supervisor'),
    );
    final canSuggestSteps = selectableBoards.any(
      (board) => board.canDraftTasks(currentUserId),
    );

    return [
      if (canSuggestTasks)
        const _ChoiceOption(_suggestionTask, 'Task Suggestion'),
      if (canSuggestSteps)
        const _ChoiceOption(_suggestionStep, 'Step Suggestion'),
    ];
  }

  UserModel? _findUserById(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    for (final user in _availableMembers) {
      if (user.userId == userId) return user;
    }
    return null;
  }

  bool get _showsTaskSelector =>
      _selectedType == Thought.typeReminder ||
      _selectedType == Thought.typeTaskAssignment ||
      _selectedType == Thought.typeTaskRequest ||
      (_selectedType == Thought.typeSuggestion &&
          _selectedSuggestionMode == _suggestionStep) ||
      _selectedType == Thought.typeSubmissionFeedback;

  bool get _showsMemberSelector {
    if (_selectedType == Thought.typeReminder) return true;
    if (_selectedType == Thought.typeBoardRequest) {
      return _selectedBoardRequestMode == _boardRequestInvite;
    }
    if (_selectedType == Thought.typeTaskAssignment) {
      return _selectedTaskAssignmentMode == _taskAssignmentManagerToMember;
    }
    return false;
  }

  void _syncDirectionalDefaults() {
    if (!mounted) return;
    final currentUser = context.read<UserProvider>().currentUser;
    final board = _selectedBoard;
    if (board == null || currentUser == null) return;

    final manager = _findUserById(board.boardManagerId);
    setState(() {
      if (_selectedType == Thought.typeBoardRequest &&
          _selectedBoardRequestMode == _boardRequestAccess) {
        _selectedTargetUser = manager;
      }
      if (_selectedType == Thought.typeTaskAssignment &&
          _selectedTaskAssignmentMode == _taskAssignmentMemberToManager) {
        _selectedTargetUser = manager;
      }
      if (_selectedType == Thought.typeTaskRequest) {
        _selectedTargetUser = manager;
      }
      if (_selectedType == Thought.typeSuggestion) {
        if (_selectedSuggestionMode == _suggestionTask) {
          _selectedTargetUser = manager;
        } else if (_selectedTask != null) {
          _selectedTargetUser = _findUserById(_selectedTask!.taskAssignedTo);
        }
      }
      if (_selectedType == Thought.typeSubmissionFeedback) {
        _selectedTargetUser = manager;
      }
    });
  }

  UserModel? _resolvedTargetUser(UserModel currentUser) {
    if (_selectedType == Thought.typeBoardRequest &&
        _selectedBoardRequestMode == _boardRequestAccess) {
      return _findUserById(_selectedBoard?.boardManagerId) ?? _selectedTargetUser;
    }
    if (_selectedType == Thought.typeTaskAssignment &&
        _selectedTaskAssignmentMode == _taskAssignmentMemberToManager) {
      return _findUserById(_selectedBoard?.boardManagerId) ?? _selectedTargetUser;
    }
    if (_selectedType == Thought.typeTaskRequest) {
      return _findUserById(_selectedBoard?.boardManagerId) ?? _selectedTargetUser;
    }
    if (_selectedType == Thought.typeSuggestion) {
      if (_selectedSuggestionMode == _suggestionTask) {
        return _findUserById(_selectedBoard?.boardManagerId) ?? _selectedTargetUser;
      }
      return _findUserById(_selectedTask?.taskAssignedTo) ?? _selectedTargetUser;
    }
    if (_selectedType == Thought.typeSubmissionFeedback) {
      return _findUserById(_selectedBoard?.boardManagerId) ?? _selectedTargetUser;
    }
    return _selectedTargetUser;
  }

  String _resolvedAssignmentAssigneeId(UserModel currentUser) {
    if (_selectedTaskAssignmentMode == _taskAssignmentMemberToManager) {
      return currentUser.userId;
    }
    return _selectedTargetUser?.userId ?? currentUser.userId;
  }

  String _resolvedAssignmentAssigneeName(UserModel currentUser) {
    final currentUserName = currentUser.userName.trim().isEmpty
        ? 'Unknown'
        : currentUser.userName.trim();
    if (_selectedTaskAssignmentMode == _taskAssignmentMemberToManager) {
      return currentUserName;
    }
    final targetName = _selectedTargetUser?.userName.trim() ?? '';
    return targetName.isEmpty ? currentUserName : targetName;
  }

  DateTime? _resolvedRequestedDeadline() {
    final date = _requestedDeadlineDate;
    if (date == null) return null;
    final time = _requestedDeadlineTime ?? const TimeOfDay(hour: 17, minute: 0);
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _pickRequestedDate() async {
    final initialDate =
        _requestedDeadlineDate ??
        _selectedTask?.taskDeadline ??
        DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _requestedDeadlineDate = picked;
      _requestedDeadlineTime ??= const TimeOfDay(hour: 17, minute: 0);
    });
  }

  Future<void> _pickRequestedTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _requestedDeadlineTime ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _requestedDeadlineTime = picked;
    });
  }

  String _formatRequestedDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$month/$day/$year';
  }

  Future<void> _createNotificationsForThought({
    required Thought thought,
    required UserModel currentUser,
    required UserModel? resolvedTargetUser,
    required String notificationSeed,
  }) async {
    final notificationProvider = context.read<NotificationProvider>();
    final notifications = <AppNotification>[];
    final now = DateTime.now();
    final actorName = currentUser.userName.trim().isEmpty
        ? 'Unknown'
        : currentUser.userName.trim();
    final boardTitle = _selectedBoard?.boardTitle ?? 'Board';
    final taskTitle = _selectedTask?.taskTitle ?? 'task';
    final targetUser = resolvedTargetUser;
    final invitedRole = (thought.metadata?['invitedRole']?.toString() ?? '')
        .trim()
        .toLowerCase();
    final invitedRolePhrase = invitedRole == 'supervisor'
        ? ' as a Supervisor'
        : invitedRole == 'member'
        ? ' as a Member'
        : '';

    if (thought.type == Thought.typeBoardRequest) {
      if (_selectedBoardRequestMode == _boardRequestInvite &&
          targetUser != null &&
          targetUser.userId != currentUser.userId) {
        notifications.add(
          _buildNotification(
            now: now,
            recipientUserId: targetUser.userId,
            title: 'Board Invite Received',
            message: '$actorName invited you to join $boardTitle$invitedRolePhrase.',
            type: 'thought_board_invite_received',
            thought: thought,
            actorUserId: currentUser.userId,
            actorUserName: actorName,
            eventKey:
                '$notificationSeed:${targetUser.userId}:thought_board_invite_received',
            metadata: {
              'role': thought.metadata?['invitedRole'],
              'requestDirection': _selectedBoardRequestMode,
            },
          ),
        );
      } else if (_selectedBoardRequestMode == _boardRequestAccess &&
          targetUser != null &&
          targetUser.userId != currentUser.userId) {
        notifications.add(
          _buildNotification(
            now: now,
            recipientUserId: targetUser.userId,
            title: 'Board Access Request Received',
            message: '$actorName requested access to $boardTitle.',
            type: 'thought_board_request_received',
            thought: thought,
            actorUserId: currentUser.userId,
            actorUserName: actorName,
            eventKey:
                '$notificationSeed:${targetUser.userId}:thought_board_request_received',
            metadata: {
              'requestDirection': _selectedBoardRequestMode,
            },
          ),
        );
      }
    }

    if (thought.type == Thought.typeTaskAssignment && targetUser != null) {
      if (_selectedTaskAssignmentMode == _taskAssignmentManagerToMember &&
          targetUser.userId != currentUser.userId) {
        notifications.add(
          _buildNotification(
            now: now,
            recipientUserId: targetUser.userId,
            title: 'Task Assignment Received',
            message: '$actorName assigned you to $taskTitle.',
            type: 'thought_task_assignment_received',
            thought: thought,
            actorUserId: currentUser.userId,
            actorUserName: actorName,
            eventKey:
                '$notificationSeed:${targetUser.userId}:thought_task_assignment_received',
            metadata: {
              'assignmentDirection': _selectedTaskAssignmentMode,
            },
          ),
        );
      } else if (_selectedTaskAssignmentMode == _taskAssignmentMemberToManager &&
          targetUser.userId != currentUser.userId) {
        notifications.add(
          _buildNotification(
            now: now,
            recipientUserId: targetUser.userId,
            title: 'Task Request Received',
            message: '$actorName requested assignment to $taskTitle.',
            type: 'thought_task_request_received',
            thought: thought,
            actorUserId: currentUser.userId,
            actorUserName: actorName,
            eventKey:
                '$notificationSeed:${targetUser.userId}:thought_task_request_received',
            metadata: {
              'assignmentDirection': _selectedTaskAssignmentMode,
            },
          ),
        );
      }
    }

    if (thought.type == Thought.typeTaskRequest &&
        targetUser != null &&
        targetUser.userId != currentUser.userId) {
      final requestedDeadline = _resolvedRequestedDeadline();
      final requestedDeadlineLabel = requestedDeadline == null
          ? 'the requested date'
          : _formatRequestedDate(requestedDeadline);
      notifications.add(
        _buildNotification(
          now: now,
          recipientUserId: targetUser.userId,
          title: 'Deadline Extension Request Received',
          message: '$actorName requested a deadline extension for $taskTitle until $requestedDeadlineLabel.',
          type: 'thought_deadline_extension_request_received',
          thought: thought,
          actorUserId: currentUser.userId,
          actorUserName: actorName,
          eventKey:
              '$notificationSeed:${targetUser.userId}:thought_deadline_extension_request_received',
          metadata: {
            'requestKind': _taskRequestDeadlineExtension,
          },
        ),
      );
    }

    if (thought.type == Thought.typeSuggestion &&
        targetUser != null &&
        targetUser.userId != currentUser.userId) {
      final isStepSuggestion = _selectedSuggestionMode == _suggestionStep;
      final suggestionLabel = isStepSuggestion ? 'Step Suggestion' : 'Task Suggestion';
      final suggestionTargetLabel = isStepSuggestion
          ? (taskTitle.trim().isEmpty ? 'the selected task' : taskTitle)
          : boardTitle;
      notifications.add(
        _buildNotification(
          now: now,
          recipientUserId: targetUser.userId,
          title: '$suggestionLabel Received',
          message: '$actorName sent you a $suggestionLabel for $suggestionTargetLabel.',
          type: isStepSuggestion
              ? 'thought_step_suggestion_received'
              : 'thought_task_suggestion_received',
          thought: thought,
          actorUserId: currentUser.userId,
          actorUserName: actorName,
          eventKey:
              '$notificationSeed:${targetUser.userId}:${isStepSuggestion ? 'thought_step_suggestion_received' : 'thought_task_suggestion_received'}',
          metadata: {
            'suggestionTarget': _selectedSuggestionMode,
          },
        ),
      );
    }

    if (thought.type == Thought.typeReminder &&
        targetUser != null &&
        targetUser.userId != currentUser.userId) {
      notifications.add(
        _buildNotification(
          now: now,
          recipientUserId: targetUser.userId,
          title: 'Reminder Received',
          message: '$actorName sent you a reminder for $taskTitle.',
          type: 'thought_reminder_received',
          thought: thought,
          actorUserId: currentUser.userId,
          actorUserName: actorName,
          eventKey:
              '$notificationSeed:${targetUser.userId}:thought_reminder_received',
          metadata: const {
            'reminderType': 'task',
          },
        ),
      );
    }

    if (thought.type == Thought.typeSubmissionFeedback &&
        targetUser != null &&
        targetUser.userId != currentUser.userId) {
      notifications.add(
        _buildNotification(
          now: now,
          recipientUserId: targetUser.userId,
          title: 'Submission Received',
          message: '$actorName submitted work for $taskTitle.',
          type: 'thought_submission_received',
          thought: thought,
          actorUserId: currentUser.userId,
          actorUserName: actorName,
          eventKey:
              '$notificationSeed:${targetUser.userId}:thought_submission_received',
          metadata: const {
            'submissionType': 'task_submission',
          },
        ),
      );
    }

    if (notifications.isEmpty) return;
    await notificationProvider.createNotifications(notifications);
  }

  AppNotification _buildNotification({
    required DateTime now,
    required String recipientUserId,
    required String title,
    required String message,
    required String type,
    required Thought thought,
    required String actorUserId,
    required String actorUserName,
    required String eventKey,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      notificationId: '',
      recipientUserId: recipientUserId,
      title: title,
      message: message,
      type: type,
      deliveryStatus: AppNotification.deliveryPending,
      isRead: false,
      isDeleted: false,
      createdAt: now,
      updatedAt: now,
      actorUserId: actorUserId,
      actorUserName: actorUserName,
      boardId: thought.type == Thought.typeBoardRequest || thought.boardId.isEmpty
          ? null
          : thought.boardId,
      taskId: thought.taskId.isEmpty ? null : thought.taskId,
      thoughtId: thought.thoughtId,
      eventKey: eventKey,
      metadata: {
        ...?metadata,
        'thoughtType': thought.type,
      },
    );
  }
}

class _ChoiceOption {
  final String value;
  final String label;

  const _ChoiceOption(this.value, this.label);
}
