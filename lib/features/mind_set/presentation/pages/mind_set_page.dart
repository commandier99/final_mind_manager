import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/shared/features/users/datasources/providers/user_provider.dart';
import '../../datasources/models/mind_set_session_model.dart';
import '../../datasources/services/mind_set_session_service.dart';
import '../widgets/views/mind_set_active_session_view.dart';
import '../widgets/views/mind_set_selection_view.dart';
import '../widgets/mind_set_details_settings_form.dart';

class MindSetPage extends StatefulWidget {
  const MindSetPage({super.key});

  @override
  State<MindSetPage> createState() => _MindSetPageState();
}

class _MindSetPageState extends State<MindSetPage> {
  final MindSetSessionService _sessionService = MindSetSessionService();
  bool _showTimer = false;
  String _taskCountMode = 'progress';

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<UserProvider>().userId;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('MIND:SET'),
        centerTitle: true,
        actions: [
          if (userId != null)
            StreamBuilder<MindSetSession?>(
              stream: _sessionService.streamActiveSession(userId),
              builder: (context, snapshot) {
                final activeSession = snapshot.data;

                if (activeSession != null) {
                  return IconButton(
                    icon: const Icon(Icons.more_vert),
                    tooltip: 'Options',
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      builder: (context) => MindSetDetailsSettingsForm(
                        showTimer: _showTimer,
                        onTimerToggle: (value) {
                          setState(() => _showTimer = value);
                        },
                        taskCountMode: _taskCountMode,
                        onTaskCountModeChange: (value) {
                          setState(() => _taskCountMode = value);
                        },
                        selectedMode: activeSession.sessionMode,
                      ),
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
        ],
      ),
      body: userId == null
          ? const MindSetSelectionView()
          : StreamBuilder<MindSetSession?>(
              stream: _sessionService.streamActiveSession(userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const MindSetSelectionView();
                }

                final activeSession = snapshot.data;

                if (activeSession != null) {
                  // Auto-hide timer in Pomodoro mode
                  if (activeSession.sessionMode == 'Pomodoro' &&
                      _showTimer) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _showTimer = false);
                      }
                    });
                  }

                  return MindSetActiveSessionView(
                    session: activeSession,
                    showTimer: _showTimer,
                    onTimerToggle: (value) =>
                        setState(() => _showTimer = value),
                    taskCountMode: _taskCountMode,
                  );
                }

                return const MindSetSelectionView();
              },
            ),
    );
  }
}
