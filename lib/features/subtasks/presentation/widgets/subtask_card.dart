import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../datasources/models/subtask_model.dart';

class SubtaskCard extends StatelessWidget {
  final Subtask subtask;
  final ValueChanged<bool?>? onToggleDone;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;
  final bool showCheckbox;
  final bool showOwner;
  final bool showDoneIcon;
  final EdgeInsetsGeometry contentPadding;
  final double elevation;
  final BorderRadiusGeometry borderRadius;

  const SubtaskCard({
    super.key,
    required this.subtask,
    this.onToggleDone,
    this.onDelete,
    this.onEdit,
    this.onTap,
    this.showCheckbox = true,
    this.showOwner = false,
    this.showDoneIcon = true,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 8,
    ),
    this.elevation = 2,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = subtask.subtaskIsDone;
    final colorScheme = theme.colorScheme;

    final cardChild = GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: elevation,
        color: isDone ? colorScheme.surfaceContainerHighest : colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: BorderSide(
            color: isDone
                ? colorScheme.primary.withValues(alpha: 0.24)
                : colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: Padding(
          padding: contentPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showCheckbox) ...[
                Checkbox(
                  value: isDone,
                  onChanged: onToggleDone,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtask.subtaskTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface,
                      ),
                    ),
                    if (showOwner) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            subtask.subtaskOwnerName,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (showDoneIcon && isDone)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    final hasActions = onDelete != null || onEdit != null;
    if (!hasActions) return cardChild;

    return Slidable(
      key: ValueKey(subtask.subtaskId),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.48,
        children: [
          if (onEdit != null)
            Expanded(
              child: Container(
                alignment: Alignment.center,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade500,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(8),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Edit',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Container(
              alignment: Alignment.center,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(8),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      child: cardChild,
    );
  }
}
