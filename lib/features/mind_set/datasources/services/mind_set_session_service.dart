import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mind_set_session_model.dart';
import '../../../../shared/features/users/datasources/services/activity_event_services.dart';

class MindSetSessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ActivityEventService _activityEventService = ActivityEventService();
  CollectionReference get _sessions => _firestore.collection('mindset_sessions');

  Future<void> addSession(MindSetSession session) async {
    try {
      await _sessions.doc(session.sessionId).set(session.toMap());
      print('[MindSetSessionService] Session ${session.sessionId} created');
    } catch (e) {
      print('[MindSetSessionService] Error creating session: $e');
      rethrow;
    }
  }

  Future<void> updateSession(MindSetSession session) async {
    try {
      await _sessions.doc(session.sessionId).update(session.toMap());
      print('[MindSetSessionService] Session ${session.sessionId} updated');
    } catch (e) {
      print('[MindSetSessionService] Error updating session: $e');
      rethrow;
    }
  }

  Future<void> startSession(MindSetSession session) async {
    try {
      final startedSession = session.copyWith(
        sessionStatus: 'active',
        sessionStartedAt: session.sessionStartedAt ?? DateTime.now(),
      );
      await _sessions.doc(session.sessionId).update(startedSession.toMap());
      await _logSessionEvent('mindset_session_started', startedSession);
      print('[MindSetSessionService] Session ${session.sessionId} started');
    } catch (e) {
      print('[MindSetSessionService] Error starting session: $e');
      rethrow;
    }
  }

  Future<void> endSession(String sessionId, DateTime endedAt) async {
    try {
      final session = await _getSession(sessionId);
      await _sessions.doc(sessionId).update({
        'sessionStatus': 'completed',
        'sessionEndedAt': Timestamp.fromDate(endedAt),
      });
      if (session != null) {
        await _logSessionEvent(
          'mindset_session_completed',
          session.copyWith(
            sessionStatus: 'completed',
            sessionEndedAt: endedAt,
          ),
        );
      }
      print('[MindSetSessionService] Session $sessionId ended');
    } catch (e) {
      print('[MindSetSessionService] Error ending session: $e');
      rethrow;
    }
  }

  Future<void> completeSession({
    required MindSetSession session,
    required DateTime endedAt,
    required int tasksTotal,
    required int tasksDone,
  }) async {
    try {
      final startedAt = session.sessionStartedAt ?? session.sessionCreatedAt;
      final duration = endedAt.difference(startedAt);

      final completedSession = session.copyWith(
        sessionStatus: 'completed',
        sessionEndedAt: endedAt,
        sessionStats: session.sessionStats.copyWith(
          tasksTotalCount: tasksTotal,
          tasksDoneCount: tasksDone,
          sessionFocusDurationMinutes: duration.inMinutes,
          sessionFocusDurationSeconds: duration.inSeconds,
          pomodoroIsRunning: false,
        ),
      );

      await _sessions.doc(session.sessionId).update(completedSession.toMap());
      await _logSessionEvent('mindset_session_completed', completedSession);
      print('[MindSetSessionService] Session ${session.sessionId} completed');
    } catch (e) {
      print('[MindSetSessionService] Error completing session ${session.sessionId}: $e');
      rethrow;
    }
  }

  Future<void> cancelSession(String sessionId) async {
    try {
      final session = await _getSession(sessionId);
      await _sessions.doc(sessionId).update({
        'sessionStatus': 'cancelled',
        'sessionEndedAt': Timestamp.now(),
      });
      if (session != null) {
        await _logSessionEvent(
          'mindset_session_cancelled',
          session.copyWith(
            sessionStatus: 'cancelled',
            sessionEndedAt: DateTime.now(),
          ),
        );
      }
      print('[MindSetSessionService] Session $sessionId cancelled');
    } catch (e) {
      print('[MindSetSessionService] Error cancelling session: $e');
      rethrow;
    }
  }

  Future<void> addTaskToSession(String sessionId, String taskId) async {
    try {
      await _sessions.doc(sessionId).update({
        'sessionTaskIds': FieldValue.arrayUnion([taskId]),
      });
      print('[MindSetSessionService] Session $sessionId linked to task $taskId');
    } catch (e) {
      print('[MindSetSessionService] Error adding task $taskId to session $sessionId: $e');
      rethrow;
    }
  }

  Future<void> removeTaskFromSession(String sessionId, String taskId) async {
    try {
      await _sessions.doc(sessionId).update({
        'sessionTaskIds': FieldValue.arrayRemove([taskId]),
      });
      print('[MindSetSessionService] Session $sessionId unlinked from task $taskId');
    } catch (e) {
      print('[MindSetSessionService] Error removing task $taskId from session $sessionId: $e');
      rethrow;
    }
  }

  Stream<List<MindSetSession>> streamUserSessions(String userId) {
    return _sessions
        .where('sessionUserId', isEqualTo: userId)
        .orderBy('sessionCreatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => MindSetSession.fromMap(
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  Stream<MindSetSession?> streamActiveSession(String userId) {
    return _sessions
        .where('sessionUserId', isEqualTo: userId)
        .where('sessionStatus', whereIn: ['active', 'created'])
        .orderBy('sessionCreatedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return MindSetSession.fromMap(
            snapshot.docs.first.data() as Map<String, dynamic>,
          );
        });
  }

  Future<MindSetSession?> getSessionById(String sessionId) {
    return _getSession(sessionId);
  }

  Future<MindSetSession?> _getSession(String sessionId) async {
    try {
      final doc = await _sessions.doc(sessionId).get();
      if (!doc.exists) return null;
      return MindSetSession.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      print('[MindSetSessionService] Error fetching session $sessionId: $e');
      return null;
    }
  }

  Future<void> _logSessionEvent(
    String activityType,
    MindSetSession session,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final description = _buildDescription(activityType, session);

    await _activityEventService.logEvent(
      userId: user.uid,
      userName: user.displayName ?? 'Unknown User',
      userProfilePicture: user.photoURL,
      activityType: activityType,
      description: description,
      metadata: {
        'sessionTitle': session.sessionTitle,
        'sessionType': session.sessionType,
        'sessionMode': session.sessionMode,
        'sessionStatus': session.sessionStatus,
      },
    );
  }

  String _buildDescription(String activityType, MindSetSession session) {
    final label = _sessionTypeLabel(session.sessionType);
    switch (activityType) {
      case 'mindset_session_started':
        return 'started a $label Mind:Set session';
      case 'mindset_session_completed':
        return 'completed a $label Mind:Set session';
      case 'mindset_session_cancelled':
        return 'cancelled a $label Mind:Set session';
      case 'mindset_session_created':
      default:
        return 'created a $label Mind:Set session';
    }
  }

  String _sessionTypeLabel(String sessionType) {
    switch (sessionType) {
      case 'on_the_spot':
        return 'On the Spot';
      case 'go_with_flow':
        return 'Go with the Flow';
      case 'follow_through':
        return 'Follow Through';
      default:
        return 'Mind:Set';
    }
  }
}
