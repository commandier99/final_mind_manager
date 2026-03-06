import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_event_model.dart';

class ActivityEventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _events => _firestore.collection('activity_events');

  /// Log an activity event
  Future<void> logEvent({
    required String userId,
    required String userName,
    required String activityType,
    String? userProfilePicture,
    String? boardId,
    String? taskId,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    debugPrint('[DEBUG] ActivityEventService.logEvent: Logging event - type: $activityType, userId: $userId, taskId: $taskId');
    try {
      final eventRef = _events.doc();
      
      final event = ActivityEvent(
        ActEvId: eventRef.id,
        ActEvUserId: userId,
        ActEvUserName: userName,
        ActEvUserProfilePicture: userProfilePicture,
        ActEvType: activityType,
        ActEvBoardId: boardId,
        ActEvTaskId: taskId,
        ActEvDescription: description,
        ActEvTimestamp: DateTime.now(),
        ActEvMetadata: metadata,
      );
      
      await eventRef.set(event.toMap());
      debugPrint('[DEBUG] ActivityEventService.logEvent: Event logged successfully with ID: ${event.ActEvId}');
    } catch (e) {
      debugPrint('[ERROR] ActivityEventService.logEvent: Failed to log event - $e');
      rethrow;
    }
  }

  Stream<List<ActivityEvent>> streamUserEvents(String userId) {
    debugPrint('[DEBUG] ActivityEventService.streamUserEvents: Starting stream for userId: $userId');
    return _events
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) {
            debugPrint('[DEBUG] ActivityEventService.streamUserEvents: Received ${snap.docs.length} events for userId: $userId');
            return snap.docs.map((doc) {
              return ActivityEvent.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            }).toList();
          },
        )
        .handleError((error) {
          debugPrint('[ERROR] ActivityEventService.streamUserEvents: Stream error for userId $userId - $error');
        });
  }

  Future<List<ActivityEvent>> getUserEvents(String userId, {int limit = 50}) async {
    debugPrint('[DEBUG] ActivityEventService.getUserEvents: Fetching events for userId: $userId, limit: $limit');
    try {
      final snapshot = await _events
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      debugPrint('[DEBUG] ActivityEventService.getUserEvents: Retrieved ${snapshot.docs.length} events for userId: $userId');
      return snapshot.docs
          .map((doc) => ActivityEvent.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      debugPrint('[ERROR] ActivityEventService.getUserEvents: Failed to fetch events - $e');
      return [];
    }
  }

  /// Stream all activities for a specific board (all members' activities)
  Stream<List<ActivityEvent>> streamBoardEvents(String boardId) {
    debugPrint('[DEBUG] ActivityEventService.streamBoardEvents: Starting stream for boardId: $boardId');
    return _events
        .where('boardId', isEqualTo: boardId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snap) {
            debugPrint('[DEBUG] ActivityEventService.streamBoardEvents: Received ${snap.docs.length} events for boardId: $boardId');
            return snap.docs.map((doc) {
              return ActivityEvent.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            }).toList();
          },
        )
        .handleError((error) {
          debugPrint('[ERROR] ActivityEventService.streamBoardEvents: Stream error for boardId $boardId - $error');
        });
  }

  /// Fetch all activities for a specific board (all members' activities)
  Future<List<ActivityEvent>> getBoardEvents(String boardId, {int limit = 100}) async {
    debugPrint('[DEBUG] ActivityEventService.getBoardEvents: Fetching events for boardId: $boardId, limit: $limit');
    try {
      final snapshot = await _events
          .where('boardId', isEqualTo: boardId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      debugPrint('[DEBUG] ActivityEventService.getBoardEvents: Retrieved ${snapshot.docs.length} events for boardId: $boardId');
      return snapshot.docs
          .map((doc) => ActivityEvent.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      debugPrint('[ERROR] ActivityEventService.getBoardEvents: Failed to fetch events - $e');
      return [];
    }
  }
}
