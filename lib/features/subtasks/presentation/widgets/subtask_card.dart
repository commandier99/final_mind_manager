import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../datasources/models/subtask_model.dart';

class SubtaskCard extends StatelessWidget {
  final Subtask subtask;
  final ValueChanged<bool?>? onToggleDone;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const SubtaskCard({
    super.key,
    required this.subtask,
    this.onToggleDone,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(subtask.subtaskId),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => onDelete?.call(),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: subtask.subtaskIsDone,
                  onChanged: onToggleDone,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subtask.subtaskTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          decoration: subtask.subtaskIsDone
                              ? TextDecoration.lineThrough
                              : null,
                          color: subtask.subtaskIsDone
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                      if (subtask.subtaskDescription != null &&
                          subtask.subtaskDescription!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            subtask.subtaskDescription!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ),
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
                  ),
                ),
                if (subtask.subtaskIsDone)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
