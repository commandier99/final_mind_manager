import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../../features/notifications/datasources/helpers/notification_helper.dart';
import '../models/memory_model.dart';
import '../services/memory_service.dart';

class MemoryProvider extends ChangeNotifier {
  final MemoryService _memoryService = MemoryService();

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  List<MemoryModel> _createdMemories = const [];
  List<MemoryModel> get createdMemories => _createdMemories;
  List<MemoryModel> _receivedMemories = const [];
  List<MemoryModel> get receivedMemories => _receivedMemories;

  StreamSubscription<List<MemoryModel>>? _createdSub;
  StreamSubscription<List<MemoryModel>>? _receivedSub;

  List<MemoryModel> get allMailboxMemories {
    final byId = <String, MemoryModel>{};
    for (final memory in [..._createdMemories, ..._receivedMemories]) {
      byId[memory.memoryId] = memory;
    }
    final list = byId.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<MemoryThreadSummary> get threadSummaries {
    final grouped = <String, List<MemoryModel>>{};
    for (final memory in allMailboxMemories) {
      final threadId = memory.effectiveThreadId;
      grouped.putIfAbsent(threadId, () => <MemoryModel>[]).add(memory);
    }

    final summaries = grouped.entries.map((entry) {
      final messages = entry.value
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final latest = messages.last;
      return MemoryThreadSummary(
        threadId: entry.key,
        latestMessage: latest,
        messages: messages,
        updatedAt: latest.updatedAt,
      );
    }).toList();

    summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return summaries;
  }

  Future<void> createMemoryEntry({
    required MemoryModel memory,
    String? notificationUserId,
    String? notificationTitle,
    String? relatedId,
    Map<String, dynamic>? notificationMetadata,
  }) async {
    _isSubmitting = true;
    notifyListeners();
    try {
      final createdMemoryId = await _memoryService.createMemoryEntry(memory);

      final shouldNotifyNow =
          memory.timing == MemoryModel.timingNow &&
          notificationUserId != null &&
          notificationUserId.isNotEmpty &&
          notificationUserId != 'None';

      if (shouldNotifyNow) {
        final senderName = memory.createdByUserName.trim().isEmpty
            ? 'Someone'
            : memory.createdByUserName.trim();
        final isUserMemory = memory.targetType == MemoryModel.targetUser;
        final isSelfReminder = notificationUserId == memory.createdByUserId;
        final subjectText = (memory.subject ?? '').trim();
        final targetTypeLabel = switch (memory.targetType) {
          MemoryModel.targetTask => 'task',
          MemoryModel.targetBoard => 'board',
          MemoryModel.targetUser => 'user',
          _ => 'item',
        };
        final targetLabel = memory.targetLabel.trim();
        final hasTarget = targetLabel.isNotEmpty;
        final isSelfUserTarget =
            isSelfReminder &&
            memory.targetType == MemoryModel.targetUser &&
            targetLabel.isNotEmpty &&
            targetLabel.toLowerCase() == senderName.toLowerCase();

        final reminderMessage = isSelfReminder
            ? (isUserMemory && subjectText.isNotEmpty
                ? 'You sent yourself a reminder about $subjectText.'
                : ((isSelfUserTarget || !hasTarget)
                    ? 'Reminder to yourself: ${memory.message}'
                    : 'Reminder for $targetTypeLabel $targetLabel: ${memory.message}'))
            : (memory.targetType == MemoryModel.targetUser
                ? '$senderName sent you a reminder: ${memory.message}'
                : (hasTarget
                    ? '$senderName sent you a reminder for $targetTypeLabel $targetLabel: ${memory.message}'
                    : '$senderName sent you a reminder: ${memory.message}'));

        final effectiveTitle =
            (notificationTitle != null && notificationTitle.trim().isNotEmpty)
                ? notificationTitle.trim()
                : (memory.subject != null && memory.subject!.trim().isNotEmpty)
                    ? memory.subject!.trim()
                    : 'Reminder';

        final reminderParts = _parseStructuredReminder(memory.message);
        final baseMetadata = <String, dynamic>{
          // Keep old keys for compatibility with existing filters/UI logic.
          'kind': isUserMemory ? 'poke' : 'reminder',
          'source': 'poke',
          'memoryId': createdMemoryId,
          'pokeId': createdMemoryId,
          'targetType': memory.targetType,
          'targetLabel': memory.targetLabel,
          'createdByUserId': memory.createdByUserId,
          'createdByUserName': memory.createdByUserName,
          'memoryTiming': memory.timing,
          'pokeTiming': memory.timing,
          if (memory.scheduledAt != null)
            'scheduledAt': memory.scheduledAt!.toIso8601String(),
        };

        await NotificationHelper.createNotificationPair(
          userId: notificationUserId,
          title: effectiveTitle,
          message: reminderMessage,
          category: NotificationHelper.categoryReminder,
          relatedId: relatedId,
          metadata: {
            ...baseMetadata,
            if (isUserMemory) 'memoryMessage': memory.message,
            if (isUserMemory) 'pokeMessage': memory.message,
            if (isUserMemory &&
                memory.subject != null &&
                memory.subject!.trim().isNotEmpty)
              'subject': memory.subject!.trim(),
            if (isUserMemory &&
                memory.threadId != null &&
                memory.threadId!.trim().isNotEmpty)
              'threadId': memory.threadId!.trim(),
            if (!isUserMemory && reminderParts.actionNeeded.isNotEmpty)
              'actionNeeded': reminderParts.actionNeeded,
            if (!isUserMemory && reminderParts.details.isNotEmpty)
              'details': reminderParts.details,
            if (!isUserMemory) 'reminderMessage': memory.message,
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
    _createdSub = _memoryService.streamCreatedByUser(userId).listen(
      (items) {
        _createdMemories = items;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('[MemoryProvider] streamCreatedByUser error: $error');
        _createdMemories = const [];
        notifyListeners();
      },
    );
  }

  void streamReceivedByUser(String userId) {
    _receivedSub?.cancel();
    _receivedSub = _memoryService.streamReceivedByUser(userId).listen(
      (items) {
        _receivedMemories = items;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('[MemoryProvider] streamReceivedByUser error: $error');
        _receivedMemories = const [];
        notifyListeners();
      },
    );
  }

  void streamMailbox(String userId) {
    streamCreatedByUser(userId);
    streamReceivedByUser(userId);
  }

  List<MemoryModel> getThreadMessages(String threadId) {
    final messages = allMailboxMemories
        .where((memory) => memory.effectiveThreadId == threadId)
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

class MemoryThreadSummary {
  final String threadId;
  final MemoryModel latestMessage;
  final List<MemoryModel> messages;
  final DateTime updatedAt;

  const MemoryThreadSummary({
    required this.threadId,
    required this.latestMessage,
    required this.messages,
    required this.updatedAt,
  });
}
