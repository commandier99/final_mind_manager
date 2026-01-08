import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_focus_session_model.dart';

class TaskFocusSessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> startFocusSession(TaskFocusSession focusSession) async {
    try {
      print('[DEBUG] TaskFocusSessionService: startFocusSession for taskId = ${focusSession.taskId}');
      await _firestore
          .collection('focusSessions')
          .doc(focusSession.focusSessionId)
          .set(focusSession.toMap());
      // Mark the related task as in-progress when a focus session starts
      try {
        await _firestore.collection('tasks').doc(focusSession.taskId).update({
          'taskStatus': 'IN_PROGRESS',
        });
      } catch (e) {
        print('[DEBUG] TaskFocusSessionService: Failed to update task status to IN_PROGRESS: $e');
      }
      print('✅ Focus session ${focusSession.focusSessionId} started');
    } catch (e) {
      print('⚠️ Error starting focus session: $e');
      rethrow;
    }
  }

  Future<void> updateFocusSession(TaskFocusSession focusSession) async {
    try {
      print('[DEBUG] TaskFocusSessionService: updateFocusSession for sessionId = ${focusSession.focusSessionId}');
      await _firestore
          .collection('focusSessions')
          .doc(focusSession.focusSessionId)
          .update(focusSession.toMap());
      print('✅ Focus session ${focusSession.focusSessionId} updated');
    } catch (e) {
      print('⚠️ Error updating focus session: $e');
      rethrow;
    }
  }

  Future<void> endFocusSession(
    String focusSessionId, {
    required int actualDurationMinutes,
    required bool wasCompleted,
    required String endReason,
    required int productivityScore,
    String? notes,
  }) async {
    try {
      print('[DEBUG] TaskFocusSessionService: endFocusSession for sessionId = $focusSessionId');
      await _firestore.collection('focusSessions').doc(focusSessionId).update({
        'focusEndedAt': Timestamp.fromDate(DateTime.now()),
        'focusActualDurationMinutes': actualDurationMinutes,
        'focusWasCompleted': wasCompleted,
        'focusEndReason': endReason,
        'focusProductivityScore': productivityScore,
        if (notes != null) 'focusNotes': notes,
      });
      // Try to update the associated task status based on how the session ended
      try {
        // Fetch the focus session to read its taskId
        final doc = await _firestore.collection('focusSessions').doc(focusSessionId).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final String? taskId = data['taskId'] as String?;
          if (taskId != null && taskId.isNotEmpty) {
            String newStatus = 'IN_PROGRESS';
            // If the session ended because of a break or stop, set task to paused
            if (endReason == 'break' || endReason == 'stopped') {
              newStatus = 'ON_PAUSE';
            } else if (endReason == 'completed') {
              // keep as IN_PROGRESS — user finished the interval but may continue
              newStatus = 'IN_PROGRESS';
            }

            await _firestore.collection('tasks').doc(taskId).update({
              'taskStatus': newStatus,
            });
          }
        }
      } catch (e) {
        print('[DEBUG] TaskFocusSessionService: Failed to update task status on endFocusSession: $e');
      }
      print('✅ Focus session $focusSessionId ended');
    } catch (e) {
      print('⚠️ Error ending focus session: $e');
      rethrow;
    }
  }

  Stream<List<TaskFocusSession>> streamTaskFocusSessions(String taskId) {
    print('[DEBUG] TaskFocusSessionService: streamTaskFocusSessions for taskId = $taskId');
    return _firestore
        .collection('focusSessions')
        .where('taskId', isEqualTo: taskId)
        .orderBy('focusStartedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final sessions = snapshot.docs
          .map((doc) => TaskFocusSession.fromMap(doc.data(), doc.id))
          .toList();
      print('[DEBUG] TaskFocusSessionService: Retrieved ${sessions.length} focus sessions for task $taskId');
      return sessions;
    });
  }

  Stream<List<TaskFocusSession>> streamUserFocusSessions(String userId) {
    print('[DEBUG] TaskFocusSessionService: streamUserFocusSessions for userId = $userId');
    return _firestore
        .collection('focusSessions')
        .where('userId', isEqualTo: userId)
        .orderBy('focusStartedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final sessions = snapshot.docs
          .map((doc) => TaskFocusSession.fromMap(doc.data(), doc.id))
          .toList();
      print('[DEBUG] TaskFocusSessionService: Retrieved ${sessions.length} focus sessions for user $userId');
      return sessions;
    });
  }

  Future<TaskFocusSession?> getFocusSession(String focusSessionId) async {
    try {
      print('[DEBUG] TaskFocusSessionService: getFocusSession for sessionId = $focusSessionId');
      final doc = await _firestore
          .collection('focusSessions')
          .doc(focusSessionId)
          .get();
      if (doc.exists) {
        return TaskFocusSession.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      print('⚠️ Error getting focus session: $e');
      rethrow;
    }
  }
}
