import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/thought_model.dart';

class ThoughtService {
  ThoughtService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _thoughts =>
      _firestore.collection('thoughts');

  Future<String> createThought(Thought thought) async {
    try {
      debugPrint(
        '[ThoughtService] Creating thought type=${thought.type} scope=${thought.scopeType}',
      );
      final docRef = thought.thoughtId.trim().isEmpty
          ? _thoughts.doc()
          : _thoughts.doc(thought.thoughtId);
      final normalized = thought.copyWith(
        thoughtId: docRef.id,
        updatedAt: DateTime.now(),
      );
      await _assertNoDuplicatePendingThought(normalized);
      await docRef.set(normalized.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('[ThoughtService] Failed to create thought: $e');
      throw Exception('Error creating thought: $e');
    }
  }

  Future<void> updateThought(Thought thought) async {
    try {
      await _thoughts.doc(thought.thoughtId).update(
        thought.copyWith(updatedAt: DateTime.now()).toMap(),
      );
    } catch (e) {
      debugPrint('[ThoughtService] Failed to update thought: $e');
      throw Exception('Error updating thought: $e');
    }
  }

  Future<void> updateThoughtStatus({
    required String thoughtId,
    required String status,
    required String actionedBy,
    required String actionedByName,
  }) async {
    try {
      await _thoughts.doc(thoughtId).update({
        'status': Thought.normalizeStatus(status),
        'updatedAt': Timestamp.now(),
        'actionedAt': Timestamp.now(),
        'actionedBy': actionedBy,
        'actionedByName': actionedByName,
      });
    } catch (e) {
      debugPrint('[ThoughtService] Failed to update thought status: $e');
      throw Exception('Error updating thought status: $e');
    }
  }

  Future<void> softDeleteThought(String thoughtId) async {
    try {
      await _thoughts.doc(thoughtId).update({
        'isDeleted': true,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('[ThoughtService] Failed to delete thought: $e');
      throw Exception('Error deleting thought: $e');
    }
  }

  Future<Thought?> getThoughtById(String thoughtId) async {
    try {
      final doc = await _thoughts.doc(thoughtId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Thought.fromMap(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('[ThoughtService] Failed to fetch thought: $e');
      throw Exception('Error fetching thought: $e');
    }
  }

  Stream<List<Thought>> streamThoughtsByBoard(String boardId) {
    return _thoughts
        .where('boardId', isEqualTo: boardId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapSnapshotToThoughts);
  }

  Stream<List<Thought>> streamThoughtsByTask(String taskId) {
    return _thoughts
        .where('taskId', isEqualTo: taskId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapSnapshotToThoughts);
  }

  Stream<List<Thought>> streamThoughtsForUser(String userId) {
    return _thoughts
        .where(
          Filter.or(
            Filter('authorId', isEqualTo: userId),
            Filter('targetUserId', isEqualTo: userId),
          ),
        )
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(_mapSnapshotToThoughts);
  }

  Future<Set<String>> getPendingBoardInviteTargetUserIds(String boardId) async {
    final snapshot = await _thoughts
        .where('type', isEqualTo: Thought.typeBoardRequest)
        .where('boardId', isEqualTo: boardId)
        .where('status', isEqualTo: Thought.statusPending)
        .where('isDeleted', isEqualTo: false)
        .get();

    final ids = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final metadata = Map<String, dynamic>.from(
        data['metadata'] as Map? ?? const <String, dynamic>{},
      );
      final direction = (metadata['requestDirection']?.toString() ?? '')
          .trim()
          .toLowerCase();
      if (direction != 'invite_member') continue;
      final targetUserId = (data['targetUserId'] as String? ?? '').trim();
      if (targetUserId.isNotEmpty) {
        ids.add(targetUserId);
      }
    }
    return ids;
  }

  Future<int> countSubmissionThoughtsForTask(String taskId) async {
    final snapshot = await _thoughts
        .where('type', isEqualTo: Thought.typeSubmissionFeedback)
        .where('taskId', isEqualTo: taskId)
        .where('isDeleted', isEqualTo: false)
        .get();
    return snapshot.docs.length;
  }

  Future<void> _assertNoDuplicatePendingThought(Thought thought) async {
    await _assertNoDuplicateReminderThought(thought);

    if (thought.isDeleted || thought.status != Thought.statusPending) return;

    if (thought.type == Thought.typeBoardRequest) {
      final metadata = thought.metadata ?? const <String, dynamic>{};
      final direction = (metadata['requestDirection']?.toString() ?? '')
          .trim()
          .toLowerCase();
      if (direction == 'invite_member') {
        final boardId = thought.boardId.trim();
        final targetUserId = (thought.targetUserId ?? '').trim();
        if (boardId.isNotEmpty && targetUserId.isNotEmpty) {
          final existing = await _thoughts
              .where('type', isEqualTo: Thought.typeBoardRequest)
              .where('boardId', isEqualTo: boardId)
              .where('targetUserId', isEqualTo: targetUserId)
              .where('status', isEqualTo: Thought.statusPending)
              .where('isDeleted', isEqualTo: false)
              .get();
          for (final doc in existing.docs) {
            final data = doc.data();
            final existingMetadata = Map<String, dynamic>.from(
              data['metadata'] as Map? ?? const <String, dynamic>{},
            );
            final existingDirection =
                (existingMetadata['requestDirection']?.toString() ?? '')
                    .trim()
                    .toLowerCase();
            if (existingDirection == 'invite_member') {
              throw StateError(
                'An invite for this board member is already pending.',
              );
            }
          }
        }
      }
    }

    if (thought.type == Thought.typeTaskAssignment) {
      final metadata = thought.metadata ?? const <String, dynamic>{};
      final assignmentDirection =
          (metadata['assignmentDirection']?.toString() ?? '')
              .trim()
              .toLowerCase();
      final assigneeId = (metadata['assignmentAssigneeId']?.toString() ?? '')
          .trim();
      final taskId = thought.taskId.trim();
      if (taskId.isEmpty || assigneeId.isEmpty) return;

      final existing = await _thoughts
          .where('type', isEqualTo: Thought.typeTaskAssignment)
          .where('taskId', isEqualTo: taskId)
          .where('status', isEqualTo: Thought.statusPending)
          .where('isDeleted', isEqualTo: false)
          .get();
      for (final doc in existing.docs) {
        final data = doc.data();
        final existingMetadata = Map<String, dynamic>.from(
          data['metadata'] as Map? ?? const <String, dynamic>{},
        );
        final existingDirection =
            (existingMetadata['assignmentDirection']?.toString() ?? '')
                .trim()
                .toLowerCase();
        final existingAssigneeId =
            (existingMetadata['assignmentAssigneeId']?.toString() ?? '')
                .trim();
        if (existingDirection == assignmentDirection &&
            existingAssigneeId == assigneeId) {
          throw StateError(
            'A pending task assignment or application already exists for this user and task.',
          );
        }
      }
    }

    if (thought.type == Thought.typeTaskRequest) {
      final metadata = thought.metadata ?? const <String, dynamic>{};
      final requestKind = (metadata['requestKind']?.toString() ?? '')
          .trim()
          .toLowerCase();
      final taskId = thought.taskId.trim();
      final authorId = thought.authorId.trim();
      if (taskId.isEmpty || authorId.isEmpty || requestKind.isEmpty) return;

      final existing = await _thoughts
          .where('type', isEqualTo: Thought.typeTaskRequest)
          .where('taskId', isEqualTo: taskId)
          .where('authorId', isEqualTo: authorId)
          .where('status', isEqualTo: Thought.statusPending)
          .where('isDeleted', isEqualTo: false)
          .get();

      for (final doc in existing.docs) {
        final data = doc.data();
        final existingMetadata = Map<String, dynamic>.from(
          data['metadata'] as Map? ?? const <String, dynamic>{},
        );
        final existingRequestKind =
            (existingMetadata['requestKind']?.toString() ?? '')
                .trim()
                .toLowerCase();
        if (existingRequestKind == requestKind) {
          throw StateError(
            'A pending request of this type already exists for this task.',
          );
        }
      }
    }

    if (thought.type == Thought.typeSubmissionFeedback) {
      final taskId = thought.taskId.trim();
      final authorId = thought.authorId.trim();
      if (taskId.isEmpty || authorId.isEmpty) return;

      final existing = await _thoughts
          .where('type', isEqualTo: Thought.typeSubmissionFeedback)
          .where('taskId', isEqualTo: taskId)
          .where('authorId', isEqualTo: authorId)
          .where('isDeleted', isEqualTo: false)
          .get();

      for (final doc in existing.docs) {
        final data = doc.data();
        final existingStatus =
            Thought.normalizeStatus(data['status'] as String?);
        final existingMetadata = Map<String, dynamic>.from(
          data['metadata'] as Map? ?? const <String, dynamic>{},
        );
        final submissionState =
            (existingMetadata['submissionState']?.toString() ?? '')
                .trim()
                .toLowerCase();
        if (existingStatus == Thought.statusOpen &&
            submissionState == 'submitted') {
          throw StateError(
            'A submission is already pending review for this task.',
          );
        }
      }
    }
  }

  Future<void> _assertNoDuplicateReminderThought(Thought thought) async {
    if (thought.type != Thought.typeReminder || thought.isDeleted) return;

    final metadata = thought.metadata ?? const <String, dynamic>{};
    final isSystemGenerated = metadata['systemGenerated'] == true;
    final reminderKind = (metadata['reminderKind']?.toString() ?? '')
        .trim()
        .toLowerCase();
    final reminderWindow = (metadata['reminderWindow']?.toString() ?? '')
        .trim()
        .toLowerCase();
    final eventKey = (metadata['eventKey']?.toString() ?? '').trim();

    if (!isSystemGenerated || reminderKind != 'deadline') return;

    if (eventKey.isNotEmpty) {
      final existingByEventKey = await _thoughts
          .where('type', isEqualTo: Thought.typeReminder)
          .where('isDeleted', isEqualTo: false)
          .where('authorId', isEqualTo: thought.authorId)
          .where('taskId', isEqualTo: thought.taskId)
          .get();

      for (final doc in existingByEventKey.docs) {
        final data = doc.data();
        final existingMetadata = Map<String, dynamic>.from(
          data['metadata'] as Map? ?? const <String, dynamic>{},
        );
        final existingEventKey =
            (existingMetadata['eventKey']?.toString() ?? '').trim();
        if (existingEventKey == eventKey) {
          throw StateError(
            'A matching deadline reminder thought already exists.',
          );
        }
      }
      return;
    }

    if (thought.taskId.trim().isEmpty || reminderWindow.isEmpty) return;

    final existing = await _thoughts
        .where('type', isEqualTo: Thought.typeReminder)
        .where('taskId', isEqualTo: thought.taskId.trim())
        .where('authorId', isEqualTo: thought.authorId)
        .where('isDeleted', isEqualTo: false)
        .get();

    for (final doc in existing.docs) {
      final data = doc.data();
      final existingMetadata = Map<String, dynamic>.from(
        data['metadata'] as Map? ?? const <String, dynamic>{},
      );
      final existingKind =
          (existingMetadata['reminderKind']?.toString() ?? '')
              .trim()
              .toLowerCase();
      final existingWindow =
          (existingMetadata['reminderWindow']?.toString() ?? '')
              .trim()
              .toLowerCase();
      final existingSystemGenerated = existingMetadata['systemGenerated'] == true;
      if (existingSystemGenerated &&
          existingKind == 'deadline' &&
          existingWindow == reminderWindow) {
        throw StateError(
          'A matching deadline reminder thought already exists.',
        );
      }
    }
  }

  List<Thought> _mapSnapshotToThoughts(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) {
          try {
            return Thought.fromMap(doc.data(), doc.id);
          } catch (e) {
            debugPrint('[ThoughtService] Failed to parse thought ${doc.id}: $e');
            return null;
          }
        })
        .whereType<Thought>()
        .toList();
  }
}
