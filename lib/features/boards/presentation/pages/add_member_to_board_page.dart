import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../datasources/models/board_model.dart';
import '../../datasources/models/board_roles.dart';
import '../../datasources/providers/board_provider.dart';
import '../../../notifications/datasources/models/notification_model.dart';
import '../../../notifications/datasources/providers/notification_provider.dart';
import '../../../thoughts/datasources/models/thought_model.dart';
import '../../../thoughts/datasources/providers/thought_provider.dart';
import '../../../../shared/features/search/providers/search_provider.dart';
import '../../../../shared/features/users/datasources/models/user_model.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import 'package:uuid/uuid.dart';

class AddMemberToBoardPage extends StatefulWidget {
  final Board board;

  const AddMemberToBoardPage({super.key, required this.board});

  @override
  State<AddMemberToBoardPage> createState() => _AddMemberToBoardPageState();
}

class _AddMemberToBoardPageState extends State<AddMemberToBoardPage> {
  final Uuid _uuid = const Uuid();
  final TextEditingController _searchController = TextEditingController();
  SearchProvider? _searchProvider;
  final Set<String> _sendingInviteUserIds = <String>{};
  final Set<String> _pendingInviteUserIds = <String>{};

  bool get _canAddMembersToThisBoard {
    return widget.board.boardType == 'team';
  }

  @override
  void initState() {
    super.initState();
    // Start streaming all discoverable users on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SearchProvider>().streamDiscoverableUsers();
      _loadPendingInvites();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _searchProvider = context.read<SearchProvider>();
  }

  @override
  void dispose() {
    _searchProvider?.stopStreamingUsers();
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
      appBar: AppBar(
        title: Text('Add Member to ${widget.board.boardTitle}'),
        elevation: 0,
      ),
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
                suffixIcon: _searchController.text.isNotEmpty
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
    if (!_canAddMembersToThisBoard) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 52, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Members are disabled for this board type.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Switch this board type to Team to invite members.',
                style: TextStyle(color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

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
    final isAlreadyMember = widget.board.memberIds.contains(user.userId);
    final isSendingInvite = _sendingInviteUserIds.contains(user.userId);
    final hasPendingInvite = _pendingInviteUserIds.contains(user.userId);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Profile Picture
            CircleAvatar(
              radius: 28,
              backgroundImage: user.userProfilePicture != null
                  ? NetworkImage(user.userProfilePicture!)
                  : null,
              child: user.userProfilePicture == null
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
                      children: user.userSkills.take(3).map((skill) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
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
            // Add/Member Button
            if (isAlreadyMember)
              Chip(
                label: const Text('Member'),
                backgroundColor: Colors.grey.shade300,
              )
            else
              ElevatedButton.icon(
                icon: Icon(
                  isSendingInvite
                      ? Icons.hourglass_top
                      : (hasPendingInvite
                            ? Icons.check_circle_outline
                            : Icons.mail_outline),
                ),
                label: Text(
                  isSendingInvite
                      ? 'Sending...'
                      : (hasPendingInvite ? 'Sent' : 'Invite'),
                ),
                onPressed: isSendingInvite || hasPendingInvite
                    ? null
                    : () => _handleAddMember(user),
              ),
          ],
        ),
      ),
    );
  }

  void _handleAddMember(UserModel user) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final currentUser = context.read<UserProvider>().currentUser;
    final thoughtProvider = context.read<ThoughtProvider>();
    final notificationProvider = context.read<NotificationProvider>();

    if (!_canAddMembersToThisBoard) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Only Team boards can add members.')),
      );
      return;
    }

    // Check if user is already a member
    if (widget.board.memberIds.contains(user.userId)) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('User is already a member of this board'),
        ),
      );
      return;
    }

    if (currentUser == null) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('No signed-in user found.')),
      );
      return;
    }

    final boardProvider = context.read<BoardProvider>();
    final selectedRole = await _showInviteRoleSheet(user);
    if (!mounted || selectedRole == null) return;

    setState(() {
      _sendingInviteUserIds.add(user.userId);
    });

    try {
      final now = DateTime.now();
      final authorName = currentUser.userName.trim().isEmpty
          ? 'Unknown'
          : currentUser.userName.trim();
      final roleLabel = selectedRole == BoardRoles.supervisor
          ? 'Supervisor'
          : 'Member';
      final rolePhrase = selectedRole == BoardRoles.supervisor
          ? 'a Supervisor'
          : 'a Member';
      final notificationSeed = _uuid.v4();

      final thought = Thought(
        thoughtId: '',
        type: Thought.typeBoardRequest,
        status: Thought.statusPending,
        scopeType: Thought.scopeBoard,
        boardId: widget.board.boardId,
        taskId: '',
        authorId: currentUser.userId,
        authorName: authorName,
        targetUserId: user.userId,
        targetUserName: user.userName,
        title: 'Board Invite: ${widget.board.boardTitle}',
        message:
            '$authorName invited ${user.userName} to join ${widget.board.boardTitle} as $rolePhrase.',
        createdAt: now,
        updatedAt: now,
        metadata: {
          'source': 'add_member_to_board_page',
          'boardTitle': widget.board.boardTitle,
          'requestDirection': 'invite_member',
          'invitedMemberId': user.userId,
          'invitedMemberName': user.userName,
          'invitedMemberHandle': user.userHandle,
          'invitedRole': selectedRole,
          'notificationSeed': notificationSeed,
        },
      );

      final thoughtId = await thoughtProvider.createThought(thought);
      await boardProvider.markPendingBoardInvite(
        boardId: widget.board.boardId,
        userId: user.userId,
        invitationThoughtId: thoughtId,
      );
      try {
        await notificationProvider.createNotifications([
          AppNotification(
            notificationId: '',
            recipientUserId: currentUser.userId,
            title: 'Board Invite Sent',
            message:
                'You invited ${user.userName} to join ${widget.board.boardTitle}.',
            type: 'thought_board_invite_sent',
            deliveryStatus: AppNotification.deliveryPending,
            isRead: false,
            isDeleted: false,
            createdAt: now,
            updatedAt: now,
            actorUserId: currentUser.userId,
            actorUserName: authorName,
            thoughtId: thoughtId,
            eventKey:
                '$notificationSeed:${currentUser.userId}:thought_board_invite_sent',
            metadata: {
              'role': selectedRole,
              'thoughtType': Thought.typeBoardRequest,
              'requestDirection': 'invite_member',
            },
          ),
          AppNotification(
            notificationId: '',
            recipientUserId: user.userId,
            title: 'Board Invite Received',
            message:
                '$authorName invited you to join ${widget.board.boardTitle} as $rolePhrase.',
            type: 'thought_board_invite_received',
            deliveryStatus: AppNotification.deliveryPending,
            isRead: false,
            isDeleted: false,
            createdAt: now,
            updatedAt: now,
            actorUserId: currentUser.userId,
            actorUserName: authorName,
            thoughtId: thoughtId,
            eventKey:
                '$notificationSeed:${user.userId}:thought_board_invite_received',
            metadata: {
              'role': selectedRole,
              'thoughtType': Thought.typeBoardRequest,
              'requestDirection': 'invite_member',
            },
          ),
        ]);
      } catch (e) {
        await _rollbackInviteThought(
          boardProvider: boardProvider,
          boardId: widget.board.boardId,
          userId: user.userId,
          thoughtProvider: thoughtProvider,
          thoughtId: thoughtId,
        );
        throw Exception(
          'Invite notifications could not be created, so the invite was cancelled. $e',
        );
      }

      if (!mounted) return;
      setState(() {
        _pendingInviteUserIds.add(user.userId);
      });
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'Invitation sent to ${user.userName} as $roleLabel.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text('Failed to send invitation: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingInviteUserIds.remove(user.userId);
        });
      }
    }
  }

  Future<void> _rollbackInviteThought({
    required BoardProvider boardProvider,
    required String boardId,
    required String userId,
    required ThoughtProvider thoughtProvider,
    required String thoughtId,
  }) async {
    try {
      await boardProvider.clearPendingBoardInvite(
        boardId: boardId,
        userId: userId,
      );
    } catch (_) {
      // Best effort rollback. The original notification failure is still surfaced.
    }

    try {
      await thoughtProvider.softDeleteThought(thoughtId);
    } catch (_) {
      // Best effort rollback. The original notification failure is still surfaced.
    }
  }

  Future<void> _loadPendingInvites() async {
    try {
      final pendingIds = await context
          .read<ThoughtProvider>()
          .getPendingBoardInviteTargetUserIds(widget.board.boardId);
      if (!mounted) return;
      setState(() {
        _pendingInviteUserIds
          ..clear()
          ..addAll(pendingIds);
      });
    } catch (_) {
      // Best effort only; the page can still send invites without preload state.
    }
  }

  Future<String?> _showInviteRoleSheet(UserModel user) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        String selectedRole = BoardRoles.member;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invite ${user.userName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose what role this user should get if they accept the board invite.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment<String>(
                          value: BoardRoles.member,
                          label: Text('Member'),
                          icon: Icon(Icons.person_outline),
                        ),
                        ButtonSegment<String>(
                          value: BoardRoles.supervisor,
                          label: Text('Supervisor'),
                          icon: Icon(Icons.shield_outlined),
                        ),
                      ],
                      selected: {selectedRole},
                      onSelectionChanged: (selection) {
                        if (selection.isEmpty) return;
                        final nextRole = selection.first;
                        setSheetState(() {
                          selectedRole = nextRole;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      selectedRole == BoardRoles.supervisor
                          ? 'Supervisor can help oversee work on the board.'
                          : 'Member gets standard board access.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(selectedRole),
                          child: const Text('Send Invite'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
