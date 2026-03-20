import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../shared/features/users/datasources/services/user_services.dart';
import '../../../datasources/models/board_model.dart';
import '../../../datasources/models/board_roles.dart';
import '../../../datasources/providers/board_provider.dart';
import '../../controllers/board_member_actions_controller.dart';
import '../../pages/add_member_to_board_page.dart';

class BoardMembersSection extends StatefulWidget {
  final List<String> memberIds;
  final String? currentUserId;
  final Board board;

  const BoardMembersSection({
    super.key,
    required this.memberIds,
    this.currentUserId,
    required this.board,
  });

  @override
  State<BoardMembersSection> createState() => _BoardMembersSectionState();
}

class _BoardMembersSectionState extends State<BoardMembersSection> {
  final UserService _userService = UserService();
  final BoardMemberActionsController _actionsController =
      BoardMemberActionsController();

  bool get _canAddMembersToThisBoard {
    return widget.board.boardType == 'team';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 80,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...widget.memberIds.map((uid) {
                    final role = BoardRoles.normalize(
                      widget.board.memberRoles[uid],
                    );
                    final isManager = uid == widget.board.boardManagerId;
                    final isCurrentUserManager =
                        widget.currentUserId == widget.board.boardManagerId;

                    return FutureBuilder<Map<String, String?>>(
                      future: _fetchUserData(uid),
                      builder: (context, snapshot) {
                        final data = snapshot.data;
                        final name = data?['name'] ?? 'Loading...';
                        final picUrl = data?['picUrl'];

                        return Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  InkWell(
                                    onTap: () => _showMemberProfile(
                                      context,
                                      uid,
                                      role,
                                      isManager,
                                      isCurrentUserManager,
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    child: CircleAvatar(
                                      radius: 24,
                                      backgroundImage: picUrl != null
                                          ? NetworkImage(picUrl)
                                          : null,
                                      child: picUrl == null
                                          ? const Icon(Icons.person)
                                          : null,
                                    ),
                                  ),
                                  if (role == BoardRoles.supervisor)
                                    _buildRoleBadge(
                                      color: Colors.orange,
                                      icon: Icons.visibility,
                                    ),
                                  if (isManager)
                                    _buildRoleBadge(
                                      color: Colors.blue,
                                      icon: Icons.star,
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
                  if (_canAddMembersToThisBoard &&
                      widget.currentUserId == widget.board.boardManagerId)
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
                                  builder: (context) =>
                                      AddMemberToBoardPage(board: widget.board),
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
                              'Invite',
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
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge({required Color color, required IconData icon}) {
    return Positioned(
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, size: 12, color: Colors.white),
      ),
    );
  }

  Future<Map<String, String?>> _fetchUserData(String uid) async {
    final user = await _userService.getUserById(uid);
    return {
      'name': user?.userName ?? 'Unknown User',
      'picUrl': user?.userProfilePicture,
    };
  }

  Future<void> _showMemberProfile(
    BuildContext context,
    String userId,
    String role,
    bool isManager,
    bool isCurrentUserManager,
  ) async {
    final user = await _userService.getUserById(userId);
    if (user == null || !context.mounted) return;

    final boardProvider = context.read<BoardProvider>();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: user.userProfilePicture != null
                  ? NetworkImage(user.userProfilePicture!)
                  : null,
              child: user.userProfilePicture == null
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
              _buildProfileRoleBadge(role: role, isManager: isManager),
              const SizedBox(height: 16),
              if (user.userBio != null && user.userBio!.isNotEmpty) ...[
                const Text(
                  'Bio',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(user.userBio!),
                const SizedBox(height: 16),
              ],
              if (user.userSkills.isNotEmpty) ...[
                const Text(
                  'Skills',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: user.userSkills
                      .map(
                        (skill) => Chip(
                          label: Text(skill),
                          backgroundColor: Colors.blue.shade50,
                          labelStyle: const TextStyle(fontSize: 12),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (isCurrentUserManager && !isManager) ...[
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                final result = await _actionsController.changeUserRole(
                  board: widget.board,
                  userId: userId,
                  currentRole: role,
                  boardProvider: boardProvider,
                );
                if (!mounted) return;
                _showResult(result);
              },
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: Text(
                'Change to ${role == BoardRoles.supervisor ? 'Member' : 'Supervisor'}',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
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
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );

                if (confirmed != true || !context.mounted) return;
                Navigator.pop(context);

                final result = await _actionsController.kickMember(
                  board: widget.board,
                  memberIdToKick: userId,
                  memberName: user.userName,
                  boardProvider: boardProvider,
                );

                if (!mounted) return;
                _showResult(result);
              },
              icon: const Icon(Icons.person_remove, size: 18),
              label: const Text('Kick'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
          if (!isCurrentUserManager && userId == widget.currentUserId)
            ElevatedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Leave Board'),
                    content: const Text(
                      'Are you sure you want to leave this board?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Leave'),
                      ),
                    ],
                  ),
                );

                if (confirmed != true || !context.mounted) return;
                Navigator.pop(context);

                final result = await _actionsController.leaveBoard(
                  board: widget.board,
                  boardProvider: boardProvider,
                );
                if (!mounted) return;
                _showResult(result);
                if (result.success && mounted && Navigator.of(this.context).canPop()) {
                  Navigator.of(this.context).pop();
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
  }

  Widget _buildProfileRoleBadge({
    required String role,
    required bool isManager,
  }) {
    final color = isManager
        ? Colors.blue
        : role == BoardRoles.supervisor
        ? Colors.orange
        : Colors.green;
    final icon = isManager
        ? Icons.star
        : role == BoardRoles.supervisor
        ? Icons.visibility
        : Icons.person;
    final label = isManager
        ? 'Manager'
        : role == BoardRoles.supervisor
        ? 'Supervisor'
        : 'Member';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showResult(BoardActionResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
    if (result.success) {
      setState(() {});
    }
  }
}
