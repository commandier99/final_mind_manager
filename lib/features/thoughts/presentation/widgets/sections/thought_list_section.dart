import 'package:flutter/material.dart';

import '../../../datasources/models/thought_model.dart';
import '../cards/thought_card.dart';

class ThoughtListSection extends StatelessWidget {
  const ThoughtListSection({
    super.key,
    required this.thoughts,
    required this.emptyLabel,
    this.highlightedThoughtId,
  });

  final List<Thought> thoughts;
  final String emptyLabel;
  final String? highlightedThoughtId;

  @override
  Widget build(BuildContext context) {
    if (thoughts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          SizedBox(
            height: 220,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  emptyLabel,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: thoughts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final thought = thoughts[index];
        return ThoughtCard(
          thought: thought,
          isHighlighted:
              highlightedThoughtId != null &&
              highlightedThoughtId == thought.thoughtId,
        );
      },
    );
  }
}
