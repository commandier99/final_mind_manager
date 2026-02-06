import 'package:flutter/material.dart';
import '../features/Mind_Set/widgets/on_the_spot_task_stream.dart';

class OnTheSpotSection extends StatefulWidget {
  final VoidCallback onCancelSet;
  final bool isSessionActive;

  const OnTheSpotSection({
    super.key,
    required this.onCancelSet,
    required this.isSessionActive,
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
        mode: 'Checklist',
        isSessionActive: widget.isSessionActive,
      ),
    );
  }
}
