import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/users/datasources/models/user_model.dart';
import '../../../features/users/datasources/providers/user_provider.dart';

Future<void> showEditProfileDialog(BuildContext context, UserModel user) {
  final nameController = TextEditingController(text: user.userName);
  final handleController = TextEditingController(text: user.userHandle);
  final phoneController = TextEditingController(text: user.userPhoneNumber);

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Edit Personal Information'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              maxLength: 50,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: handleController,
              decoration: const InputDecoration(
                labelText: 'Handle',
                border: OutlineInputBorder(),
                prefixText: '@',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              maxLength: 30,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
                hintText: '09123456789',
              ),
              keyboardType: TextInputType.phone,
              maxLength: 11,
            ),
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
            if (nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Name cannot be empty')),
              );
              return;
            }

            final updatedUser = user.copyWith(
              userName: nameController.text.trim(),
              userHandle: handleController.text.trim(),
              userPhoneNumber: phoneController.text.trim().isEmpty
                  ? null
                  : phoneController.text.trim(),
            );

            try {
              await context.read<UserProvider>().updateUserData(updatedUser);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating profile: $e')),
                );
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
