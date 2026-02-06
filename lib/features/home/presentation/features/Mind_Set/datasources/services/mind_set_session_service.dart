import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/mind_set_session_model.dart';

class MindSetSessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  CollectionReference get _sessions => _firestore.collection('mindset_sessions');

  Future<void> addSession(MindSetSession session) async {
    try {
      await _sessions.doc(session.sessionId).set(session.toMap());
      print('✅ Mind:Set session ${session.sessionId} created');
    } catch (e) {
      print('⚠️ Error creating Mind:Set session: $e');
    }
  }

  Future<void> updateSession(MindSetSession session) async {
    try {
      await _sessions.doc(session.sessionId).update(session.toMap());
      print('✅ Mind:Set session ${session.sessionId} updated');
    } catch (e) {
      print('⚠️ Error updating Mind:Set session: $e');
    }
  }

  Future<void> endSession(String sessionId, DateTime endedAt) async {
    try {
      await _sessions.doc(sessionId).update({
        'sessionStatus': 'completed',
        'sessionEndedAt': Timestamp.fromDate(endedAt),
      });
      print('✅ Mind:Set session $sessionId ended');
    } catch (e) {
      print('⚠️ Error ending Mind:Set session: $e');
    }
  }

  Future<void> cancelSession(String sessionId) async {
    try {
      await _sessions.doc(sessionId).update({
        'sessionStatus': 'cancelled',
        'sessionEndedAt': Timestamp.now(),
      });
      print('✅ Mind:Set session $sessionId cancelled');
    } catch (e) {
      print('⚠️ Error cancelling Mind:Set session: $e');
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
}
