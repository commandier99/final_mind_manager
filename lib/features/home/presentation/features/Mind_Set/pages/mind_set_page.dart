import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/shared/features/users/datasources/providers/user_provider.dart';
import '../datasources/models/mind_set_session_model.dart';
import '../datasources/services/mind_set_session_service.dart';
import '../widgets/mind_set_active_session_view.dart';
import '../widgets/mind_set_selection_view.dart';

class MindSetPage extends StatefulWidget {
  const MindSetPage({super.key});

  @override
  State<MindSetPage> createState() => _MindSetPageState();
}

class _MindSetPageState extends State<MindSetPage> {
  final MindSetSessionService _sessionService = MindSetSessionService();

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<UserProvider>().userId;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('Mind:Set'),
        centerTitle: true,
      ),
      body: userId == null
          ? const MindSetSelectionView()
          : StreamBuilder<MindSetSession?>(
              stream: _sessionService.streamActiveSession(userId),
              builder: (context, snapshot) {
                final activeSession = snapshot.data;
                if (activeSession != null) {
                  return MindSetActiveSessionView(session: activeSession);
                }
                return const MindSetSelectionView();
              },
            ),
    );
  }
}
