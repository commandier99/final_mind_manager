import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../datasources/models/task_model.dart';
import '../../datasources/providers/task_provider.dart';
import '../../../../shared/presentation/widgets/app_top_bar.dart';
import '../../../../shared/features/users/datasources/models/user_model.dart';
import '../../../../shared/features/users/datasources/services/user_services.dart';

class TaskApplicationsPage extends StatelessWidget {
  final Task task;

  const TaskApplicationsPage({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final appealsStream = FirebaseFirestore.instance
        .collection('tasks')
        .doc(task.taskId)
        .collection('appeals')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppTopBar(
        title: 'Task Applications',
        showBackButton: true,
        onBackPressed: () => Navigator.pop(context),
        showNotificationButton: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: appealsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final appeals = snapshot.data!.docs;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Task: ${task.taskTitle}',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                '${appeals.length} member(s) interested',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),

              ...appeals.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final userId = data['userId'] as String?;
                final appealText = data['appealText'] ?? '';
                final createdAt = data['createdAt'];

                if (userId == null) return const SizedBox();

                return _ApplicationCard(
                  task: task,
                  appealDocId: doc.id,
                  userId: userId,
                  appealText: appealText,
                  createdAt: createdAt,
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_add_disabled, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No applications yet',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Members will appear here when they express interest',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatefulWidget {
  final Task task;
  final String appealDocId;
  final String userId;
  final String appealText;
  final dynamic createdAt;

  const _ApplicationCard({
    required this.task,
    required this.appealDocId,
    required this.userId,
    required this.appealText,
    required this.createdAt,
  });

  @override
  State<_ApplicationCard> createState() => _ApplicationCardState();
}

class _ApplicationCardState extends State<_ApplicationCard> {
  UserModel? user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final userService = UserService();
    final fetchedUser = await userService.getUserById(widget.userId);
    if (mounted) {
      setState(() => user = fetchedUser);
    }
  }

  Future<void> _assignToMember() async {
    if (user == null) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final taskProvider = context.read<TaskProvider>();

    final updatedTask = widget.task.copyWith(
      taskAssignedTo: widget.userId,
      taskAssignedToName: user!.userName,
    );

    await taskProvider.updateTask(updatedTask);

    if (!mounted) return;

    // Pop FIRST so this card is safely removed
    navigator.pop();

    // Show snackbar AFTER pop using root messenger
    messenger.showSnackBar(
      SnackBar(
        content: Text('✅ Task assigned to ${user!.userName}'),
        backgroundColor: Colors.green,
      ),
    );
  }


  Future<void> _decline() async {
    await FirebaseFirestore.instance
        .collection('tasks')
        .doc(widget.task.taskId)
        .collection('appeals')
        .doc(widget.appealDocId)
        .delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application removed')),
      );
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                user?.userProfilePicture?.isNotEmpty == true
                    ? CircleAvatar(
                        radius: 24,
                        backgroundImage:
                            NetworkImage(user!.userProfilePicture!),
                      )
                    : CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.blue.shade100,
                        child: const Icon(Icons.person, color: Colors.blue),
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    user?.userName ?? 'Loading...',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Application Message',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.appealText,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _formatDate(widget.createdAt),
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _assignToMember,
                    icon: const Icon(Icons.check),
                    label: const Text('Assign'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _decline,
                  icon: const Icon(Icons.close),
                  label: const Text('Decline'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
