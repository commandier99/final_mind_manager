import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../datasources/models/thought_model.dart';
import '../../datasources/providers/thought_provider.dart';
import '../../../../shared/datasources/providers/navigation_provider.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../widgets/dialogs/create_thought_dialog.dart';
import '../widgets/sections/thought_list_section.dart';

class ThoughtsPage extends StatefulWidget {
  const ThoughtsPage({super.key});

  @override
  State<ThoughtsPage> createState() => _ThoughtsPageState();
}

class _ThoughtsPageState extends State<ThoughtsPage> {
  static const List<_ThoughtTab> _tabs = [
    _ThoughtTab(
      label: 'Reminders',
      type: Thought.typeReminder,
      emptyLabel: 'No reminders yet.',
    ),
    _ThoughtTab(
      label: 'Board Requests',
      type: Thought.typeBoardRequest,
      emptyLabel: 'No board requests yet.',
    ),
    _ThoughtTab(
      label: 'Assignments',
      type: Thought.typeTaskAssignment,
      emptyLabel: 'No task assignments yet.',
    ),
    _ThoughtTab(
      label: 'Task Requests',
      type: Thought.typeTaskRequest,
      emptyLabel: 'No task requests yet.',
    ),
    _ThoughtTab(
      label: 'Suggestions',
      type: Thought.typeSuggestion,
      emptyLabel: 'No suggestions yet.',
    ),
    _ThoughtTab(
      label: 'Submissions',
      type: Thought.typeSubmissionFeedback,
      emptyLabel: 'No submissions or feedback yet.',
    ),
  ];

  int _indexForType(String? type) {
    final index = _tabs.indexWhere((tab) => tab.type == type);
    return index >= 0 ? index : 0;
  }

  Future<void> _refreshThoughts() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null || userId.isEmpty) return;
    context.read<ThoughtProvider>().streamThoughtsForUser(userId);
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId = context.read<UserProvider>().userId;
      if (userId != null && userId.isNotEmpty) {
        context.read<ThoughtProvider>().streamThoughtsForUser(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<NavigationProvider>();
    final selectedThoughtId = navigation.selectedThoughtId;
    final selectedThoughtType = navigation.selectedThoughtType;

    return DefaultTabController(
      length: _tabs.length,
      initialIndex: _indexForType(selectedThoughtType),
      child: Builder(
        builder: (context) {
          final controller = DefaultTabController.of(context);
          final targetIndex = _indexForType(selectedThoughtType);
          if (controller.index != targetIndex) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final currentController = DefaultTabController.of(context);
              if (currentController.index != targetIndex) {
                currentController.animateTo(targetIndex);
              }
            });
          }

          return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showCreateThoughtPlaceholder,
          icon: const Icon(Icons.add_comment_outlined),
          label: const Text('Create Thought'),
        ),
        body: Consumer<ThoughtProvider>(
          builder: (context, thoughtProvider, _) {
            if (thoughtProvider.isLoading && thoughtProvider.thoughts.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (thoughtProvider.error != null &&
                thoughtProvider.thoughts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    thoughtProvider.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    'Thoughts',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Track reminders, requests, assignments, suggestions, and feedback in one place.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: _tabs.map((tab) => Tab(text: tab.label)).toList(),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: _tabs.map((tab) {
                      final thoughts = thoughtProvider.thoughtsByType(tab.type);
                      return RefreshIndicator(
                        onRefresh: _refreshThoughts,
                        child: ThoughtListSection(
                          thoughts: thoughts,
                          emptyLabel: tab.emptyLabel,
                          highlightedThoughtId:
                              tab.type == selectedThoughtType
                                  ? selectedThoughtId
                                  : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
          );
        },
      ),
    );
  }

  void _showCreateThoughtPlaceholder() {
    CreateThoughtDialog.show(context).then((created) {
      if (created == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thought created.')),
        );
      }
    });
  }
}

class _ThoughtTab {
  final String label;
  final String type;
  final String emptyLabel;

  const _ThoughtTab({
    required this.label,
    required this.type,
    required this.emptyLabel,
  });
}
