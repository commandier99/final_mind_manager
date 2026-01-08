import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/features/search/providers/search_provider.dart';

class TaskSearchBar extends StatefulWidget {
  final String userId;

  const TaskSearchBar({
    required this.userId,
    super.key,
  });

  @override
  State<TaskSearchBar> createState() => _TaskSearchBarState();
}

class _TaskSearchBarState extends State<TaskSearchBar> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchProvider>(
      builder: (context, searchProvider, child) {
        return TextField(
          controller: _searchController,
          onChanged: (query) {
            if (query.isEmpty) {
              searchProvider.clearTaskResults();
            } else {
              searchProvider.searchTasks(query, widget.userId);
            }
          },
          decoration: InputDecoration(
            hintText: 'Search tasks by title or description...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      searchProvider.clearTaskResults();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        );
      },
    );
  }
}
