import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/features/users/datasources/models/activity_event_model.dart';

class BoardMemberActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all activities for a specific board filtered by member
  Future<List<ActivityEvent>> getBoardMemberActivities({
    required String boardId,
    required String memberId,
    int limit = 50,
  }) async {
    try {
      print('[DEBUG] BoardMemberActivityService: Getting activities for boardId=$boardId, memberId=$memberId');
      
      final query = _firestore
          .collection('activity_events')
          .where('boardId', isEqualTo: boardId)
          .where('userId', isEqualTo: memberId)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      final snapshot = await query.get();
      
      final activities = snapshot.docs
          .map((doc) => ActivityEvent.fromMap(doc.data(), doc.id))
          .toList();

      print('[DEBUG] BoardMemberActivityService: Found ${activities.length} activities');
      return activities;
    } catch (e) {
      print('[ERROR] BoardMemberActivityService: Error getting member activities: $e');
      rethrow;
    }
  }

  /// Get all activities for a board (all members)
  Future<List<ActivityEvent>> getBoardActivities({
    required String boardId,
    int limit = 100,
  }) async {
    try {
      print('[DEBUG] BoardMemberActivityService: Getting all activities for boardId=$boardId');
      
      final query = _firestore
          .collection('activity_events')
          .where('boardId', isEqualTo: boardId)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      final snapshot = await query.get();
      
      final activities = snapshot.docs
          .map((doc) => ActivityEvent.fromMap(doc.data(), doc.id))
          .toList();

      print('[DEBUG] BoardMemberActivityService: Found ${activities.length} activities');
      return activities;
    } catch (e) {
      print('[ERROR] BoardMemberActivityService: Error getting board activities: $e');
      rethrow;
    }
  }

  /// Stream activities for a board member
  Stream<List<ActivityEvent>> streamBoardMemberActivities({
    required String boardId,
    required String memberId,
    int limit = 50,
  }) {
    print('[DEBUG] BoardMemberActivityService: Streaming activities for boardId=$boardId, memberId=$memberId');
    
    return _firestore
        .collection('activity_events')
        .where('boardId', isEqualTo: boardId)
        .where('userId', isEqualTo: memberId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityEvent.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Stream all activities for a board
  Stream<List<ActivityEvent>> streamBoardActivities({
    required String boardId,
    int limit = 100,
  }) {
    print('[DEBUG] BoardMemberActivityService: Streaming all activities for boardId=$boardId');
    
    return _firestore
        .collection('activity_events')
        .where('boardId', isEqualTo: boardId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ActivityEvent.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Get activities filtered by type (e.g., 'task_assigned', 'task_submitted', etc.)
  Future<List<ActivityEvent>> getBoardActivitiesByType({
    required String boardId,
    required String activityType,
    int limit = 50,
  }) async {
    try {
      print('[DEBUG] BoardMemberActivityService: Getting $activityType activities for boardId=$boardId');
      
      final query = _firestore
          .collection('activity_events')
          .where('boardId', isEqualTo: boardId)
          .where('activityType', isEqualTo: activityType)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      final snapshot = await query.get();
      
      final activities = snapshot.docs
          .map((doc) => ActivityEvent.fromMap(doc.data(), doc.id))
          .toList();

      print('[DEBUG] BoardMemberActivityService: Found ${activities.length} $activityType activities');
      return activities;
    } catch (e) {
      print('[ERROR] BoardMemberActivityService: Error getting activities by type: $e');
      rethrow;
    }
  }
}
