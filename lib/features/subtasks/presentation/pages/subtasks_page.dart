import 'package:flutter/material.dart';

class SubtasksPage extends StatefulWidget {
  const SubtasksPage({super.key});

  @override
  State<SubtasksPage> createState() => _SubtasksPageState();
}

class _SubtasksPageState extends State<SubtasksPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subtasks'),
      ),
      body: const Center(
        child: Text('Subtasks Page'),
      ),
    );
  }
}
