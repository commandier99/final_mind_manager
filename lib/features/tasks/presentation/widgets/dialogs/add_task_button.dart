import 'package:flutter/material.dart';
import 'add_task_dialog.dart';

class AddTaskButton extends StatelessWidget {
  final String userId;

  const AddTaskButton({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (_) => AddTaskDialog(userId: userId),  // Pass userId to the dialog
        );
      },
      shape: const CircleBorder(),
      child: const Icon(Icons.add),
    );
  }
}
