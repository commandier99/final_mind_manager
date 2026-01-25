import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../datasources/models/task_model.dart';
import '../../datasources/providers/task_provider.dart';
import '../../../../shared/presentation/widgets/app_top_bar.dart';
import '../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../../shared/features/users/datasources/models/user_model.dart';
import '../../../../shared/features/users/datasources/services/user_services.dart';
import '../../../boards/datasources/providers/board_provider.dart';

class TaskApplicationsPage extends StatefulWidget {
  final Task task;

  const TaskApplicationsPage({super.key, required this.task});

  @override
  State<TaskApplicationsPage> createState() => _TaskApplicationsPageState();
}

class _TaskApplicationsPageState extends State<TaskApplicationsPage> {
  Map<String, UserModel?> _interestedUsers = {};
  Map<String, Map<String, dynamic>> _appeals = {}; // Map of userId -> appeal data

  @override
  void initState() {
    super.initState();
    _loadInterestedUsers();
    _loadAppeals();
  }

  Future<void> _loadAppeals() async {
    try {
      final appealsSnapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(widget.task.taskId)
          .collection('appeals')
          .get();
      
      final appeals = <String, Map<String, dynamic>>{};
      for (var doc in appealsSnapshot.docs) {
        final data = doc.data();
        appeals[data['userId']] = data;
      }
      
      setState(() {
        _appeals = appeals;
      });
    } catch (e) {
      print('Error loading appeals: $e');
    }
  }

  Future<void> _loadInterestedUsers() async {
    final userService = UserService();
    
    final interested = <String, UserModel?>{};
    for (var userId in widget.task.taskHelpers) {
      try {
        final user = await userService.getUserById(userId);
        interested[userId] = user;
      } catch (e) {
        print('Error loading user $userId: $e');
        interested[userId] = null;
      }
    }
    
    setState(() {
      _interestedUsers = interested;
    });
  }

  Future<void> _assignToMember(String? userId, String? userName) async {
    if (userId == null || userName == null) return;
    
    final taskProvider = context.read<TaskProvider>();
    
    try {
      // Update task to assign to this member
      final updatedTask = widget.task.copyWith(
        taskAssignedTo: userId,
        taskAssignedToName: userName,
      );
      
      await taskProvider.updateTask(updatedTask);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Task assigned to $userName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        // Pop back to task details
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error assigning task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeInterest(String userId) async {
    final taskProvider = context.read<TaskProvider>();
    
    try {
      final updatedHelpers = widget.task.taskHelpers
          .where((id) => id != userId)
          .toList();
      
      final updatedTask = widget.task.copyWith(
        taskHelpers: updatedHelpers,
      );
      
      await taskProvider.updateTask(updatedTask);
      
      if (mounted) {
        setState(() {
          _interestedUsers.remove(userId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed interest'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Error removing interest: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatAppealDate(dynamic timestamp) {
    try {
      if (timestamp == null) return 'Unknown date';
      
      // If it's a Firestore Timestamp
      if (timestamp.runtimeType.toString().contains('Timestamp')) {
        final dateTime = timestamp.toDate();
        final now = DateTime.now();
        final difference = now.difference(dateTime);
        
        if (difference.inMinutes < 1) {
          return 'Just now';
        } else if (difference.inHours < 1) {
          return '${difference.inMinutes}m ago';
        } else if (difference.inDays < 1) {
          return '${difference.inHours}h ago';
        } else if (difference.inDays < 7) {
          return '${difference.inDays}d ago';
        } else {
          return '${dateTime.month}/${dateTime.day}/${dateTime.year}';
        }
      }
      
      return 'Unknown date';
    } catch (e) {
      return 'Unknown date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: 'Task Applications',
        showBackButton: true,
        onBackPressed: () => Navigator.pop(context),
        showNotificationButton: false,
      ),
      body: widget.task.taskHelpers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_add_disabled,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No applications yet',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Members will appear here when they express interest',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Task: ${widget.task.taskTitle}',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.task.taskHelpers.length} member(s) interested',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                ..._interestedUsers.entries.map((entry) {
                  final userId = entry.key;
                  final user = entry.value;
                  final userName = user?.userName ?? 'Unknown User';
                  
                  // Get the appeal for this user
                  final appealData = _appeals[userId];
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // User avatar
                              if ((user?.userProfilePicture?.isNotEmpty ?? false))
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage: NetworkImage(
                                    user!.userProfilePicture!,
                                  ),
                                )
                              else
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.blue.shade100,
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.blue,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if ((user?.userEmail?.isNotEmpty ?? false))
                                      Text(
                                        user!.userEmail,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // Appeal section
                          if (appealData != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Appeal',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    appealData['appealText'] ?? '',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatAppealDate(appealData['createdAt']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 12),
                            Text(
                              'No appeal submitted',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _assignToMember(userId, userName),
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
                                onPressed: () => _removeInterest(userId),
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
                }).toList(),
              ],
            ),
    );
  }
}
