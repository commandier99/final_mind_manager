import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    print('[DEBUG] AboutPage: build called');
    return const Center(child: Text('About Page'));
  }
}
