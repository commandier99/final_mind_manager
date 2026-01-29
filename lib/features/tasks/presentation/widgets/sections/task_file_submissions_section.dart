import 'package:flutter/material.dart';
import 'package:mind_manager_final/features/boards/datasources/models/board_model.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../datasources/models/task_model.dart';
import '../../../datasources/models/task_submission_model.dart';
import '../../../datasources/services/task_submission_service.dart';
import '../../../datasources/providers/upload_progress_provider.dart';
import '../../../../../shared/features/users/datasources/providers/user_provider.dart';
import '../../../../boards/datasources/providers/board_provider.dart';

class TaskFileSubmissionsSection extends StatefulWidget {
  final Task task;

  const TaskFileSubmissionsSection({super.key, required this.task});

  @override
  State<TaskFileSubmissionsSection> createState() =>
      _TaskFileSubmissionsSectionState();
}

class _TaskFileSubmissionsSectionState
    extends State<TaskFileSubmissionsSection> {
  final TaskSubmissionService _submissionService = TaskSubmissionService();

  @override
  void dispose() {
    // Upload continues in background even after dispose
    print('🗑️ [FileSubmissions] Widget disposed, upload continues in background');
    super.dispose();
  }

  Future<void> _pickAndUploadFiles() async {
    try {
      // Check current storage usage before opening file picker
      const int maxBytes = 100 * 1024 * 1024; // 100 MB
      final int existingBytes = await _submissionService.getTotalBytesForTask(widget.task.taskId);
      
      if (existingBytes >= maxBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task storage limit reached. Cannot upload more files.'),
              backgroundColor: Color(0xFF9C88D4),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      print('📁 [FilePicker] Opening file picker...');

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: true, // IMPORTANT: Load file bytes
      );

      print('📁 [FilePicker] Picker closed');
      print('📁 [FilePicker] Result is null: ${result == null}');

      if (result != null && result.files.isNotEmpty) {
        print('📁 [FilePicker] Files selected: ${result.files.length}');

        for (int i = 0; i < result.files.length; i++) {
          final file = result.files[i];
          print('📁 [FilePicker] File ${i + 1}: ${file.name}');
          print('📁 [FilePicker] - Size: ${file.size}');
          print('📁 [FilePicker] - Path: ${file.path}');
          print('📁 [FilePicker] - Has bytes: ${file.bytes != null}');
          print('📁 [FilePicker] - Extension: ${file.extension}');
        }

        // Enforce max 100MB per task capacity (existing + new)
        const int maxBytes = 100 * 1024 * 1024; // 100 MB
        final int existingBytes = await _submissionService.getTotalBytesForTask(widget.task.taskId);
        final int newBytes = result.files.fold<int>(0, (sum, f) => sum + (f.size));
        final int totalAfterUpload = existingBytes + newBytes;

        if (totalAfterUpload > maxBytes) {
          final usedMb = (existingBytes / (1024 * 1024)).toStringAsFixed(1);
          final newMb = (newBytes / (1024 * 1024)).toStringAsFixed(1);
          final limitMb = (maxBytes / (1024 * 1024)).toStringAsFixed(0);
          final remainingBytes = maxBytes - existingBytes;
          final remainingMb = (remainingBytes / (1024 * 1024)).clamp(0, 100).toStringAsFixed(1);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Task storage limit ${limitMb}MB exceeded. Used: ${usedMb}MB, New: ${newMb}MB, Remaining: ${remainingMb}MB.'),
                backgroundColor: const Color(0xFF9C88D4),
              ),
            );
          }
          return;
        }

        // Start background upload - doesn't await, continues in background
        final uploadProgressProvider = context.read<UploadProgressProvider>();
        
        _submissionService.createSubmission(
          taskId: widget.task.taskId,
          files: result.files,
          onProgress: (submissionId, currentFile, totalFiles, fileName, progress) {
            uploadProgressProvider.updateProgress(
              submissionId: submissionId,
              fileName: fileName,
              currentFile: currentFile,
              totalFiles: totalFiles,
              progress: progress,
            );
          },
        ).then((submissionId) {
          print('✅ [Upload] Background upload completed for task ${widget.task.taskId}');
          uploadProgressProvider.clearProgress(submissionId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Files uploaded successfully!'),
                backgroundColor: Color(0xFF66BB6A),
              ),
            );
          } else {
            // Widget disposed during upload, but upload completed in background
            print('🗑️ [Upload] Widget disposed, upload completed in background');
          }
        }).catchError((e) {
          print('❌ [Upload] Background upload failed: $e');
          final uploadProgressProvider = context.read<UploadProgressProvider>();
          // Clear all active uploads on error
          for (final submissionId in uploadProgressProvider.uploads.keys.toList()) {
            uploadProgressProvider.clearProgress(submissionId);
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error uploading files: $e'),
                backgroundColor: const Color(0xFF9C88D4),
              ),
            );
          } else {
            // Widget disposed during error handling
            print('🗑️ [Upload] Widget disposed during error handling');
          }
        });
      } else {
        // User cancelled picker without selecting files
        print('📁 [FilePicker] No files selected or result is null');
      }
    } catch (e) {
      print('❌ [FilePicker] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFF9C88D4),
          ),
        );
      }
    }
  }

  bool _canUploadFiles() {
    final userProvider = context.read<UserProvider>();
    final currentUserId = userProvider.userId ?? '';

    // Task owner can upload
    if (widget.task.taskOwnerId == currentUserId) return true;

    // Assigned member can upload
    if (widget.task.taskAssignedTo == currentUserId) return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final canUpload = _canUploadFiles();

    print('🔍 [FileSubmissions] Building for task: ${widget.task.taskId}');
    print('🔍 [FileSubmissions] Can upload: $canUpload');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show persistent upload progress for all active uploads
          Consumer<UploadProgressProvider>(
            builder: (context, uploadProgress, _) {
              if (!uploadProgress.isUploading) {
                return const SizedBox.shrink();
              }
              return Column(
                children: uploadProgress.uploads.entries.map((entry) {
                  final upload = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Uploading...',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    upload.fileName,
                                    style: Theme.of(context).textTheme.bodySmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${(upload.fileProgress * 100).toStringAsFixed(0)}%',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: upload.fileProgress,
                        minHeight: 4,
                        backgroundColor: Colors.blue.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                      ),
                    ),
                  ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          
          // Section header
          Text(
            'File Submissions',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Prominent upload button
          if (canUpload)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickAndUploadFiles,
                icon: const Icon(Icons.attach_file, size: 24),
                label: const Text(
                  'Attach Files',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  backgroundColor: const Color(0xFF5B9BD5),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Only the task owner or assigned member can attach files.',
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          if (canUpload) const SizedBox(height: 16),

          // Submissions list
          StreamBuilder<List<TaskSubmission>>(
            stream: _submissionService.streamSubmissionsForTask(
              widget.task.taskId,
            ),
            builder: (context, snapshot) {
              print(
                '🔍 [FileSubmissions] StreamBuilder state: ${snapshot.connectionState}',
              );
              print('🔍 [FileSubmissions] Has error: ${snapshot.hasError}');
              print('🔍 [FileSubmissions] Error: ${snapshot.error}');
              print('🔍 [FileSubmissions] Has data: ${snapshot.hasData}');
              print(
                '🔍 [FileSubmissions] Data length: ${snapshot.data?.length ?? 0}',
              );

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Error loading submissions: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }

              final submissions = snapshot.data ?? [];

              print(
                '🔍 [FileSubmissions] Submissions count: ${submissions.length}',
              );
              if (submissions.isNotEmpty) {
                print(
                  '🔍 [FileSubmissions] First submission has ${submissions[0].files.length} files',
                );
              }

              // Compute storage usage
              const int maxBytes = 100 * 1024 * 1024; // 100MB
              int usedBytes = 0;
              for (final s in submissions) {
                for (final f in s.files) {
                  print('📊 [Storage] File: ${f.fileName}, Size: ${f.fileSize} bytes');
                  usedBytes += f.fileSize;
                }
              }
              print('📊 [Storage] Total used bytes: $usedBytes');
              print('📊 [Storage] Max bytes: $maxBytes');
              final double progress = (usedBytes / maxBytes).clamp(0.0, 1.0);
              final String usedMb = (usedBytes / (1024 * 1024)).toStringAsFixed(1);
              final String remainingMb = ((maxBytes - usedBytes) / (1024 * 1024)).clamp(0, 100).toStringAsFixed(1);
              print('📊 [Storage] Progress: $progress');
              print('📊 [Storage] Used MB: $usedMb');
              print('📊 [Storage] Remaining MB: $remainingMb');

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Storage usage header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Storage Used: $usedMb MB of 100 MB',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[800],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Remaining: $remainingMb MB',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress < 0.7
                                  ? const Color(0xFF66BB6A) // green
                                  : (progress < 0.9
                                      ? const Color(0xFFFFA726) // orange
                                      : const Color(0xFFEF5350)), // red
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (submissions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No file submissions yet',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (canUpload) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Upload files to submit your work',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: submissions.length,
                      itemBuilder: (context, index) {
                        final submission = submissions[index];
                        return _buildSubmissionCard(submission);
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionCard(TaskSubmission submission) {
    Color statusColor;
    IconData statusIcon;

    switch (submission.status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'revision_requested':
        statusColor = Colors.orange;
        statusIcon = Icons.edit;
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.pending;
    }

    final userProvider = context.read<UserProvider>();
    final currentUserId = userProvider.userId ?? '';
    final canDelete = _canDeleteSubmission(submission, currentUserId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Submission ${submission.submittedAt.toString().split('.')[0]}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    submission.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                if (canDelete) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Delete submission',
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () => _confirmDeleteSubmission(submission),
                  ),
                ],
              ],
            ),
            if (submission.feedback != null && submission.feedback!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Feedback:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        submission.feedback!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Files:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ...submission.files.map(
              (file) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _downloadFile(file),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              _getFileIcon(file.fileType),
                              size: 18,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                file.fileName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatFileSize(file.fileSize),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.download,
                              size: 16,
                              color: Colors.blue,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canDeleteSubmission(TaskSubmission submission, String currentUserId) {
    // Allow delete if user is the submitter, task owner or assignee
    if (submission.submittedBy == currentUserId) return true;
    if (widget.task.taskOwnerId == currentUserId) return true;
    if (widget.task.taskAssignedTo == currentUserId) return true;

    // Board manager can also delete
    if (widget.task.taskBoardId.isNotEmpty) {
      final boardProvider = context.read<BoardProvider>();
      final boards = boardProvider.boards;
      Board? board;
      for (final b in boards) {
        if (b.boardId == widget.task.taskBoardId) {
          board = b;
          break;
        }
      }
      if (board != null && board.boardManagerId == currentUserId) return true;
    }
    return false;
  }

  Future<void> _confirmDeleteSubmission(TaskSubmission submission) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Submission'),
        content: const Text('Are you sure you want to delete this submission? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _submissionService.deleteSubmission(submission.submissionId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Submission deleted.'),
              backgroundColor: Color(0xFF66BB6A),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting submission: $e'),
              backgroundColor: const Color(0xFF9C88D4),
            ),
          );
        }
      }
    }
  }

  IconData _getFileIcon(String type) {
    if (type.contains('image')) return Icons.image;
    if (type.contains('pdf')) return Icons.picture_as_pdf;
    if (type.contains('video')) return Icons.video_file;
    if (type.contains('audio')) return Icons.audio_file;
    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _downloadFile(SubmissionFile file) async {
    print('🔵 Download button tapped!');
    print('📥 File name: ${file.fileName}');
    print('📥 File URL: ${file.fileUrl}');

    try {
      final url = Uri.parse(file.fileUrl);
      print('📥 Parsed URL: $url');

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Text('Opening file...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      print('📥 Attempting to launch URL...');

      // Try different launch modes
      bool launched = false;

      // Try mode 1: External application
      try {
        launched = await launchUrl(url, mode: LaunchMode.externalApplication);
        print('✅ External application mode: $launched');
      } catch (e) {
        print('❌ External application failed: $e');
      }

      // Try mode 2: Platform default
      if (!launched) {
        try {
          launched = await launchUrl(url, mode: LaunchMode.platformDefault);
          print('✅ Platform default mode: $launched');
        } catch (e) {
          print('❌ Platform default failed: $e');
        }
      }

      // Try mode 3: External non-browser
      if (!launched) {
        try {
          launched = await launchUrl(
            url,
            mode: LaunchMode.externalNonBrowserApplication,
          );
          print('✅ External non-browser mode: $launched');
        } catch (e) {
          print('❌ External non-browser failed: $e');
        }
      }

      if (!launched) {
        throw 'Could not open file URL with any launch mode';
      }

      print('✅ File opened successfully');
    } catch (e) {
      print('❌ Error downloading file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open file: $e\n\nURL: ${file.fileUrl}'),
            backgroundColor: const Color(0xFF9C88D4),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'COPY URL',
              textColor: Colors.white,
              onPressed: () {
                // User can manually copy and open
                print('Copy this URL: ${file.fileUrl}');
              },
            ),
          ),
        );
      }
    }
  }
}
