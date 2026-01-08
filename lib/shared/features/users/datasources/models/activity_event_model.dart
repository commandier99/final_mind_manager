import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityEvent {
  final String ActEvId;
  final String ActEvUserId;
  final String ActEvUserName;
  final String? ActEvUserProfilePicture;
  final String? ActEvType; // e.g., 'task_assigned', 'task_submitted', 'task_approved'
  final String? ActEvBoardId; // Board this activity is related to
  final String? ActEvTaskId; // Task this activity is related to
  final String? ActEvDescription;
  final DateTime ActEvTimestamp;
  final Map<String, dynamic>? ActEvMetadata; // Additional data
  ActivityEvent({
    required this.ActEvId,
    required this.ActEvUserId,
    required this.ActEvUserName,
    this.ActEvUserProfilePicture,
    this.ActEvType,
    this.ActEvBoardId,
    this.ActEvTaskId,
    this.ActEvDescription,
    required this.ActEvTimestamp,
    this.ActEvMetadata,
  });

  factory ActivityEvent.fromMap(Map<String, dynamic> data, String documentId) {
    final activityType = data['activityType'];
    print('[DEBUG] ActivityEvent.fromMap: Processing document $documentId');
    print('[DEBUG] ActivityEvent.fromMap: Raw data = $data');
    print('[DEBUG] ActivityEvent.fromMap: activityType value = $activityType (type: ${activityType.runtimeType})');
    
    return ActivityEvent(
      ActEvId: documentId,
      ActEvUserId: data['userId'] ?? '',
      ActEvUserName: data['userName'] ?? 'Unknown',
      ActEvUserProfilePicture: data['userProfilePicture'] as String?,
      ActEvType: (data['activityType'] as String?)?.isEmpty ?? true ? null : data['activityType'] as String?,
      ActEvBoardId: data['boardId'] as String?,
      ActEvTaskId: data['taskId'] as String?,
      ActEvDescription: data['description'] as String?,
      ActEvTimestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ActEvMetadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': ActEvUserId,
      'userName': ActEvUserName,
      if (ActEvUserProfilePicture != null) 'userProfilePicture': ActEvUserProfilePicture,
      'activityType': ActEvType,
      if (ActEvBoardId != null) 'boardId': ActEvBoardId,
      if (ActEvTaskId != null) 'taskId': ActEvTaskId,
      if (ActEvDescription != null) 'description': ActEvDescription,
      'timestamp': Timestamp.fromDate(ActEvTimestamp),
      if (ActEvMetadata != null) 'metadata': ActEvMetadata,
    };
  }
}
