import 'package:flutter/material.dart';
import '../../../datasources/providers/subtask_provider.dart';

class AddSubtaskDialog extends StatefulWidget {
  final String parentTaskId;
  final String? subtaskBoardId;
  final SubtaskProvider subtaskProvider;

  const AddSubtaskDialog({
    super.key,
    required this.parentTaskId,
    this.subtaskBoardId,
    required this.subtaskProvider,
  });

  @override
  State<AddSubtaskDialog> createState() => _AddSubtaskDialogState();
}

class _AddSubtaskDialogState extends State<AddSubtaskDialog> {
  late TextEditingController _stepController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _stepController = TextEditingController();
  }

  @override
  void dispose() {
    _stepController.dispose();
    super.dispose();
  }

  void _handleAddSubtask() async {
    if (_stepController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a step')),
      );
      return;
    }

    setState(() => _isLoading = true);

    await widget.subtaskProvider.addSubtask(
      subtaskTaskId: widget.parentTaskId,
      subtaskBoardId: widget.subtaskBoardId ?? '',
      subtaskTitle: _stepController.text.trim(),
      subtaskDescription: null,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Step added successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Step',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _stepController,
              decoration: InputDecoration(
                hintText: 'Step',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              enabled: !_isLoading,
              maxLines: 1,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleAddSubtask,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
