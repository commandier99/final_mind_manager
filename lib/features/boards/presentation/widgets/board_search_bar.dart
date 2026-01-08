import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/features/search/providers/search_provider.dart';

class BoardSearchBar extends StatefulWidget {
  final String userId;

  const BoardSearchBar({
    required this.userId,
    super.key,
  });

  @override
  State<BoardSearchBar> createState() => _BoardSearchBarState();
}

class _BoardSearchBarState extends State<BoardSearchBar> {
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
              searchProvider.clearBoardResults();
            } else {
              searchProvider.searchBoards(query, widget.userId);
            }
          },
          decoration: InputDecoration(
            hintText: 'Search boards by name or description...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      searchProvider.clearBoardResults();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.white,
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
