import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mind_set_session_model.dart';
import '../services/mind_set_session_service.dart';

class MindSetSessionProvider extends ChangeNotifier {
  final MindSetSessionService _service = MindSetSessionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<MindSetSession> _sessions = [];
  List<MindSetSession> get sessions => _sessions;

  MindSetSession? _activeSession;
  MindSetSession? get activeSession => _activeSession;

  Stream<List<MindSetSession>>? _sessionStream;
  Stream<List<MindSetSession>>? get sessionStream => _sessionStream;

  Stream<MindSetSession?>? _activeSessionStream;
  Stream<MindSetSession?>? get activeSessionStream => _activeSessionStream;

  void streamUserSessions() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _sessionStream = _service.streamUserSessions(userId);
    _sessionStream!.listen((sessions) {
      _sessions = sessions;
      notifyListeners();
    });
  }

  void streamActiveSession() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _activeSessionStream = _service.streamActiveSession(userId);
    _activeSessionStream!.listen((session) {
      _activeSession = session;
      notifyListeners();
    });
  }

  Future<void> createSession(MindSetSession session) async {
    await _service.addSession(session);
  }

  Future<void> updateSession(MindSetSession session) async {
    await _service.updateSession(session);
  }

  Future<void> endSession(String sessionId) async {
    await _service.endSession(sessionId, DateTime.now());
  }

  Future<void> cancelSession(String sessionId) async {
    await _service.cancelSession(sessionId);
  }
}
