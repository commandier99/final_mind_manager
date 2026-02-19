import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/providers/board_provider.dart';

class AddBoardFormPage extends StatefulWidget {
  const AddBoardFormPage({super.key});

  @override
  State<AddBoardFormPage> createState() => _AddBoardFormPageState();
}

class _AddBoardFormPageState extends State<AddBoardFormPage> {
  late TextEditingController _titleController;
  late TextEditingController _goalController;
  late TextEditingController _descriptionController;
  String _selectedBoardType = 'team';
  String _selectedBoardPurpose = 'project';
  bool _isSubmitting = false;

  final List<_BoardChoice> _boardTypeChoices = const [
    _BoardChoice(
      value: 'team',
      shortLabel: 'Team',
      title: 'Team Board',
      description: 'For group projects. Shows assignment options.',
    ),
    _BoardChoice(
      value: 'personal',
      shortLabel: 'Personal',
      title: 'Personal Board',
      description: 'For solo work. Tasks auto-assign to you.',
    ),
  ];

  final List<_BoardChoice> _boardPurposeChoices = const [
    _BoardChoice(
      value: 'project',
      shortLabel: 'Project',
      title: 'Project Board',
      description: 'Track a project with clear goals and deliverables.',
    ),
    _BoardChoice(
      value: 'category',
      shortLabel: 'Category',
      title: 'Category Board',
      description: 'Organize tasks into a category without a specific end goal.',
    ),
  ];

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

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    var title = _titleController.text.trim();
    final goal = _selectedBoardPurpose == 'project'
      ? _goalController.text
      : '';
    final description = _descriptionController.text;

    try {
      final boardProvider = context.read<BoardProvider>();

      if (title.isEmpty) {
        final nextNumber =
            _getNextUntitledBoardNumber(boardProvider.boards);
        title = 'Board ${nextNumber.toString().padLeft(2, '0')}';
      }

      await boardProvider.addBoard(
        title: title,
        goal: goal,
        description: description,
        boardType: _selectedBoardType,
        boardPurpose: _selectedBoardPurpose,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Board created successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating board: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildChoiceSelector({
    required String title,
    required Color accentColor,
    required List<_BoardChoice> options,
    required String selectedValue,
    required ValueChanged<String> onChanged,
  }) {
    final selectedOption =
        options.firstWhere((option) => option.value == selectedValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final buttonWidth = (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final isSelected = option.value == selectedValue;
                return SizedBox(
                  width: buttonWidth,
                  child: OutlinedButton(
                    onPressed: () => onChanged(option.value),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      backgroundColor: isSelected
                          ? accentColor.withOpacity(0.12)
                          : Colors.white,
                      side: BorderSide(
                        color: isSelected ? accentColor : Colors.grey.shade300,
                        width: isSelected ? 1.5 : 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      option.shortLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? accentColor : Colors.grey.shade800,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedOption.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                selectedOption.description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Board'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              maxLength: 60,
              decoration: const InputDecoration(
                labelText: 'Board Title',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintText: 'e.g., SE1 Project, House Chores, ...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedBoardPurpose == 'project') ...[
              TextField(
                controller: _goalController,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Board Goal',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  hintText: 'e.g., Create a software, organize home tasks...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _descriptionController,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Description',
                floatingLabelBehavior: FloatingLabelBehavior.always,
                hintText: 'Add details about this board\'s purpose...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildChoiceSelector(
              title: 'Board Purpose',
              accentColor: Colors.green.shade600,
              options: _boardPurposeChoices,
              selectedValue: _selectedBoardPurpose,
              onChanged: (value) {
                setState(() {
                  _selectedBoardPurpose = value;
                  if (value == 'category') {
                    _goalController.clear();
                  }
                });
              },
            ),
            const SizedBox(height: 6),
            Text(
              'Goal is required only for Project boards.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            _buildChoiceSelector(
              title: 'Board Type',
              accentColor: Colors.blue.shade600,
              options: _boardTypeChoices,
              selectedValue: _selectedBoardType,
              onChanged: (value) {
                setState(() {
                  _selectedBoardType = value;
                });
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: Text(_isSubmitting ? 'Creating...' : 'Create Board'),
          ),
        ),
      ),
    );
  }
}

class _BoardChoice {
  final String value;
  final String shortLabel;
  final String title;
  final String description;

  const _BoardChoice({
    required this.value,
    required this.shortLabel,
    required this.title,
    required this.description,
  });
}
