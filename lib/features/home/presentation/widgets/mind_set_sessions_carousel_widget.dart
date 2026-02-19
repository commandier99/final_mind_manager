import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../mind_set/datasources/services/mind_set_session_service.dart';
import '../../../mind_set/datasources/models/mind_set_session_model.dart';
import 'mind_set_session_widget.dart';
import '../../../mind_set/presentation/pages/mind_set_page.dart';

class MindSetSessionsCarouselWidget extends StatelessWidget {
  const MindSetSessionsCarouselWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<UserProvider>().userId;
    if (userId == null) return const SizedBox();

    final sessionService = MindSetSessionService();

    return StreamBuilder<List<MindSetSession>>(
      stream: sessionService.streamUserSessions(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox();
        }

        final sessions = snapshot.data!;
        final activeSession =
            sessions.firstWhereOrNull((s) => s.sessionStatus == 'active');

        final sortedSessions = [
          if (activeSession != null) activeSession,
          ...sessions.where((s) => s.sessionStatus != 'active').take(5),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mind:Set Sessions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: PageView.builder(
                itemCount: sortedSessions.length,
                itemBuilder: (context, index) {
                  final session = sortedSessions[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: MindSetSessionWidget(session: session),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  
}
