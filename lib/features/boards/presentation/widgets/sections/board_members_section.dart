import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../shared/features/users/datasources/services/user_services.dart';
import '../../../../../shared/datasources/providers/navigation_provider.dart';
import '../../../datasources/models/board_model.dart';
import '../../../datasources/services/board_services.dart';
import '../../../datasources/providers/board_provider.dart';
import '../../pages/add_member_to_board_page.dart';

class BoardMembersSection extends StatefulWidget {
  final List<String> memberIds;
  final Future<String?> Function(String) getUserName;
  final Future<String?> Function(String) getUserProfilePicture;
  final String boardId;
  final String? currentUserId;
  final VoidCallback? onAddMember;
  final Board board;

  const BoardMembersSection({
    super.key,
    required this.memberIds,
    required this.getUserName,
    required this.getUserProfilePicture,
    required this.boardId,
    this.currentUserId,
    this.onAddMember,
    required this.board,
  });

  @override
  State<BoardMembersSection> createState() => _BoardMembersSectionState();
}

class _BoardMembersSectionState extends State<BoardMembersSection> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Members list - always visible, horizontally scrollable with add button
          SizedBox(
            height: 80,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...widget.memberIds.map((uid) {
                      final role = widget.board.memberRoles[uid] ?? 'member';
                      final isManager = uid == widget.board.boardManagerId;
                      final isCurrentUserManager =
                          widget.currentUserId == widget.board.boardManagerId;

                      return FutureBuilder<Map<String, String?>>(
                        future: _fetchUserData(uid),
                        builder: (context, snapshot) {
                          final data = snapshot.data;
                          final name = data?['name'] ?? "Loading...";
                          final picUrl = data?['picUrl'];

                          return Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    InkWell(
                                      onTap:
                                          () => _showMemberProfile(
                                            context,
                                            uid,
                                            role,
                                            isManager,
                                            isCurrentUserManager,
                                          ),
                                      borderRadius: BorderRadius.circular(24),
                                      child: CircleAvatar(
                                        radius: 24,
                                        backgroundImage:
                                            picUrl != null
                                                ? NetworkImage(picUrl)
                                                : null,
                                        child:
                                            picUrl == null
                                                ? const Icon(Icons.person)
                                                : null,
                                      ),
                                    ),
                                    if (role == 'inspector')
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.visibility,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    if (isManager)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.star,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    name,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }),
                  // Add Member Button at the end (only for non-personal boards)
                  if (widget.board.boardTitle.toLowerCase() != 'personal')
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddMemberToBoardPage(
                                    board: widget.board,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey.shade400,
                                  width: 2,
                                  strokeAlign: BorderSide.strokeAlignOutside,
                                ),
                              ),
                              child: Icon(
                                Icons.add,
                                size: 24,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: 60,
                            child: Text(
                              "Add",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
            ),
          ),
      )],
      ),
    );
  }

  /// Combines name + profile picture fetch in a single future
  Future<Map<String, String?>> _fetchUserData(String uid) async {
    final name = await widget.getUserName(uid);
    final picUrl = await widget.getUserProfilePicture(uid);
    return {'name': name, 'picUrl': picUrl};
  }

  /// Show user profile dialog
  void _showMemberProfile(
    BuildContext context,
    String userId,
    String role,
    bool isManager,
    bool isCurrentUserManager,
  ) async {
    print('[DEBUG] _showMemberProfile called:');
    print('  - userId: $userId');
    print('  - role: $role');
    print('  - isManager: $isManager');
    print('  - isCurrentUserManager: $isCurrentUserManager');
    print('  - widget.currentUserId: ${widget.currentUserId}');
    
    try {
      // Fetch full user data
      final userService = UserService();
      final user = await userService.getUserById(userId);

      if (user == null || !context.mounted) return;

      print('[DEBUG] User fetched: ${user.userName}');
      print('[DEBUG] Should show manager actions: ${isCurrentUserManager && !isManager}');
      print('[DEBUG] Should show leave board: ${!isCurrentUserManager && userId == widget.currentUserId}');

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
                        Text(
                          user.userName,
                          style: const TextStyle(fontSize: 18),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '@${user.userHandle}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isManager
                                ? Colors.blue.shade50
                                : role == 'inspector'
                                ? Colors.orange.shade50
                                : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              isManager
                                  ? Colors.blue
                                  : role == 'inspector'
                                  ? Colors.orange
                                  : Colors.green,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isManager
                                ? Icons.star
                                : role == 'inspector'
                                ? Icons.visibility
                                : Icons.person,
                            size: 16,
                            color:
                                isManager
                                    ? Colors.blue
                                    : role == 'inspector'
                                    ? Colors.orange
                                    : Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isManager
                                ? 'Manager'
                                : role == 'inspector'
                                ? 'Inspector'
                                : 'Member',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color:
                                  isManager
                                      ? Colors.blue
                                      : role == 'inspector'
                                      ? Colors.orange
                                      : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (user.userBio != null && user.userBio!.isNotEmpty) ...[
                      const Text(
                        'Bio',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(user.userBio!),
                      const SizedBox(height: 16),
                    ],
                    if (user.userSkills.isNotEmpty) ...[
                      const Text(
                        'Skills',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            user.userSkills.map((skill) {
                              return Chip(
                                label: Text(skill),
                                backgroundColor: Colors.blue.shade50,
                                labelStyle: const TextStyle(fontSize: 12),
                              );
                            }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                // Action buttons for managers
                if (isCurrentUserManager && !isManager) ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Get provider references BEFORE closing dialog
                      final boardProvider = context.read<BoardProvider>();                      final navigator = Navigator.of(context);
                      
                      navigator.pop();
                      await _changeUserRole(context, userId, role, user.userName, boardProvider);
                    },
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: Text(
                      'Change to ${role == 'inspector' ? 'Member' : 'Inspector'}',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      print('[DEBUG] Kick button pressed for user: ${user.userName}');
                      
                      // Show confirmation dialog BEFORE closing profile dialog
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Remove Member'),
                          content: Text(
                            'Are you sure you want to remove ${user.userName} from this board?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );

                      print('[DEBUG] Confirmation returned: $confirmed');
                      
                      if (confirmed != true) return;
                      
                      // Get provider references BEFORE closing profile dialog
                      final boardProvider = context.read<BoardProvider>();
                      final navigator = Navigator.of(context);
                      
                      // Close profile dialog
                      navigator.pop();
                      print('[DEBUG] Profile dialog closed, executing kick');
                      
                      // Execute kick operation
                      try {
                        final boardService = BoardService();
                        await boardService.kickMember(
                          boardId: widget.board.boardId,
                          memberIdToKick: userId,
                          memberName: user.userName,
                        );
                        print('[DEBUG] Member kicked successfully');

                        if (context.mounted) {
                          boardProvider.refreshBoards();
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${user.userName} has been removed from the board'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          setState(() {});
                        }
                      } catch (e) {
                        print('[ERROR] Failed to kick member: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to remove member: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.person_remove, size: 18),
                    label: const Text('Kick'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
                // Leave board button for non-managers
                if (!isCurrentUserManager && userId == widget.currentUserId)
                  ElevatedButton.icon(
                    onPressed: () async {
                      print('[DEBUG] Leave Board button pressed for user: ${user.userName}');
                      // Show confirmation dialog
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Leave Board'),
                          content: Text('Are you sure you want to leave this board?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Leave'),
                            ),
                          ],
                        ),
                      );
                      print('[DEBUG] Leave confirmation returned: $confirmed');
                      if (confirmed != true) return;
                      final boardProvider = context.read<BoardProvider>();
                      final navigator = Navigator.of(context);
                      print('[DEBUG] Executing leave (will close profile after operation)');
                      try {
                        final boardService = BoardService();
                        await boardService.leaveBoard(
                          boardId: widget.board.boardId,
                        );
                        print('[DEBUG] Member left board successfully');

                        // Close profile dialog AFTER successful leave
                        if (navigator.canPop()) navigator.pop();

                        if (context.mounted) {
                          boardProvider.refreshBoards();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('You have left the board'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          setState(() {});
                        }
                      } catch (e) {
                        print('[ERROR] Failed to leave board: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to leave board: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.exit_to_app, size: 18),
                    label: const Text('Leave Board'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load user profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changeUserRole(
    BuildContext context,
    String userId,
    String currentRole,
    String memberName,
    BoardProvider boardProvider,
  ) async {
    try {
      final newRole = currentRole == 'inspector' ? 'member' : 'inspector';

      // If trying to set as inspector, check if another inspector exists
      if (newRole == 'inspector') {
        final existingInspector = widget.board.memberRoles.entries.firstWhere(
          (entry) => entry.value == 'inspector' && entry.key != userId,
          orElse: () => const MapEntry('', ''),
        );

        if (existingInspector.key.isNotEmpty) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Only one inspector is allowed per board. Remove the current inspector first.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      final boardService = BoardService();

      // Update memberRoles map
      final updatedRoles = Map<String, String>.from(widget.board.memberRoles);
      updatedRoles[userId] = newRole;

      await boardService.updateBoard(
        widget.board.boardId,
        memberRoles: updatedRoles,
      );

      // Refresh board data first using passed provider
      boardProvider.refreshBoards();

      if (context.mounted) {
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Member role changed to ${newRole == 'inspector' ? 'Inspector' : 'Member'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the UI
        setState(() {});
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _kickMember(
    BuildContext context,
    String memberIdToKick,
    String memberName,
  ) async {
    print('[DEBUG] _kickMember called - memberName: $memberName, memberId: $memberIdToKick');
    
    // Show confirmation dialog
    print('[DEBUG] Showing kick confirmation dialog');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
          'Are you sure you want to remove $memberName from this board?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    print('[DEBUG] Dialog returned: confirmed=$confirmed, context.mounted=${context.mounted}');
    
    if (confirmed != true || !context.mounted) return;

    try {
      final boardService = BoardService();
      await boardService.kickMember(
        boardId: widget.board.boardId,
        memberIdToKick: memberIdToKick,
        memberName: memberName,
      );
      print('[DEBUG] Member kicked successfully');

      if (context.mounted) {
        // Refresh board data
        context.read<BoardProvider>().refreshBoards();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$memberName has been removed from the board'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      print('[ERROR] Failed to kick member: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove member: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveBoard(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Board'),
        content: const Text(
          'Are you sure you want to leave this board? You will need to be re-invited to rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final boardService = BoardService();
      await boardService.leaveBoard(
        boardId: widget.board.boardId,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have left the board'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate back to boards page
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave board: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
