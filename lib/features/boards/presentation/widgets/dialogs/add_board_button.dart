import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/providers/board_provider.dart';

class AddBoardButton extends StatefulWidget {
  final String userId;

  const AddBoardButton({super.key, required this.userId});

  @override
  State<AddBoardButton> createState() => _AddBoardButtonState();
}

class _AddBoardButtonState extends State<AddBoardButton> {
  late TextEditingController _titleController;
  late TextEditingController _goalController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _goalController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _goalController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showAddBoardDialog() {
    print('[DEBUG] AddBoardButton: Showing add board dialog');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Board'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Board Title',
                  hintText: 'Enter board title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _goalController,
                decoration: const InputDecoration(
                  labelText: 'Board Goal',
                  hintText: 'Enter board goal',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
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
            onPressed: () {
              print('[DEBUG] AddBoardButton: Cancel button pressed');
              Navigator.pop(context);
              _clearFields();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              print('[DEBUG] AddBoardButton: Create button pressed');
              var title = _titleController.text.trim();
              final goal = _goalController.text;
              final description = _descriptionController.text;

              // Auto-generate title if empty
              if (title.isEmpty) {
                final boardProvider = context.read<BoardProvider>();
                final nextNumber = _getNextUntitledBoardNumber(boardProvider.boards);
                title = 'Board ${nextNumber.toString().padLeft(2, '0')}';
              }

              try {
                final boardProvider = context.read<BoardProvider>();
                await boardProvider.addBoard(
                  title: title,
                  goal: goal,
                  description: description,
                );
                print('[DEBUG] AddBoardButton: Board created successfully');
                Navigator.pop(context);
                _clearFields();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Board created successfully')),
                );
              } catch (e) {
                print('[ERROR] AddBoardButton: Error creating board: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error creating board: $e')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _clearFields() {
    _titleController.clear();
    _goalController.clear();
    _descriptionController.clear();
  }

  int _getNextUntitledBoardNumber(List<dynamic> existingBoards) {
    int maxNumber = 0;
    final regex = RegExp(r'^Board (\d+)$');
    
    for (var board in existingBoards) {
      final match = regex.firstMatch(board.boardTitle ?? '');
      if (match != null) {
        final number = int.parse(match.group(1)!);
        if (number > maxNumber) {
          maxNumber = number;
        }
      }
    }
    
    return maxNumber + 1;
  }

  @override
  Widget build(BuildContext context) {
    print('[DEBUG] AddBoardButton: build called');
    return FloatingActionButton(
      onPressed: _showAddBoardDialog,
      tooltip: 'Add New Board',
      shape: const CircleBorder(),
      child: const Icon(Icons.add),
    );
  }
}
