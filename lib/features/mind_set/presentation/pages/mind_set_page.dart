import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/shared/features/users/datasources/providers/user_provider.dart';
import '/shared/modes/mind_set_mode_policy.dart';
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
  bool _showTimer = true;
  String _taskCountMode = 'progress';

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<UserProvider>().userId;

    if (userId == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          title: const Text('MIND:SET'),
          centerTitle: true,
        ),
        body: const MindSetSelectionView(),
      );
    }

    return StreamBuilder<MindSetSession?>(
      stream: _sessionService.streamActiveSession(userId),
      builder: (context, snapshot) {
        final activeSession = snapshot.data;
        final isTrulyActive = activeSession?.sessionStatus == 'active';
        final modePolicy = !isTrulyActive
            ? null
            : MindSetModePolicy.fromMode(activeSession!.sessionMode);

        if ((modePolicy?.hidesSessionTimer ?? false) && _showTimer) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _showTimer = false);
            }
          });
        }

        final sessionBody = !isTrulyActive
            ? const MindSetSelectionView()
            : MindSetActiveSessionView(
                session: activeSession!,
                showTimer: _showTimer,
                onTimerToggle: (value) {
                  if (!(modePolicy?.hidesSessionTimer ?? false)) {
                    setState(() => _showTimer = value);
                  }
                },
                taskCountMode: _taskCountMode,
              );

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            title: const Text('MIND:SET'),
            centerTitle: true,
            actions: [
              if (isTrulyActive)
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Options',
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    builder: (context) => MindSetDetailsSettingsForm(
                      showTimer: _showTimer,
                      onTimerToggle: (value) {
                        if (!(modePolicy?.hidesSessionTimer ?? false)) {
                          setState(() => _showTimer = value);
                        }
                      },
                      taskCountMode: _taskCountMode,
                      onTaskCountModeChange: (value) {
                        setState(() => _taskCountMode = value);
                      },
                      selectedMode: activeSession!.sessionMode,
                    ),
                  ),
                ),
            ],
          ),
          body: sessionBody,
        );
      },
    );
  }
}
