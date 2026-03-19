import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../../../features/boards/datasources/models/board_roles.dart';
import '../../../../../features/boards/datasources/services/board_services.dart';
import '../../../../../features/notifications/datasources/helpers/notification_helper.dart';
import '../../../../../shared/features/users/datasources/services/activity_event_services.dart';
import '../models/thought_model.dart';
import '../services/thought_service.dart';

class ThoughtProvider extends ChangeNotifier {
  final ThoughtService _thoughtService = ThoughtService();
  final BoardService _boardService = BoardService();
  final ActivityEventService _activityEventService = ActivityEventService();

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  List<ThoughtModel> _createdThoughts = const [];
  List<ThoughtModel> get createdThoughts => _createdThoughts;
  List<ThoughtModel> _receivedThoughts = const [];
  List<ThoughtModel> get receivedThoughts => _receivedThoughts;
  List<ThoughtModel> _boardThoughts = const [];
  List<ThoughtModel> get boardThoughts => _boardThoughts;
  List<ThoughtModel> _boardTaskSuggestions = const [];
  List<ThoughtModel> get boardTaskSuggestions => _boardTaskSuggestions;

  StreamSubscription<List<ThoughtModel>>? _createdSub;
  StreamSubscription<List<ThoughtModel>>? _receivedSub;
  StreamSubscription<List<ThoughtModel>>? _boardThoughtsSub;
  StreamSubscription<List<ThoughtModel>>? _boardTaskSuggestionsSub;
  String? _boardThoughtsBoardId;
  String? _boardTaskSuggestionsBoardId;

  List<ThoughtModel> get allThoughts {
    final byId = <String, ThoughtModel>{};
    for (final thought in [..._createdThoughts, ..._receivedThoughts]) {
      byId[thought.thoughtId] = thought;
    }
    final list = byId.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<ThoughtThreadSummary> get threadSummaries {
    final grouped = <String, List<ThoughtModel>>{};
    for (final thought in allThoughts) {
      final threadId = thought.effectiveThreadId;
      grouped.putIfAbsent(threadId, () => <ThoughtModel>[]).add(thought);
    }

    final summaries = grouped.entries.map((entry) {
      final messages = entry.value
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final latest = messages.last;
      return ThoughtThreadSummary(
        threadId: entry.key,
        latestThought: latest,
        thoughts: messages,
        updatedAt: latest.updatedAt,
      );
    }).toList();

    summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return summaries;
  }

  Future<void> createThought({
    required ThoughtModel thought,
    String? notificationUserId,
    String? notificationTitle,
    String? notificationCategory,
    String? relatedId,
    Map<String, dynamic>? notificationMetadata,
  }) async {
    _isSubmitting = true;
    notifyListeners();
    try {
      final createdThoughtId = await _thoughtService.createThought(thought);

      final shouldNotifyNow =
          thought.timing == ThoughtModel.timingNow &&
          notificationUserId != null &&
          notificationUserId.isNotEmpty &&
          notificationUserId != 'None';

      if (shouldNotifyNow) {
        final senderName = thought.senderUserName.trim().isEmpty
            ? 'Someone'
            : thought.senderUserName.trim();
        final isUserThought = thought.targetType == ThoughtModel.targetUser;
        final isSelfReminder = notificationUserId == thought.senderUserId;
        final titleText = (thought.title ?? '').trim();
        final targetTypeLabel = switch (thought.targetType) {
          ThoughtModel.targetTask => 'task',
          ThoughtModel.targetBoard => 'board',
          ThoughtModel.targetUser => 'user',
          _ => 'item',
        };
        final targetLabel = thought.targetLabel.trim();
        final hasTarget = targetLabel.isNotEmpty;
        final isSelfUserTarget =
            isSelfReminder &&
            thought.targetType == ThoughtModel.targetUser &&
            targetLabel.isNotEmpty &&
            targetLabel.toLowerCase() == senderName.toLowerCase();

        final reminderMessage = isSelfReminder
            ? (isUserThought && titleText.isNotEmpty
                ? 'You sent yourself a thought about $titleText.'
                : ((isSelfUserTarget || !hasTarget)
                    ? 'Thought to yourself: ${thought.message}'
                    : 'Thought for $targetTypeLabel $targetLabel: ${thought.message}'))
            : (thought.targetType == ThoughtModel.targetUser
                ? '$senderName sent you a thought: ${thought.message}'
                : (hasTarget
                    ? '$senderName sent you a thought for $targetTypeLabel $targetLabel: ${thought.message}'
                    : '$senderName sent you a thought: ${thought.message}'));

        final effectiveTitle =
            (notificationTitle != null && notificationTitle.trim().isNotEmpty)
                ? notificationTitle.trim()
                : titleText.isNotEmpty
                    ? titleText
                    : 'Thought';

        final baseMetadata = <String, dynamic>{
          'thoughtId': createdThoughtId,
          'memoryId': createdThoughtId,
          'pokeId': createdThoughtId,
          'targetType': thought.targetType,
          'targetLabel': thought.targetLabel,
          'createdByUserId': thought.senderUserId,
          'createdByUserName': thought.senderUserName,
          'thoughtTiming': thought.timing,
          'memoryTiming': thought.timing,
          'pokeTiming': thought.timing,
          if (thought.scheduledAt != null)
            'scheduledAt': thought.scheduledAt!.toIso8601String(),
        };

        await NotificationHelper.createNotificationPair(
          userId: notificationUserId,
          title: effectiveTitle,
          message: reminderMessage,
          category:
              notificationCategory ?? NotificationHelper.categoryReminder,
          relatedId: relatedId,
          metadata: {
            ...baseMetadata,
            if (isUserThought) 'thoughtMessage': thought.message,
            if (isUserThought) 'memoryMessage': thought.message,
            if (isUserThought) 'pokeMessage': thought.message,
            if (thought.title != null && thought.title!.trim().isNotEmpty)
              'title': thought.title!.trim(),
            if (thought.title != null && thought.title!.trim().isNotEmpty)
              'subject': thought.title!.trim(),
            if (thought.threadId != null && thought.threadId!.trim().isNotEmpty)
              'threadId': thought.threadId!.trim(),
            if (notificationMetadata != null) ...notificationMetadata,
          },
        );
      }
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void streamThoughtsCreatedByUser(String userId) {
    _createdSub?.cancel();
    _createdSub = _thoughtService.streamThoughtsCreatedByUser(userId).listen(
      (items) {
        _createdThoughts = items;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('[ThoughtProvider] streamThoughtsCreatedByUser error: $error');
        _createdThoughts = const [];
        notifyListeners();
      },
    );
  }

  void streamThoughtsReceivedByUser(String userId) {
    _receivedSub?.cancel();
    _receivedSub = _thoughtService.streamThoughtsReceivedByUser(userId).listen(
      (items) {
        _receivedThoughts = items;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('[ThoughtProvider] streamThoughtsReceivedByUser error: $error');
        _receivedThoughts = const [];
        notifyListeners();
      },
    );
  }

  void streamInbox(String userId) {
    streamThoughtsCreatedByUser(userId);
    streamThoughtsReceivedByUser(userId);
  }

  void streamBoardThoughts(String boardId) {
    if (_boardThoughtsBoardId == boardId && _boardThoughtsSub != null) {
      return;
    }

    _boardThoughtsSub?.cancel();
    _boardThoughtsBoardId = boardId;
    _boardThoughtsSub = _thoughtService.streamBoardThoughts(boardId).listen(
      (items) {
        _boardThoughts = items;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('[ThoughtProvider] streamBoardThoughts error: $error');
        _boardThoughts = const [];
        notifyListeners();
      },
    );
  }

  void streamBoardTaskSuggestions(String boardId) {
    if (_boardTaskSuggestionsBoardId == boardId &&
        _boardTaskSuggestionsSub != null) {
      return;
    }

    _boardTaskSuggestionsSub?.cancel();
    _boardTaskSuggestionsBoardId = boardId;
    _boardTaskSuggestionsSub = _thoughtService
        .streamBoardTaskSuggestions(boardId)
        .listen(
      (items) {
        _boardTaskSuggestions = items;
        notifyListeners();
      },
      onError: (error) {
        debugPrint(
          '[ThoughtProvider] streamBoardTaskSuggestions error: $error',
        );
        _boardTaskSuggestions = const [];
        notifyListeners();
      },
    );
  }

  Future<void> updateThoughtStatus({
    required String thoughtId,
    required String status,
  }) async {
    await _thoughtService.updateThoughtStatus(
      thoughtId: thoughtId,
      status: status,
    );
  }

  Future<void> updateSuggestionOutcome({
    required String thoughtId,
    required String status,
    String? convertedTaskId,
    String? convertedStepId,
  }) async {
    final fields = <String, dynamic>{
      'status': status,
      if (convertedTaskId != null && convertedTaskId.trim().isNotEmpty)
        'metadata.convertedTaskId': convertedTaskId.trim(),
      if (convertedStepId != null && convertedStepId.trim().isNotEmpty)
        'metadata.convertedStepId': convertedStepId.trim(),
    };
    await _thoughtService.updateThoughtFields(
      thoughtId: thoughtId,
      fields: fields,
    );
  }

  Future<bool> hasPendingBoardInvite({
    required String boardId,
    required String recipientUserId,
  }) {
    return _thoughtService.hasPendingBoardThought(
      boardId: boardId,
      recipientUserId: recipientUserId,
      thoughtType: ThoughtModel.typeBoardInvite,
    );
  }

  Future<void> createBoardInviteThought({
    required String boardId,
    required String boardTitle,
    required String recipientUserId,
    required String recipientUserName,
    required String boardManagerId,
    required String boardManagerName,
    String role = BoardRoles.member,
    String? message,
  }) async {
    final normalizedRole = BoardRoles.normalize(role);
    final now = DateTime.now();
    final thought = ThoughtModel(
      thoughtId: '',
      thoughtType: ThoughtModel.typeBoardInvite,
      senderUserId: boardManagerId,
      senderUserName: boardManagerName,
      targetType: ThoughtModel.targetBoard,
      targetId: boardId,
      targetLabel: boardTitle,
      title: 'Board Invitation',
      message: message ?? 'You have been invited to join this board',
      timing: ThoughtModel.timingNow,
      status: ThoughtModel.statusPending,
      recipientUserId: recipientUserId,
      metadata: {
        'type': ThoughtModel.typeBoardInvite,
        'boardId': boardId,
        'boardTitle': boardTitle,
        'boardManagerId': boardManagerId,
        'boardManagerName': boardManagerName,
        'targetUserId': recipientUserId,
        'targetUserName': recipientUserName,
        'requestedRole': normalizedRole,
      },
      createdAt: now,
      updatedAt: now,
    );

    await createThought(
      thought: thought,
      notificationUserId: recipientUserId,
      notificationTitle: 'Board Invitation',
      notificationCategory: NotificationHelper.categoryInvitation,
      relatedId: boardId,
      notificationMetadata: {
        'type': ThoughtModel.typeBoardInvite,
        'boardId': boardId,
        'boardTitle': boardTitle,
        'boardManagerId': boardManagerId,
        'boardManagerName': boardManagerName,
        'targetUserId': recipientUserId,
        'targetUserName': recipientUserName,
        'requestedRole': normalizedRole,
        'thoughtStatus': ThoughtModel.statusPending,
      },
    );

    await _activityEventService.logEvent(
      userId: boardManagerId,
      userName: boardManagerName,
      activityType: 'board_invitation_sent',
      boardId: boardId,
      description: 'sent a board invitation',
      metadata: {
        'targetUserId': recipientUserId,
        'targetUserName': recipientUserName,
        'requestedRole': normalizedRole,
      },
    );
  }

  Future<void> createTaskSuggestionThought({
    required String boardId,
    required String boardTitle,
    required String boardManagerId,
    required String boardManagerName,
    required String senderUserId,
    required String senderUserName,
    required String title,
    required String description,
  }) async {
    final now = DateTime.now();
    final thought = ThoughtModel(
      thoughtId: '',
      thoughtType: ThoughtModel.typeSuggestion,
      senderUserId: senderUserId,
      senderUserName: senderUserName,
      targetType: ThoughtModel.targetTask,
      targetId: '',
      targetLabel: boardTitle,
      title: title,
      message: description,
      timing: ThoughtModel.timingNow,
      status: ThoughtModel.statusPending,
      recipientUserId: boardManagerId,
      metadata: {
        'type': 'suggestion_created',
        'suggestionTargetType': ThoughtModel.suggestionTargetTask,
        'boardId': boardId,
        'boardTitle': boardTitle,
        'boardManagerId': boardManagerId,
        'boardManagerName': boardManagerName,
        'suggestionTitle': title,
        'suggestionDescription': description,
      },
      createdAt: now,
      updatedAt: now,
    );

    await createThought(
      thought: thought,
      notificationUserId: boardManagerId,
      notificationTitle: title,
      notificationCategory: NotificationHelper.categoryReminder,
      relatedId: boardId,
      notificationMetadata: {
        'type': 'suggestion_created',
        'thoughtType': ThoughtModel.typeSuggestion,
        'suggestionTargetType': ThoughtModel.suggestionTargetTask,
        'boardId': boardId,
        'boardTitle': boardTitle,
        'boardManagerId': boardManagerId,
        'boardManagerName': boardManagerName,
        'suggestionTitle': title,
        'suggestionDescription': description,
        'thoughtStatus': ThoughtModel.statusPending,
      },
    );

    await _activityEventService.logEvent(
      userId: senderUserId,
      userName: senderUserName,
      activityType: 'suggestion_created',
      boardId: boardId,
      description: 'created a task suggestion',
      metadata: {
        'suggestionTitle': title,
        'suggestionTargetType': ThoughtModel.suggestionTargetTask,
      },
    );
  }

  Future<void> respondToBoardInvite({
    required ThoughtModel thought,
    required bool approved,
    required String responderUserId,
    required String responderUserName,
    String? responseMessage,
  }) async {
    if (thought.recipientUserId != responderUserId) {
      throw Exception('Only the invited user can respond to this invite.');
    }

    final metadata = thought.metadata ?? const <String, dynamic>{};
    final boardId = (metadata['boardId']?.toString() ?? thought.targetId).trim();
    final boardTitle =
        (metadata['boardTitle']?.toString() ?? thought.targetLabel).trim();
    final requestedRole = BoardRoles.normalize(
      metadata['requestedRole']?.toString() ?? BoardRoles.member,
    );

    if (approved) {
      await _boardService.addMemberToBoard(
        boardId: boardId,
        userId: responderUserId,
        role: requestedRole,
      );
    }

    await updateThoughtStatus(
      thoughtId: thought.thoughtId,
      status: approved ? 'approved' : 'rejected',
    );

    await _activityEventService.logEvent(
      userId: responderUserId,
      userName: responderUserName,
      activityType: approved
          ? 'board_invitation_accepted'
          : 'board_invitation_declined',
      boardId: boardId,
      description: approved
          ? 'accepted a board invitation'
          : 'declined a board invitation',
      metadata: {
        'boardTitle': boardTitle,
        'requestedRole': requestedRole,
      },
    );

    final managerId = (metadata['boardManagerId']?.toString() ?? '').trim();
    if (managerId.isNotEmpty && managerId != responderUserId) {
      await NotificationHelper.createInAppOnly(
        userId: managerId,
        title: approved
            ? 'Board Invitation Accepted'
            : 'Board Invitation Declined',
        message:
            '$responderUserName ${approved ? 'accepted' : 'declined'} your invitation to "$boardTitle".',
        category: NotificationHelper.categoryInvitation,
        relatedId: boardId,
        metadata: {
          'type': ThoughtModel.typeBoardInvite,
          'boardId': boardId,
          'boardTitle': boardTitle,
          'decision': approved ? 'approved' : 'rejected',
          'respondedBy': responderUserId,
          'respondedByName': responderUserName,
          if (responseMessage != null && responseMessage.trim().isNotEmpty)
            'responseMessage': responseMessage.trim(),
        },
      );
    }
  }

  List<ThoughtModel> getThreadThoughts(String threadId) {
    final thoughts = allThoughts
        .where((thought) => thought.effectiveThreadId == threadId)
        .toList();
    thoughts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return thoughts;
  }

  @override
  void dispose() {
    _createdSub?.cancel();
    _receivedSub?.cancel();
    _boardThoughtsSub?.cancel();
    _boardTaskSuggestionsSub?.cancel();
    super.dispose();
  }
}

class ThoughtThreadSummary {
  final String threadId;
  final ThoughtModel latestThought;
  final List<ThoughtModel> thoughts;
  final DateTime updatedAt;

  const ThoughtThreadSummary({
    required this.threadId,
    required this.latestThought,
    required this.thoughts,
    required this.updatedAt,
  });
}
