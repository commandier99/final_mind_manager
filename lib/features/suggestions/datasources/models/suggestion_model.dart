import 'package:cloud_firestore/cloud_firestore.dart';

class Suggestion {
  final String suggestionId;
  final String suggestionBoardId;
  final String suggestionAuthorId;
  final String suggestionAuthorName;
  final String? suggestionAuthorProfilePicture;

  final String suggestionTitle;
  final String suggestionDescription;

  final DateTime suggestionCreatedAt;
  final DateTime? suggestionUpdatedAt;

  // pending | accepted | rejected | converted
  final String suggestionStatus;
  final String? suggestionReviewerId;
  final String? suggestionReviewNote;
  final DateTime? suggestionReviewedAt;
  final String? suggestionConvertedTaskId;

  final bool suggestionIsDeleted;
  final DateTime? suggestionDeletedAt;

  const Suggestion({
    required this.suggestionId,
    required this.suggestionBoardId,
    required this.suggestionAuthorId,
    required this.suggestionAuthorName,
    this.suggestionAuthorProfilePicture,
    required this.suggestionTitle,
    required this.suggestionDescription,
    required this.suggestionCreatedAt,
    this.suggestionUpdatedAt,
    this.suggestionStatus = 'pending',
    this.suggestionReviewerId,
    this.suggestionReviewNote,
    this.suggestionReviewedAt,
    this.suggestionConvertedTaskId,
    this.suggestionIsDeleted = false,
    this.suggestionDeletedAt,
  });

  factory Suggestion.fromMap(Map<String, dynamic> data, String documentId) {
    return Suggestion(
      suggestionId: documentId,
      suggestionBoardId: data['suggestionBoardId'] as String? ?? '',
      suggestionAuthorId: data['suggestionAuthorId'] as String? ?? '',
      suggestionAuthorName:
          data['suggestionAuthorName'] as String? ?? 'Unknown',
      suggestionAuthorProfilePicture:
          data['suggestionAuthorProfilePicture'] as String?,
      suggestionTitle:
          data['suggestionTitle'] as String? ?? 'Untitled Suggestion',
      suggestionDescription: data['suggestionDescription'] as String? ?? '',
      suggestionCreatedAt:
          (data['suggestionCreatedAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      suggestionUpdatedAt: (data['suggestionUpdatedAt'] as Timestamp?)
          ?.toDate(),
      suggestionStatus: data['suggestionStatus'] as String? ?? 'pending',
      suggestionReviewerId: data['suggestionReviewerId'] as String?,
      suggestionReviewNote: data['suggestionReviewNote'] as String?,
      suggestionReviewedAt: (data['suggestionReviewedAt'] as Timestamp?)
          ?.toDate(),
      suggestionConvertedTaskId: data['suggestionConvertedTaskId'] as String?,
      suggestionIsDeleted: data['suggestionIsDeleted'] as bool? ?? false,
      suggestionDeletedAt: (data['suggestionDeletedAt'] as Timestamp?)
          ?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'suggestionBoardId': suggestionBoardId,
      'suggestionAuthorId': suggestionAuthorId,
      'suggestionAuthorName': suggestionAuthorName,
      if (suggestionAuthorProfilePicture != null)
        'suggestionAuthorProfilePicture': suggestionAuthorProfilePicture,
      'suggestionTitle': suggestionTitle,
      'suggestionDescription': suggestionDescription,
      'suggestionCreatedAt': Timestamp.fromDate(suggestionCreatedAt),
      if (suggestionUpdatedAt != null)
        'suggestionUpdatedAt': Timestamp.fromDate(suggestionUpdatedAt!),
      'suggestionStatus': suggestionStatus,
      if (suggestionReviewerId != null)
        'suggestionReviewerId': suggestionReviewerId,
      if (suggestionReviewNote != null)
        'suggestionReviewNote': suggestionReviewNote,
      if (suggestionReviewedAt != null)
        'suggestionReviewedAt': Timestamp.fromDate(suggestionReviewedAt!),
      if (suggestionConvertedTaskId != null)
        'suggestionConvertedTaskId': suggestionConvertedTaskId,
      'suggestionIsDeleted': suggestionIsDeleted,
      if (suggestionDeletedAt != null)
        'suggestionDeletedAt': Timestamp.fromDate(suggestionDeletedAt!),
    };
  }

  Suggestion copyWith({
    String? suggestionId,
    String? suggestionBoardId,
    String? suggestionAuthorId,
    String? suggestionAuthorName,
    String? suggestionAuthorProfilePicture,
    String? suggestionTitle,
    String? suggestionDescription,
    DateTime? suggestionCreatedAt,
    DateTime? suggestionUpdatedAt,
    String? suggestionStatus,
    String? suggestionReviewerId,
    String? suggestionReviewNote,
    DateTime? suggestionReviewedAt,
    String? suggestionConvertedTaskId,
    bool? suggestionIsDeleted,
    DateTime? suggestionDeletedAt,
  }) {
    return Suggestion(
      suggestionId: suggestionId ?? this.suggestionId,
      suggestionBoardId: suggestionBoardId ?? this.suggestionBoardId,
      suggestionAuthorId: suggestionAuthorId ?? this.suggestionAuthorId,
      suggestionAuthorName: suggestionAuthorName ?? this.suggestionAuthorName,
      suggestionAuthorProfilePicture:
          suggestionAuthorProfilePicture ?? this.suggestionAuthorProfilePicture,
      suggestionTitle: suggestionTitle ?? this.suggestionTitle,
      suggestionDescription:
          suggestionDescription ?? this.suggestionDescription,
      suggestionCreatedAt: suggestionCreatedAt ?? this.suggestionCreatedAt,
      suggestionUpdatedAt: suggestionUpdatedAt ?? this.suggestionUpdatedAt,
      suggestionStatus: suggestionStatus ?? this.suggestionStatus,
      suggestionReviewerId: suggestionReviewerId ?? this.suggestionReviewerId,
      suggestionReviewNote: suggestionReviewNote ?? this.suggestionReviewNote,
      suggestionReviewedAt: suggestionReviewedAt ?? this.suggestionReviewedAt,
      suggestionConvertedTaskId:
          suggestionConvertedTaskId ?? this.suggestionConvertedTaskId,
      suggestionIsDeleted: suggestionIsDeleted ?? this.suggestionIsDeleted,
      suggestionDeletedAt: suggestionDeletedAt ?? this.suggestionDeletedAt,
    );
  }
}
