import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../thoughts/datasources/models/thought_model.dart';
import '../../../../thoughts/datasources/services/thought_service.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../datasources/models/board_model.dart';
import '../cards/board_submission_card.dart';

class BoardSubmissionsSection extends StatelessWidget {
  const BoardSubmissionsSection({
    super.key,
    required this.boardId,
    required this.board,
  });

  final String boardId;
  final Board board;

  @override
  Widget build(BuildContext context) {
    final thoughtService = ThoughtService();

    return StreamBuilder<List<Thought>>(
      stream: thoughtService.streamThoughtsByBoard(boardId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Could not load submissions.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red[400],
                ),
              ),
            ),
          );
        }

        final thoughts = snapshot.data ?? const <Thought>[];
        final currentUserId = context.read<UserProvider>().userId ?? '';
        final isManager = board.isManager(currentUserId);
        final submissions = thoughts
            .where((thought) {
              if (thought.type != Thought.typeSubmissionFeedback) return false;
              if (isManager) return true;
              final metadata = thought.metadata ?? const <String, dynamic>{};
              final submissionState =
                  (metadata['submissionState']?.toString() ?? '')
                      .trim()
                      .toLowerCase();
              return thought.authorId == currentUserId ||
                  submissionState == 'approved';
            })
            .toList();

        if (submissions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No submissions yet.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: submissions
                .map(
                  (thought) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BoardSubmissionCard(
                      thought: thought,
                      board: board,
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}
