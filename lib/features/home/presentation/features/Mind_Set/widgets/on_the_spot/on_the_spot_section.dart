import 'package:flutter/material.dart';
import 'on_the_spot_task_stream.dart';
import '../../datasources/models/mind_set_session_model.dart';

class OnTheSpotSection extends StatefulWidget {
  final String sessionId;
  final List<String> sessionTaskIds;
  final VoidCallback onCancelSet;
  final bool isSessionActive;
  final String mode;
  final MindSetSession? session;

  const OnTheSpotSection({
    super.key,
    required this.sessionId,
    required this.sessionTaskIds,
    required this.onCancelSet,
    required this.isSessionActive,
    required this.mode,
    this.session,
  });

  @override
  State<OnTheSpotSection> createState() => _OnTheSpotSectionState();
}

class _OnTheSpotSectionState extends State<OnTheSpotSection> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: OnTheSpotTaskStream(
        sessionId: widget.sessionId,
        sessionTaskIds: widget.sessionTaskIds,
        mode: widget.mode,
        isSessionActive: widget.isSessionActive,
        session: widget.session,
      ),
    );
  }
}
