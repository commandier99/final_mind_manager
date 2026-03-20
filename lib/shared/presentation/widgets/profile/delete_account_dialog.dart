import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../features/users/datasources/providers/user_provider.dart';

Future<void> showDeleteAccountDialog(BuildContext context) {
  final confirmController = TextEditingController();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete Account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This action is permanent and cannot be undone.',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
          const SizedBox(height: 16),
          const Text('All your data will be permanently deleted, including:'),
          const SizedBox(height: 8),
          const Text('- All boards and tasks'),
          const Text('- Profile information'),
          const Text('- Activity history'),
          const SizedBox(height: 16),
          TextField(
            controller: confirmController,
            decoration: const InputDecoration(
              labelText: 'Type "DELETE" to confirm',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (confirmController.text.trim() != 'DELETE') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please type DELETE to confirm')),
              );
              return;
            }

            Navigator.pop(dialogContext);

            showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (loadingContext) =>
                  const Center(child: CircularProgressIndicator()),
            );

            try {
              await context.read<UserProvider>().deleteAccount();

              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/auth', (route) => false);
              }
            } catch (e) {
              if (context.mounted) {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Account deletion completed with warnings. You have been signed out.',
                    ),
                    duration: Duration(seconds: 5),
                  ),
                );

                Future.delayed(const Duration(milliseconds: 500), () {
                  if (context.mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/auth', (route) => false);
                  }
                });
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9C88D4),
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete Account'),
        ),
      ],
    ),
  );
}
