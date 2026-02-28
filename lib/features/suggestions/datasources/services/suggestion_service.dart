import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/suggestion_model.dart';

class SuggestionService {
  final FirebaseFirestore _firestore;

  SuggestionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _suggestions =>
      _firestore.collection('suggestions');

  bool _isPendingStatus(String status) {
    return status.trim().toLowerCase() == 'pending';
  }

  Stream<List<Suggestion>> streamBoardSuggestions(
    String boardId, {
    bool includeResolved = true,
  }) {
    Query<Map<String, dynamic>> query = _suggestions
        .where('suggestionBoardId', isEqualTo: boardId)
        .where('suggestionIsDeleted', isEqualTo: false);

    return query.snapshots().map((snapshot) {
      var suggestions = snapshot.docs
          .map((doc) => Suggestion.fromMap(doc.data(), doc.id))
          .toList();

      if (!includeResolved) {
        suggestions = suggestions
            .where((s) => _isPendingStatus(s.suggestionStatus))
            .toList();
      }

      suggestions.sort(
        (a, b) => b.suggestionCreatedAt.compareTo(a.suggestionCreatedAt),
      );

      return suggestions;
    });
  }

  Stream<List<Suggestion>> streamUserSuggestions(
    String userId, {
    String? boardId,
  }) {
    Query<Map<String, dynamic>> query = _suggestions
        .where('suggestionAuthorId', isEqualTo: userId)
        .where('suggestionIsDeleted', isEqualTo: false);

    if (boardId != null && boardId.isNotEmpty) {
      query = query.where('suggestionBoardId', isEqualTo: boardId);
    }

    return query.snapshots().map((snapshot) {
      final suggestions = snapshot.docs
          .map((doc) => Suggestion.fromMap(doc.data(), doc.id))
          .toList();

      suggestions.sort(
        (a, b) => b.suggestionCreatedAt.compareTo(a.suggestionCreatedAt),
      );

      return suggestions;
    });
  }

  Future<void> addSuggestion(Suggestion suggestion) async {
    await _suggestions.doc(suggestion.suggestionId).set(suggestion.toMap());
  }

  Future<void> updateSuggestion(Suggestion suggestion) async {
    await _suggestions
        .doc(suggestion.suggestionId)
        .update(
          suggestion.copyWith(suggestionUpdatedAt: DateTime.now()).toMap(),
        );
  }

  Future<void> softDeleteSuggestion(String suggestionId) async {
    await _suggestions.doc(suggestionId).update({
      'suggestionIsDeleted': true,
      'suggestionDeletedAt': Timestamp.now(),
    });
  }

  Future<void> reviewSuggestion({
    required String suggestionId,
    required String status,
    required String reviewerId,
    String? reviewNote,
    String? convertedTaskId,
  }) async {
    if (status != 'accepted' && status != 'rejected' && status != 'converted') {
      throw ArgumentError('Invalid suggestion review status: $status');
    }

    await _suggestions.doc(suggestionId).update({
      'suggestionStatus': status,
      'suggestionReviewerId': reviewerId,
      'suggestionReviewNote': reviewNote,
      'suggestionReviewedAt': Timestamp.now(),
      if (convertedTaskId != null) 'suggestionConvertedTaskId': convertedTaskId,
      'suggestionUpdatedAt': Timestamp.now(),
    });
  }
}
