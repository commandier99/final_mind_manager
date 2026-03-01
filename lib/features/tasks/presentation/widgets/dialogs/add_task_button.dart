import 'package:flutter/material.dart';
import 'add_task_dialog.dart';

class AddTaskButton extends StatelessWidget {
  final String userId;

  const AddTaskButton({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => AddTaskDialog(userId: userId),
        );
      },
      shape: const CircleBorder(),
      child: const Icon(Icons.add),
    );
  }
}
