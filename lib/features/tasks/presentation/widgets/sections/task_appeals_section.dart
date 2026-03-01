import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../datasources/models/task_model.dart';
import '../../../datasources/providers/task_provider.dart';
import '../../../datasources/services/task_appeal_service.dart';
import '../../../../../shared/features/users/datasources/models/user_model.dart';
import '../../../../../shared/features/users/datasources/services/user_services.dart';

class TaskAppealsSection extends StatelessWidget {
  final String taskId;

  const TaskAppealsSection({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, _) {
        Task? task;
        try {
          task = taskProvider.tasks.firstWhere((t) => t.taskId == taskId);
        } catch (_) {
          task = null;
        }

        if (task == null) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: TaskAppealService().streamAppeals(task.taskId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final appeals = snapshot.data?.docs ?? const [];
            if (appeals.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueGrey.shade100),
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blueGrey.shade50, Colors.white],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blueGrey.shade100),
                      ),
                      child: Icon(
                        Icons.inbox_outlined,
                        size: 18,
                        color: Colors.blueGrey.shade500,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No appeals submitted yet.\nNew appeals from members will show up here.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: Colors.blueGrey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: appeals.map((doc) {
                final data = doc.data();
                final userId = data['userId'] as String?;
                final appealText = (data['appealText'] ?? '').toString();
                final createdAt = data['createdAt'];

                if (userId == null) return const SizedBox.shrink();
                return _AppealCard(
                  task: task!,
                  appealDocId: doc.id,
                  userId: userId,
                  appealText: appealText,
                  createdAt: createdAt,
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _AppealCard extends StatefulWidget {
  final Task task;
  final String appealDocId;
  final String userId;
  final String appealText;
  final dynamic createdAt;

  const _AppealCard({
    required this.task,
    required this.appealDocId,
    required this.userId,
    required this.appealText,
    required this.createdAt,
  });

  @override
  State<_AppealCard> createState() => _AppealCardState();
}

class _AppealCardState extends State<_AppealCard> {
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await UserService().getUserById(widget.userId);
    if (!mounted) return;
    setState(() => _user = user);
  }

  Future<void> _assignToMember() async {
    if (_user == null) return;
    final taskProvider = context.read<TaskProvider>();
    final updatedTask = widget.task.copyWith(
      taskAssignedTo: widget.userId,
      taskAssignedToName: _user!.userName,
    );
    await taskProvider.updateTask(updatedTask);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task assigned to ${_user!.userName}.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _decline() async {
    await TaskAppealService().deleteAppeal(
      taskId: widget.task.taskId,
      appealDocId: widget.appealDocId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Appeal removed.')));
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue.shade100,
                backgroundImage:
                    (_user?.userProfilePicture?.isNotEmpty ?? false)
                    ? NetworkImage(_user!.userProfilePicture!)
                    : null,
                child: (_user?.userProfilePicture?.isNotEmpty ?? false)
                    ? null
                    : const Icon(Icons.person, size: 16, color: Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _user?.userName ?? 'Loading...',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _formatDate(widget.createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.appealText.trim().isEmpty
                ? 'No message provided.'
                : widget.appealText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _assignToMember,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Assign'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _decline,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Dismiss'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
