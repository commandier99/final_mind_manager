import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/models/board_model.dart';
import '../../../datasources/providers/board_provider.dart';
import '../../../datasources/services/board_services.dart';
import '../../../../../shared/features/users/datasources/services/user_services.dart';

class EditBoardDialog extends StatefulWidget {
  final Board board;

  const EditBoardDialog({super.key, required this.board});

  @override
  State<EditBoardDialog> createState() => _EditBoardDialogState();
}

class _EditBoardDialogState extends State<EditBoardDialog> {
  late TextEditingController _titleController;
  late TextEditingController _goalController;
  late TextEditingController _descriptionController;
  Map<String, String> _memberRoles = {};
  Map<String, String> _memberNames = {};
  bool _loadingMembers = true;

  static const int maxTitleLength = 50;
  static const int maxGoalLength = 100;
  static const int maxDescriptionLength = 500;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.board.boardTitle);
    _goalController = TextEditingController(text: widget.board.boardGoal);
    _descriptionController = TextEditingController(
      text: widget.board.boardGoalDescription,
    );
    _memberRoles = Map<String, String>.from(widget.board.memberRoles);
    _loadMemberNames();
  }

  Future<void> _loadMemberNames() async {
    final names = <String, String>{};

    for (String memberId in widget.board.memberIds) {
      if (memberId != widget.board.boardManagerId) {
        try {
          final user = await UserService().getUserById(memberId);
          if (user != null) {
            names[memberId] = user.userName;
          } else {
            names[memberId] = 'Unknown User';
          }
        } catch (e) {
          names[memberId] = 'Unknown User';
        }
      }
    }

    setState(() {
      _memberNames = names;
      _loadingMembers = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _goalController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Board title cannot be empty')),
      );
      return;
    }

    try {
      final boardService = BoardService();

      // Update board details and member roles
      await boardService.updateBoard(
        widget.board.boardId,
        newTitle: _titleController.text.trim(),
        newGoal: _goalController.text.trim(),
        newGoalDescription: _descriptionController.text.trim(),
        memberRoles: _memberRoles,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Board updated successfully')),
        );
      }
    } catch (e) {
      print('Error updating board: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating board: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Board'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Board Title',
                  border: const OutlineInputBorder(),
                  counterText:
                      '${_titleController.text.length}/$maxTitleLength',
                ),
                maxLength: maxTitleLength,
                autofocus: true,
                onChanged: (value) {
                  setState(() {}); // Update character count
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _goalController,
                decoration: InputDecoration(
                  labelText: 'Goal',
                  border: const OutlineInputBorder(),
                  counterText: '${_goalController.text.length}/$maxGoalLength',
                ),
                maxLength: maxGoalLength,
                onChanged: (value) {
                  setState(() {}); // Update character count
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: const OutlineInputBorder(),
                  counterText:
                      '${_descriptionController.text.length}/$maxDescriptionLength',
                ),
                maxLines: 4,
                maxLength: maxDescriptionLength,
                onChanged: (value) {
                  setState(() {}); // Update character count
                },
              ),
              const SizedBox(height: 24),

              // Inspector Selection
              if (_memberNames.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Board Inspector',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Inspectors can view progress but cannot be assigned to tasks.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                if (_loadingMembers)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Inspector',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_search),
                    ),
                    initialValue:
                        _memberRoles.entries
                                .firstWhere(
                                  (entry) => entry.value == 'inspector',
                                  orElse: () => const MapEntry('', ''),
                                )
                                .key
                                .isEmpty
                            ? null
                            : _memberRoles.entries
                                .firstWhere(
                                  (entry) => entry.value == 'inspector',
                                )
                                .key,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('None'),
                      ),
                      ..._memberNames.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }),
                    ],
                    onChanged: (String? newInspectorId) {
                      setState(() {
                        // Reset all members to 'member' role
                        for (var memberId in _memberNames.keys) {
                          _memberRoles[memberId] = 'member';
                        }

                        // Set the selected member as inspector
                        if (newInspectorId != null &&
                            newInspectorId.isNotEmpty) {
                          _memberRoles[newInspectorId] = 'inspector';
                        }
                      });
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
      ],
    );
  }
}
