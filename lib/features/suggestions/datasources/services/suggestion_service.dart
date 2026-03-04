import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/suggestion_model.dart';
import '../../../../shared/features/users/datasources/services/activity_event_services.dart';
import '../../../notifications/datasources/helpers/notification_helper.dart';

class SuggestionService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final ActivityEventService _activityEventService;

  SuggestionService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance,
      _activityEventService = ActivityEventService();

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
    await _activityEventService.logEvent(
      userId: suggestion.suggestionAuthorId,
      userName: suggestion.suggestionAuthorName,
      userProfilePicture: suggestion.suggestionAuthorProfilePicture,
      activityType: 'suggestion_created',
      boardId: suggestion.suggestionBoardId,
      description: 'created a suggestion',
      metadata: {
        'suggestionId': suggestion.suggestionId,
        'suggestionTitle': suggestion.suggestionTitle,
      },
    );

    try {
      final boardDoc = await _firestore
          .collection('boards')
          .doc(suggestion.suggestionBoardId)
          .get();
      final boardData = boardDoc.data();
      final managerId = (boardData?['boardManagerId'] as String? ?? '').trim();
      final boardTitle =
          (boardData?['boardTitle'] as String? ?? 'Untitled Board').trim();

      if (managerId.isNotEmpty && managerId != suggestion.suggestionAuthorId) {
        await NotificationHelper.createInAppOnly(
          userId: managerId,
          title: 'New Suggestion',
          message:
              '${suggestion.suggestionAuthorName} submitted a suggestion on $boardTitle: ${suggestion.suggestionTitle}',
          category: NotificationHelper.categoryReminder,
          relatedId: suggestion.suggestionId,
          metadata: {
            'type': 'suggestion_created',
            'suggestionId': suggestion.suggestionId,
            'suggestionTitle': suggestion.suggestionTitle,
            'suggestionDescription': suggestion.suggestionDescription,
            'boardId': suggestion.suggestionBoardId,
            'boardTitle': boardTitle,
            'authorId': suggestion.suggestionAuthorId,
            'authorName': suggestion.suggestionAuthorName,
          },
        );
      }
    } catch (e) {
      // Notification failure should not block suggestion creation.
      debugPrint('[SuggestionService] Failed to notify board manager: $e');
    }
  }

  Future<void> updateSuggestion(Suggestion suggestion) async {
    await _suggestions
        .doc(suggestion.suggestionId)
        .update(
          suggestion.copyWith(suggestionUpdatedAt: DateTime.now()).toMap(),
        );
    await _activityEventService.logEvent(
      userId: suggestion.suggestionAuthorId,
      userName: suggestion.suggestionAuthorName,
      userProfilePicture: suggestion.suggestionAuthorProfilePicture,
      activityType: 'suggestion_updated',
      boardId: suggestion.suggestionBoardId,
      description: 'updated a suggestion',
      metadata: {
        'suggestionId': suggestion.suggestionId,
        'suggestionTitle': suggestion.suggestionTitle,
      },
    );
  }

  Future<void> softDeleteSuggestion(String suggestionId) async {
    final doc = await _suggestions.doc(suggestionId).get();
    final data = doc.data();
    await _suggestions.doc(suggestionId).update({
      'suggestionIsDeleted': true,
      'suggestionDeletedAt': Timestamp.now(),
    });
    if (data != null) {
      await _activityEventService.logEvent(
        userId:
            data['suggestionAuthorId'] as String? ??
            _auth.currentUser?.uid ??
            '',
        userName: data['suggestionAuthorName'] as String? ?? 'Unknown User',
        userProfilePicture: data['suggestionAuthorProfilePicture'] as String?,
        activityType: 'suggestion_deleted',
        boardId: data['suggestionBoardId'] as String?,
        description: 'deleted a suggestion',
        metadata: {
          'suggestionId': suggestionId,
          'suggestionTitle': data['suggestionTitle'] as String? ?? '',
        },
      );
    }
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

    final doc = await _suggestions.doc(suggestionId).get();
    final data = doc.data();

    await _suggestions.doc(suggestionId).update({
      'suggestionStatus': status,
      'suggestionReviewerId': reviewerId,
      'suggestionReviewNote': reviewNote,
      'suggestionReviewedAt': Timestamp.now(),
      if (convertedTaskId != null) 'suggestionConvertedTaskId': convertedTaskId,
      'suggestionUpdatedAt': Timestamp.now(),
    });

    if (data != null) {
      final reviewerName = _auth.currentUser?.displayName ?? 'Reviewer';
      await _activityEventService.logEvent(
        userId: reviewerId,
        userName: reviewerName,
        userProfilePicture: _auth.currentUser?.photoURL,
        activityType: 'suggestion_reviewed',
        boardId: data['suggestionBoardId'] as String?,
        description: 'reviewed a suggestion',
        metadata: {
          'suggestionId': suggestionId,
          'suggestionTitle': data['suggestionTitle'] as String? ?? '',
          'status': status,
          if (convertedTaskId != null) 'convertedTaskId': convertedTaskId,
        },
      );
    }
  }
}
