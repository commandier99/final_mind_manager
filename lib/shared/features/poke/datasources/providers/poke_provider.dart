import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/poke_model.dart';
import '../services/poke_service.dart';
import '../../../../../features/notifications/datasources/helpers/notification_helper.dart';

class PokeProvider extends ChangeNotifier {
  final PokeService _pokeService = PokeService();

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  List<PokeModel> _createdPokes = const [];
  List<PokeModel> get createdPokes => _createdPokes;
  List<PokeModel> _receivedPokes = const [];
  List<PokeModel> get receivedPokes => _receivedPokes;

  StreamSubscription<List<PokeModel>>? _createdSub;
  StreamSubscription<List<PokeModel>>? _receivedSub;

  List<PokeModel> get allMailboxPokes {
    final byId = <String, PokeModel>{};
    for (final poke in [..._createdPokes, ..._receivedPokes]) {
      byId[poke.pokeId] = poke;
    }
    final list = byId.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<PokeThreadSummary> get threadSummaries {
    final grouped = <String, List<PokeModel>>{};
    for (final poke in allMailboxPokes) {
      final threadId = poke.effectiveThreadId;
      grouped.putIfAbsent(threadId, () => <PokeModel>[]).add(poke);
    }

    final summaries = grouped.entries.map((entry) {
      final messages = entry.value..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final latest = messages.last;
      return PokeThreadSummary(
        threadId: entry.key,
        latestMessage: latest,
        messages: messages,
        updatedAt: latest.updatedAt,
      );
    }).toList();

    summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return summaries;
  }

  Future<void> createPoke({
    required PokeModel poke,
    String? notificationUserId,
    String? notificationTitle,
    String? relatedId,
    Map<String, dynamic>? notificationMetadata,
  }) async {
    _isSubmitting = true;
    notifyListeners();
    try {
      final createdPokeId = await _pokeService.createPoke(poke);

      final shouldNotifyNow =
          poke.timing == PokeModel.timingNow &&
          notificationUserId != null &&
          notificationUserId.isNotEmpty &&
          notificationUserId != 'None';

      if (shouldNotifyNow) {
        final senderName = poke.createdByUserName.trim().isEmpty
            ? 'Someone'
            : poke.createdByUserName.trim();
        final isUserPoke = poke.targetType == PokeModel.targetUser;
        final isSelfReminder = notificationUserId == poke.createdByUserId;
        final subjectText = (poke.subject ?? '').trim();
        final targetTypeLabel = switch (poke.targetType) {
          PokeModel.targetTask => 'task',
          PokeModel.targetBoard => 'board',
          PokeModel.targetUser => 'user',
          _ => 'item',
        };
        final targetLabel = poke.targetLabel.trim();
        final hasTarget = targetLabel.isNotEmpty;
        final isSelfUserTarget =
            isSelfReminder &&
            poke.targetType == PokeModel.targetUser &&
            targetLabel.isNotEmpty &&
            targetLabel.toLowerCase() == senderName.toLowerCase();
        final reminderMessage =
            isSelfReminder
            ? (isUserPoke && subjectText.isNotEmpty
                  ? 'You sent yourself a reminder about $subjectText.'
                  : ((isSelfUserTarget || !hasTarget)
                  ? 'Reminder to yourself: ${poke.message}'
                  : 'Reminder for $targetTypeLabel $targetLabel: ${poke.message}'))
            : (poke.targetType == PokeModel.targetUser
                  ? '$senderName sent you a reminder: ${poke.message}'
                  : (hasTarget
                        ? '$senderName sent you a reminder for $targetTypeLabel $targetLabel: ${poke.message}'
                        : '$senderName sent you a reminder: ${poke.message}'));
        final effectiveTitle =
            (notificationTitle != null && notificationTitle.trim().isNotEmpty)
            ? notificationTitle.trim()
            : (poke.subject != null && poke.subject!.trim().isNotEmpty)
            ? poke.subject!.trim()
            : 'Reminder';

        final reminderParts = _parseStructuredReminder(poke.message);
        final baseMetadata = <String, dynamic>{
          'kind': isUserPoke ? 'poke' : 'reminder',
          'source': 'poke',
          'pokeId': createdPokeId,
          'targetType': poke.targetType,
          'targetLabel': poke.targetLabel,
          'createdByUserId': poke.createdByUserId,
          'createdByUserName': poke.createdByUserName,
          'pokeTiming': poke.timing,
          if (poke.scheduledAt != null)
            'scheduledAt': poke.scheduledAt!.toIso8601String(),
        };

        await NotificationHelper.createNotificationPair(
          userId: notificationUserId,
          title: effectiveTitle,
          message: reminderMessage,
          category: NotificationHelper.categoryReminder,
          relatedId: relatedId,
          metadata: {
            ...baseMetadata,
            if (isUserPoke) 'pokeMessage': poke.message,
            if (isUserPoke && poke.subject != null && poke.subject!.trim().isNotEmpty)
              'subject': poke.subject!.trim(),
            if (isUserPoke &&
                poke.threadId != null &&
                poke.threadId!.trim().isNotEmpty)
              'threadId': poke.threadId!.trim(),
            if (!isUserPoke && reminderParts.actionNeeded.isNotEmpty)
              'actionNeeded': reminderParts.actionNeeded,
            if (!isUserPoke && reminderParts.details.isNotEmpty)
              'details': reminderParts.details,
            if (!isUserPoke) 'reminderMessage': poke.message,
            if (notificationMetadata != null) ...notificationMetadata,
          },
        );
      }
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void streamCreatedByUser(String userId) {
    _createdSub?.cancel();
    _createdSub = _pokeService.streamCreatedByUser(userId).listen((items) {
      _createdPokes = items;
      notifyListeners();
    });
  }

  void streamReceivedByUser(String userId) {
    _receivedSub?.cancel();
    _receivedSub = _pokeService.streamReceivedByUser(userId).listen((items) {
      _receivedPokes = items;
      notifyListeners();
    });
  }

  void streamMailbox(String userId) {
    streamCreatedByUser(userId);
    streamReceivedByUser(userId);
  }

  List<PokeModel> getThreadMessages(String threadId) {
    final messages = allMailboxPokes
        .where((poke) => poke.effectiveThreadId == threadId)
        .toList();
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }

  @override
  void dispose() {
    _createdSub?.cancel();
    _receivedSub?.cancel();
    super.dispose();
  }

  _ReminderParts _parseStructuredReminder(String message) {
    final lines = message.split('\n');
    String action = '';
    String details = '';

    for (final line in lines) {
      final normalized = line.trim();
      if (normalized.toLowerCase().startsWith('action needed:')) {
        action = normalized.substring('action needed:'.length).trim();
      } else if (normalized.toLowerCase().startsWith('details:')) {
        details = normalized.substring('details:'.length).trim();
      }
    }

    if (action.isEmpty && lines.isNotEmpty) {
      action = lines.first.trim();
    }
    if (details.isEmpty && lines.length > 1) {
      details = lines.skip(1).join('\n').trim();
    }
    return _ReminderParts(actionNeeded: action, details: details);
  }
}

class _ReminderParts {
  final String actionNeeded;
  final String details;

  const _ReminderParts({
    required this.actionNeeded,
    required this.details,
  });
}

class PokeThreadSummary {
  final String threadId;
  final PokeModel latestMessage;
  final List<PokeModel> messages;
  final DateTime updatedAt;

  const PokeThreadSummary({
    required this.threadId,
    required this.latestMessage,
    required this.messages,
    required this.updatedAt,
  });
}
