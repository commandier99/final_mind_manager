import 'package:flutter/material.dart';

class AddBoardDialog extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController goalController;
  final TextEditingController goalDescController;
  final VoidCallback onConfirm;

  const AddBoardDialog({
    super.key,
    required this.titleController,
    required this.goalController,
    required this.goalDescController,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Board'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Board Title',
                hintText: 'Leave blank for auto-generated name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: goalController,
              decoration: const InputDecoration(
                labelText: 'Board Goal',
                hintText: 'Enter board goal',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: goalDescController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter board description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
