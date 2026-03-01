import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/models/board_model.dart';
import '../../../datasources/models/board_roles.dart';
import '../../../datasources/providers/board_provider.dart';
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
  late TextEditingController _taskCapacityController;
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
    _taskCapacityController = TextEditingController(
      text: widget.board.boardTaskCapacity.toString(),
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
    _taskCapacityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Board title cannot be empty')),
      );
      return;
    }

    final parsedCapacity = int.tryParse(_taskCapacityController.text.trim());
    if (parsedCapacity == null || parsedCapacity < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Member task capacity must be a whole number >= 0'),
        ),
      );
      return;
    }

    try {
      await context.read<BoardProvider>().updateBoard(
        board: widget.board,
        newTitle: _titleController.text.trim(),
        newGoal: _goalController.text.trim(),
        newGoalDescription: _descriptionController.text.trim(),
        memberRoles: _memberRoles,
        boardTaskCapacity: parsedCapacity,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Board updated successfully')),
        );
      }
    } catch (e) {
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
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Board Settings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _taskCapacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Member Task Capacity',
                  border: OutlineInputBorder(),
                  helperText: 'Same cap for all members. Use 0 for unlimited.',
                ),
              ),
              const SizedBox(height: 24),

              // Supervisor Selection
              if (_memberNames.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Board Supervisor',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Supervisors can view progress but cannot be assigned to tasks.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                if (_loadingMembers)
                  const Center(child: CircularProgressIndicator())
                else
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Select Supervisor',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_search),
                    ),
                    initialValue:
                        _memberRoles.entries
                            .firstWhere(
                              (entry) =>
                                  BoardRoles.normalize(entry.value) ==
                                  BoardRoles.supervisor,
                              orElse: () => const MapEntry('', ''),
                            )
                            .key
                            .isEmpty
                        ? null
                        : _memberRoles.entries
                              .firstWhere(
                                (entry) =>
                                    BoardRoles.normalize(entry.value) ==
                                    BoardRoles.supervisor,
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
                    onChanged: (String? newSupervisorId) {
                      setState(() {
                        // Reset all members to 'member' role
                        for (var memberId in _memberNames.keys) {
                          _memberRoles[memberId] = BoardRoles.member;
                        }

                        // Set the selected member as supervisor
                        if (newSupervisorId != null &&
                            newSupervisorId.isNotEmpty) {
                          _memberRoles[newSupervisorId] = BoardRoles.supervisor;
                        } else {
                          // Keep map values normalized to known roles.
                          _memberRoles.updateAll(
                            (_, role) => BoardRoles.normalize(role),
                          );
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
