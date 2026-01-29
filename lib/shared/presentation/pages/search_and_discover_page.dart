import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/search/providers/search_provider.dart';
import '../../features/users/datasources/models/user_model.dart';
import '../../features/users/datasources/providers/user_provider.dart';
import '../../../features/boards/datasources/models/board_model.dart';
import '../../../features/boards/datasources/providers/board_provider.dart';
import '../../../features/boards/datasources/providers/board_request_provider.dart';

class SearchAndDiscoverPage extends StatefulWidget {
  const SearchAndDiscoverPage({super.key});

  @override
  State<SearchAndDiscoverPage> createState() => _SearchAndDiscoverPageState();
}

class _SearchAndDiscoverPageState extends State<SearchAndDiscoverPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Start streaming all discoverable users on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SearchProvider>().streamDiscoverableUsers();
    });
  }

  @override
  void dispose() {
    context.read<SearchProvider>().stopStreamingUsers();
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    context.read<SearchProvider>().searchUsers(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Column(
        children: [
          // Search bar
          Container(
            color: const Color(0xFFFAFCFD),
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, handle, or skills...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch();
                            setState(() {});
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) {
                setState(() {});
                _performSearch();
              },
            ),
          ),
          // Results
          Expanded(child: _buildUserResults()),
        ],
      ),
    );
  }

  Widget _buildUserResults() {
    return Consumer<SearchProvider>(
      builder: (context, searchProvider, _) {
        if (searchProvider.isLoadingUsers) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = searchProvider.filteredUserResults;

        if (users.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_search, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No users found'),
                SizedBox(height: 8),
                Text(
                  'Try a different search or check back later',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _buildUserCard(user);
          },
        );
      },
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => _showUserProfile(user),
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Profile Picture
              CircleAvatar(
                radius: 28,
                backgroundImage:
                    user.userProfilePicture != null
                        ? NetworkImage(user.userProfilePicture!)
                        : null,
                child:
                    user.userProfilePicture == null
                        ? Text(
                          user.userName[0].toUpperCase(),
                          style: const TextStyle(fontSize: 20),
                        )
                        : null,
              ),
              const SizedBox(width: 12),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '@${user.userHandle}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    if (user.userBio != null && user.userBio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.userBio!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                      ),
                    ],
                    if (user.userSkills.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children:
                            user.userSkills.take(3).map((skill) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  skill,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              // Recruit Button
              IconButton(
                icon: const Icon(Icons.person_add, color: Colors.blue),
                onPressed: () => _showRecruitDialog(user),
                tooltip: 'Recruit to Board',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecruitDialog(UserModel user) async {
    final boardProvider = context.read<BoardProvider>();
    final userProvider = context.read<UserProvider>();
    final currentUserId = userProvider.currentUser?.userId;

    if (currentUserId == null) return;

    final myBoards =
        boardProvider.boards
            .where((board) => board.boardManagerId == currentUserId && board.boardTitle.toLowerCase() != 'personal')
            .toList();

    if (myBoards.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You need to create a board first to recruit members',
            ),
          ),
        );
      }
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Recruit ${user.userName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select a board to invite this user to:'),
                const SizedBox(height: 16),
                ...myBoards.map(
                  (board) => ListTile(
                    title: Text(board.boardTitle),
                    subtitle: Text(board.boardGoal),
                    onTap: () async {
                      Navigator.pop(context);
                      await _sendBoardInvite(board, user);
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  Future<void> _sendBoardInvite(Board board, UserModel user) async {
    // Check if user is already a member
    if (board.memberIds.contains(user.userId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.userName} is already a member of this board'),
          ),
        );
      }
      return;
    }

    // Check if there's already a pending request
    final requestProvider = context.read<BoardRequestProvider>();
    final hasPending = await requestProvider.hasPendingRequest(
      board.boardId,
      user.userId,
    );

    if (hasPending) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${user.userName} already has a pending invite to ${board.boardTitle}',
            ),
          ),
        );
      }
      return;
    }

    try {
      // Send recruitment request instead of directly adding
      await requestProvider.createInvitation(
        boardId: board.boardId,
        boardTitle: board.boardTitle,
        userId: user.userId,
        message: 'You have been invited to join this board',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation sent to ${user.userName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invitation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showUserProfile(UserModel user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage:
                      user.userProfilePicture != null
                          ? NetworkImage(user.userProfilePicture!)
                          : null,
                  child:
                      user.userProfilePicture == null
                          ? Text(user.userName[0].toUpperCase())
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.userName, style: const TextStyle(fontSize: 18)),
                      Text(
                        '@${user.userHandle}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (user.userBio != null && user.userBio!.isNotEmpty) ...[
                    const Text(
                      'Bio:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(user.userBio!),
                    const SizedBox(height: 12),
                  ],
                  if (user.userSkills.isNotEmpty) ...[
                    const Text(
                      'Skills:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          user.userSkills.map((skill) {
                            return Chip(label: Text(skill));
                          }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}
