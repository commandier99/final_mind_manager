import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import 'date_widget.dart';

class GreetingSection extends StatelessWidget {
  const GreetingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final userName = userProvider.currentUser?.userName ?? 'User';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date section
            const DateWidget(),
            // Greeting text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 18, left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $userName!',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'What do you want to do today?',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(
          color: Colors.grey[400],
          thickness: 1,
        ),
      ],
    );
  }
}
