import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/thought_model.dart';

class ThoughtService {
  // Temporary storage path during migration. The data model is Thoughts even
  // though the collection name is still `pokes`.
  final CollectionReference _thoughtCollection = FirebaseFirestore.instance
      .collection('pokes');

  Future<String> createThought(ThoughtModel thought) async {
    final ref = _thoughtCollection.doc();
    final payload = thought.toMap();
    payload['thoughtId'] = ref.id;
    payload['memoryId'] = ref.id;
    payload['pokeId'] = ref.id;
    payload['threadId'] = (thought.threadId ?? '').trim().isEmpty
        ? ref.id
        : thought.threadId!.trim();
    payload['updatedAt'] = Timestamp.fromDate(DateTime.now());
    await ref.set(payload);
    return ref.id;
  }

  Stream<List<ThoughtModel>> streamThoughtsCreatedByUser(String userId) {
    return _thoughtCollection
        .where('createdByUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ThoughtModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Stream<List<ThoughtModel>> streamThoughtsReceivedByUser(String userId) {
    return _thoughtCollection
        .where('recipientUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ThoughtModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Stream<List<ThoughtModel>> streamBoardThoughts(String boardId) {
    return _thoughtCollection
        .where('targetType', isEqualTo: ThoughtModel.targetBoard)
        .where('targetId', isEqualTo: boardId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ThoughtModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .where(
                (thought) =>
                    thought.status != ThoughtModel.statusResolved &&
                    thought.status != ThoughtModel.statusDeleted,
              )
              .toList(),
        );
  }

  Stream<List<ThoughtModel>> streamBoardTaskSuggestions(String boardId) {
    return _thoughtCollection
        .where('thoughtType', isEqualTo: ThoughtModel.typeSuggestion)
        .where(
          'metadata.suggestionTargetType',
          isEqualTo: ThoughtModel.suggestionTargetTask,
        )
        .where('metadata.boardId', isEqualTo: boardId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ThoughtModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .where(
                (thought) =>
                    thought.status != ThoughtModel.statusResolved &&
                    thought.status != ThoughtModel.statusDeleted,
              )
              .toList(),
        );
  }

  Stream<List<ThoughtModel>> streamTaskStepSuggestions(String taskId) {
    return _thoughtCollection
        .where('thoughtType', isEqualTo: ThoughtModel.typeSuggestion)
        .where(
          'metadata.suggestionTargetType',
          isEqualTo: ThoughtModel.suggestionTargetStep,
        )
        .where('metadata.taskId', isEqualTo: taskId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => ThoughtModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .where(
                (thought) =>
                    thought.status != ThoughtModel.statusResolved &&
                    thought.status != ThoughtModel.statusDeleted,
              )
              .toList(),
        );
  }

  Future<void> updateThoughtStatus({
    required String thoughtId,
    required String status,
  }) async {
    await _thoughtCollection.doc(thoughtId).update({
      'status': status,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> updateThoughtFields({
    required String thoughtId,
    required Map<String, dynamic> fields,
  }) async {
    await _thoughtCollection.doc(thoughtId).update({
      ...fields,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<bool> hasPendingBoardThought({
    required String boardId,
    required String recipientUserId,
    required String thoughtType,
  }) async {
    final snapshot = await _thoughtCollection
        .where('thoughtType', isEqualTo: thoughtType)
        .where('targetType', isEqualTo: ThoughtModel.targetBoard)
        .where('targetId', isEqualTo: boardId)
        .where('recipientUserId', isEqualTo: recipientUserId)
        .where('status', isEqualTo: ThoughtModel.statusPending)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }
}
