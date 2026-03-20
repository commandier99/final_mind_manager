import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/users/datasources/models/user_model.dart';
import '../../../features/users/datasources/providers/user_provider.dart';

const List<String> _availableProfileSkills = [
  'Front-end',
  'Backend',
  'Full Stack',
  'UI/UX',
  'Project Management',
  'Data Analysis',
  'Mobile Development',
];

Future<void> showManageSkillsDialog(BuildContext context, UserModel user) {
  final selectedSkills = [...user.userSkills];

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Manage Skills'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select up to 3 skills (${selectedSkills.length}/3)',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              ..._availableProfileSkills.map((skill) {
                final isSelected = selectedSkills.contains(skill);
                final canSelect = selectedSkills.length < 3 || isSelected;

                return CheckboxListTile(
                  title: Text(skill),
                  value: isSelected,
                  onChanged: canSelect
                      ? (value) {
                          setState(() {
                            if (value == true) {
                              selectedSkills.add(skill);
                            } else {
                              selectedSkills.remove(skill);
                            }
                          });
                        }
                      : null,
                  enabled: canSelect,
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedUser = user.copyWith(userSkills: selectedSkills);

              try {
                await context.read<UserProvider>().updateUserData(updatedUser);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Skills updated successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating skills: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
