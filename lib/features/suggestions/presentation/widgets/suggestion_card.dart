import 'package:flutter/material.dart';
import '../../datasources/models/suggestion_model.dart';

class SuggestionCard extends StatelessWidget {
  final Suggestion suggestion;
  final VoidCallback? onConvert;
  final VoidCallback? onDelete;
  final bool isConverting;
  final bool isDeleting;
  final bool canDelete;

  const SuggestionCard({
    super.key,
    required this.suggestion,
    this.onConvert,
    this.onDelete,
    this.isConverting = false,
    this.isDeleting = false,
    this.canDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasDescription = suggestion.suggestionDescription.trim().isNotEmpty;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    suggestion.suggestionTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (hasDescription) ...[
              const SizedBox(height: 6),
              Text(
                suggestion.suggestionDescription,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Suggested by ${suggestion.suggestionAuthorName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: isConverting ? null : onConvert,
                  icon: Icon(
                    isConverting ? Icons.hourglass_top : Icons.task_alt,
                    size: 16,
                  ),
                  label: Text(isConverting ? 'Converting' : 'Convert'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (canDelete) ...[
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: isDeleting ? null : onDelete,
                    icon: Icon(
                      isDeleting ? Icons.hourglass_top : Icons.delete_outline,
                      size: 16,
                    ),
                    label: Text(isDeleting ? 'Deleting' : 'Delete'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.red.shade700,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
