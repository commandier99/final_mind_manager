import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('[DEBUG] HelpPage: build called');
    return const Center(child: Text('Help Page'));
  }
}
