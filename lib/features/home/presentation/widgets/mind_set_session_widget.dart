import 'package:flutter/material.dart';
import '../../../mind_set/datasources/models/mind_set_session_model.dart';
import '../../../mind_set/presentation/pages/mind_set_page.dart';

class MindSetSessionWidget extends StatelessWidget {
  final MindSetSession session;

  const MindSetSessionWidget({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = session.sessionStatus == 'active';

    final tasksDone = session.sessionStats.tasksDoneCount ?? 0;
    final tasksTotal = session.sessionStats.tasksTotalCount ?? 0;

    final focusMinutes =
        session.sessionStats.sessionFocusDurationMinutes ?? 0;

    Color statusColor;
    String statusLabel;

    switch (session.sessionStatus) {
      case 'active':
        statusColor = Colors.blue.shade400;
        statusLabel = 'Ongoing';
        break;
      case 'completed':
        statusColor = Colors.green.shade400;
        statusLabel = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red.shade400;
        statusLabel = 'Cancelled';
        break;
      default:
        statusColor = Colors.grey.shade400;
        statusLabel = session.sessionStatus;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MindSetPage()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: statusColor,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    session.sessionTitle.isEmpty
                        ? 'Mind:Set Session'
                        : session.sessionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            // Mode + Type
            Text(
              '${session.sessionType.replaceAll('_', ' ').toUpperCase()}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),

            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$tasksDone / $tasksTotal tasks',
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  '$focusMinutes min',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),

            if (isActive)
              const Text(
                'Tap to continue →',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
