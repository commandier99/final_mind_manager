import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/models/board_model.dart';
import '../../../datasources/providers/board_provider.dart';
import '../../../../../shared/features/users/datasources/models/user_model.dart';
import '../../../../../shared/features/search/providers/search_provider.dart';

class AddMemberToBoardDialog extends StatefulWidget {
  final Board board;

  const AddMemberToBoardDialog({
    super.key,
    required this.board,
  });

  @override
  State<AddMemberToBoardDialog> createState() => _AddMemberToBoardDialogState();
}

class _AddMemberToBoardDialogState extends State<AddMemberToBoardDialog> {
  final _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleAddMember(UserModel user) async {
    // Check if user is already a member
    if (widget.board.memberIds.contains(user.userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User is already a member of this board')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final boardProvider = context.read<BoardProvider>();
      await boardProvider.addMemberToBoard(
        boardId: widget.board.boardId,
        userId: user.userId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.userName} added to board')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding member: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Member to ${widget.board.boardTitle}'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search users by name or email',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {});
                  if (value.isNotEmpty) {
                    context.read<SearchProvider>().searchUsers(value);
                  } else {
                    context.read<SearchProvider>().clearSearch();
                  }
                },
              ),
              const SizedBox(height: 16),
              Consumer<SearchProvider>(
                builder: (context, searchProvider, _) {
                  if (_searchController.text.isEmpty) {
                    return const Center(
                      child: Text('Start typing to search for users'),
                    );
                  }

                  if (searchProvider.isSearching) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = searchProvider.searchResults;

                  if (users.isEmpty) {
                    return const Center(
                      child: Text('No users found'),
                    );
                  }

                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final isAlreadyMember =
                            widget.board.memberIds.contains(user.userId);

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user.userProfilePicture != null
                                ? NetworkImage(user.userProfilePicture!)
                                : null,
                            child: user.userProfilePicture == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(user.userName),
                          subtitle: Text(user.userEmail ?? 'No email'),
                          trailing: isAlreadyMember
                              ? Chip(
                                  label: const Text('Member'),
                                  backgroundColor:
                                      Colors.grey.shade300,
                                )
                              : ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () => _handleAddMember(user),
                                  child: const Text('Add'),
                                ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
