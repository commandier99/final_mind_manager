import 'package:flutter/material.dart';

class MindSetPage extends StatefulWidget {
  const MindSetPage({super.key});

  @override
  State<MindSetPage> createState() => _MindSetPageState();
}

class _MindSetPageState extends State<MindSetPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('Mind:Set'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            const Text(
              'What do you want to do?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Divider(thickness: 1),
            const Spacer(),
            
            // Buttons Row
            Row(
              children: [
                // Go with the Flow Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Navigate to Go with the Flow mode
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Column(
                      children: const [
                        Text(
                          'Go with the Flow',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Do tasks as they come.',
                          style: TextStyle(
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Follow Through Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Navigate to Follow Through mode
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Column(
                      children: const [
                        Text(
                          'Follow Through',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Do tasks that were pre-planned.',
                          style: TextStyle(
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
