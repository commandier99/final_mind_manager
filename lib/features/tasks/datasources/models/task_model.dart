import 'package:cloud_firestore/cloud_firestore.dart';
import 'task_stats_model.dart';

class Task {
  // Priority field
  final String taskId;
  final String taskBoardId;
  final String? taskBoardTitle;
  final String taskOwnerId;
  final String taskOwnerName;

  final String taskAssignedBy;
  final String taskAssignedTo;
  final String taskAssignedToName; // Display name of the person assigned to

  final String taskPriorityLevel; // e.g. 'Low', 'Medium', 'High'
  final DateTime taskCreatedAt;
  final DateTime? taskDeletedAt;
  final bool taskIsDeleted;
  final String taskTitle;
  final String taskDescription;

  final DateTime? taskDeadline;
  final bool taskDeadlineMissed; // Whether the deadline was missed
  final int taskExtensionCount; // How many times deadline was extended
  final DateTime? taskReminderSentAt; // When deadline reminder was sent (to prevent duplicates)

  final bool taskIsDone;
  final DateTime? taskIsDoneAt;

  final bool taskFailed; // Whether task was marked as failed by manager

  final TaskStats taskStats; // TaskStats model for task stats

  // Status field - tracks task workflow state (core statuses only)
  final String
  taskStatus; // e.g. 'To Do', 'In Progress', 'Paused', 'Completed'

  // Approval fields - optional, only used if task requires approval
  final bool taskRequiresApproval; // Whether this task needs approval
  final String? taskSubmissionId; // Reference to task submission if exists

  // Repeating Fields
  final bool taskIsRepeating; // Does the task repeat?
  final String? taskRepeatInterval; // Repeat interval (e.g., "daily", "weekly")
  final DateTime? taskRepeatEndDate; // End date for repeating
  final DateTime? taskNextRepeatDate; // Date for the next repeat
  final String? taskRepeatTime; // Time of day for repeat (HH:mm format, e.g., "14:30")

  // Acceptance status for assigned tasks
  final String?
  taskAcceptanceStatus; // 'pending', 'accepted', 'declined', null for self-assigned

  // Helper assignees when user requests help
  final List<String> taskHelpers; // List of user IDs who volunteered to help
  final Map<String, String> taskHelperNames; // Map of userId -> userName

  Task({
    required this.taskId,
    required this.taskBoardId,
    this.taskBoardTitle,
    required this.taskOwnerId,
    required this.taskOwnerName,
    required this.taskAssignedBy,
    required this.taskAssignedTo,
    required this.taskAssignedToName,
    this.taskPriorityLevel = 'Low',
    required this.taskCreatedAt,
    this.taskDeletedAt,
    this.taskIsDeleted = false,
    required this.taskTitle,
    required this.taskDescription,
    this.taskDeadline,
    this.taskDeadlineMissed = false,
    this.taskExtensionCount = 0,
    this.taskReminderSentAt,
    this.taskIsDone = false,
    this.taskIsDoneAt,
    this.taskFailed = false,
    required this.taskStats, // TaskStats passed as a parameter
    this.taskStatus = 'To Do',
    this.taskRequiresApproval = false,
    this.taskSubmissionId,
    this.taskIsRepeating = false,
    this.taskRepeatInterval,
    this.taskRepeatEndDate,
    this.taskNextRepeatDate,
    this.taskRepeatTime,
    this.taskAcceptanceStatus,
    this.taskHelpers = const [],
    this.taskHelperNames = const {},
  });

  // Helper to map legacy Firestore statuses to core statuses
  static String _mapStatusFromFirestore(String status) {
    switch (status.toUpperCase()) {
      case 'TODO':
      case 'TO DO':
        return 'To Do';
      case 'IN_PROGRESS':
      case 'IN PROGRESS':
        return 'In Progress';
      case 'ON_PAUSE':
      case 'PAUSED':
        return 'Paused';
      case 'COMPLETED':
        return 'COMPLETED';
      // Legacy states map to In Progress
      case 'IN_REVIEW':
      case 'UNDER_REVISION':
        return 'In Progress';
      default:
        return 'To Do';
    }
  }

  // Computed deadline state getters
  bool get isOverdue {
    if (taskIsDone || taskDeadline == null) return false;
    return DateTime.now().isAfter(taskDeadline!);
  }

  bool get isDueToday {
    if (taskIsDone || taskDeadline == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(taskDeadline!.year, taskDeadline!.month, taskDeadline!.day);
    return deadlineDay == today;
  }

  bool get isDueUpcoming {
    if (taskIsDone || taskDeadline == null || isOverdue || isDueToday) return false;
    return DateTime.now().isBefore(taskDeadline!);
  }

  // Factory to create Task from Firestore document
  factory Task.fromMap(Map<String, dynamic> data, String documentId) {
    return Task(
      taskId: documentId,
      taskBoardId: data['taskBoardId'] as String? ?? '',
      taskBoardTitle: data['taskBoardTitle'] as String?,
      taskOwnerId: data['taskOwnerId'] as String? ?? '',
      taskOwnerName: data['taskOwnerName'] as String? ?? 'Unknown',
      taskAssignedBy: data['taskAssignedBy'] as String? ?? 'None',
      taskAssignedTo: data['taskAssignedTo'] as String? ?? 'None',
      taskAssignedToName: data['taskAssignedToName'] as String? ?? 'Unknown',
      taskPriorityLevel: data['taskPriorityLevel'] as String? ?? 'Low',
      taskCreatedAt:
          (data['taskCreatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      taskDeletedAt: (data['taskDeletedAt'] as Timestamp?)?.toDate(),
      taskIsDeleted: data['taskIsDeleted'] as bool? ?? false,
      taskTitle: data['taskTitle'] as String? ?? 'Untitled Task',
      taskDescription: data['taskDescription'] as String? ?? '',
      taskDeadline: (data['taskDeadline'] as Timestamp?)?.toDate(),
      taskDeadlineMissed: data['taskDeadlineMissed'] as bool? ?? false,
      taskExtensionCount: data['taskExtensionCount'] as int? ?? 0,
      taskReminderSentAt: (data['taskReminderSentAt'] as Timestamp?)?.toDate(),
      taskIsDone: data['taskIsDone'] as bool? ?? false,
      taskIsDoneAt: (data['taskIsDoneAt'] as Timestamp?)?.toDate(),
      taskFailed: data['taskFailed'] as bool? ?? false,
      taskStats:
          data['taskStats'] != null
              ? TaskStats.fromMap(Map<String, dynamic>.from(data['taskStats']))
              : TaskStats(), // Fallback to empty TaskStats if null
      taskStatus: _mapStatusFromFirestore(data['taskStatus'] as String? ?? 'To Do'),
      taskRequiresApproval: data['taskRequiresApproval'] as bool? ?? false,
      taskSubmissionId: data['taskSubmissionId'] as String?,
      taskIsRepeating: data['taskIsRepeating'] as bool? ?? false,
      taskRepeatInterval: data['taskRepeatInterval'] as String?,
      taskRepeatEndDate: (data['taskRepeatEndDate'] as Timestamp?)?.toDate(),
      taskNextRepeatDate:
          (data['taskNextRepeatDate'] as Timestamp?)?.toDate(),
      taskRepeatTime: data['taskRepeatTime'] as String?,
      taskAcceptanceStatus: data['taskAcceptanceStatus'] as String?,
      taskHelpers:
          (data['taskHelpers'] as List<dynamic>?)?.cast<String>() ?? [],
      taskHelperNames:
          (data['taskHelperNames'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ??
          {},
    );
  }

  // Convert Task object to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'taskBoardId': taskBoardId,
      if (taskBoardTitle != null) 'taskBoardTitle': taskBoardTitle,
      'taskOwnerId': taskOwnerId,
      'taskOwnerName': taskOwnerName,
      'taskAssignedBy': taskAssignedBy,
      'taskAssignedTo': taskAssignedTo,
      'taskAssignedToName': taskAssignedToName,
      'taskPriorityLevel': taskPriorityLevel,
      'taskCreatedAt': Timestamp.fromDate(taskCreatedAt),
      if (taskDeletedAt != null)
        'taskDeletedAt': Timestamp.fromDate(taskDeletedAt!),
      'taskIsDeleted': taskIsDeleted,
      'taskTitle': taskTitle,
      'taskDescription': taskDescription,
      if (taskDeadline != null)
        'taskDeadline': Timestamp.fromDate(taskDeadline!),
      'taskDeadlineMissed': taskDeadlineMissed,
      'taskExtensionCount': taskExtensionCount,
      if (taskReminderSentAt != null)
        'taskReminderSentAt': Timestamp.fromDate(taskReminderSentAt!),
      'taskIsDone': taskIsDone,
      if (taskIsDoneAt != null)
        'taskIsDoneAt': Timestamp.fromDate(taskIsDoneAt!),
      'taskFailed': taskFailed,
      'taskStats': taskStats.toMap(),
      'taskStatus': taskStatus,
      'taskRequiresApproval': taskRequiresApproval,
      if (taskSubmissionId != null) 'taskSubmissionId': taskSubmissionId,
      'taskIsRepeating': taskIsRepeating,
      if (taskRepeatInterval != null) 'taskRepeatInterval': taskRepeatInterval,
      if (taskRepeatEndDate != null)
        'taskRepeatEndDate': Timestamp.fromDate(taskRepeatEndDate!),
      if (taskNextRepeatDate != null)
        'taskNextRepeatDate': Timestamp.fromDate(taskNextRepeatDate!),
      if (taskRepeatTime != null) 'taskRepeatTime': taskRepeatTime,
      if (taskAcceptanceStatus != null)
        'taskAcceptanceStatus': taskAcceptanceStatus,
      'taskHelpers': taskHelpers,
      'taskHelperNames': taskHelperNames,
    };
  }

  // CopyWith method to make task updates easier
  Task copyWith({
    String? taskId,
    String? taskBoardId,
    String? taskBoardTitle,
    String? taskOwnerId,
    String? taskOwnerName,
    String? taskAssignedBy,
    String? taskAssignedTo,
    String? taskAssignedToName,
    String? taskPriorityLevel,
    DateTime? taskCreatedAt,
    DateTime? taskDeletedAt,
    bool? taskIsDeleted,
    String? taskTitle,
    String? taskDescription,
    DateTime? taskDeadline,
    bool? taskDeadlineMissed,
    int? taskExtensionCount,
    bool? taskIsDone,
    DateTime? taskIsDoneAt,
    bool? taskFailed,
    TaskStats? taskStats,
    String? taskStatus,
    bool? taskRequiresApproval,
    String? taskSubmissionId,
    bool? taskIsRepeating,
    String? taskRepeatInterval,
    DateTime? taskRepeatEndDate,
    DateTime? taskNextRepeatDate,
    String? taskRepeatTime,
    String? taskAcceptanceStatus,
    List<String>? taskHelpers,
    Map<String, String>? taskHelperNames,
  }) {
    return Task(
      taskId: taskId ?? this.taskId,
      taskBoardId: taskBoardId ?? this.taskBoardId,
      taskBoardTitle: taskBoardTitle ?? this.taskBoardTitle,
      taskOwnerId: taskOwnerId ?? this.taskOwnerId,
      taskOwnerName: taskOwnerName ?? this.taskOwnerName,
      taskAssignedBy: taskAssignedBy ?? this.taskAssignedBy,
      taskAssignedTo: taskAssignedTo ?? this.taskAssignedTo,
      taskAssignedToName: taskAssignedToName ?? this.taskAssignedToName,
      taskPriorityLevel: taskPriorityLevel ?? this.taskPriorityLevel,
      taskCreatedAt: taskCreatedAt ?? this.taskCreatedAt,
      taskDeletedAt: taskDeletedAt ?? this.taskDeletedAt,
      taskIsDeleted: taskIsDeleted ?? this.taskIsDeleted,
      taskTitle: taskTitle ?? this.taskTitle,
      taskDescription: taskDescription ?? this.taskDescription,
      taskDeadline: taskDeadline ?? this.taskDeadline,
      taskDeadlineMissed: taskDeadlineMissed ?? this.taskDeadlineMissed,
      taskExtensionCount: taskExtensionCount ?? this.taskExtensionCount,
      taskIsDone: taskIsDone ?? this.taskIsDone,
      taskIsDoneAt: taskIsDoneAt ?? this.taskIsDoneAt,
      taskFailed: taskFailed ?? this.taskFailed,
      taskStats: taskStats ?? this.taskStats,
      taskStatus: taskStatus ?? this.taskStatus,
      taskRequiresApproval: taskRequiresApproval ?? this.taskRequiresApproval,
      taskSubmissionId: taskSubmissionId ?? this.taskSubmissionId,
      taskIsRepeating: taskIsRepeating ?? this.taskIsRepeating,
      taskRepeatInterval: taskRepeatInterval ?? this.taskRepeatInterval,
      taskRepeatEndDate: taskRepeatEndDate ?? this.taskRepeatEndDate,
      taskNextRepeatDate:
          taskNextRepeatDate ?? this.taskNextRepeatDate,
      taskRepeatTime: taskRepeatTime ?? this.taskRepeatTime,
      taskAcceptanceStatus: taskAcceptanceStatus ?? this.taskAcceptanceStatus,
      taskHelpers: taskHelpers ?? this.taskHelpers,
      taskHelperNames: taskHelperNames ?? this.taskHelperNames,
    );
  }

  /// Reset task for next repeat cycle
  /// When a repeating task is marked as done, call this to prepare it for the next repeat
  Task resetForNextRepeat() {
    if (!taskIsRepeating) {
      return this;
    }

    // Calculate next repeat date based on taskRepeatInterval
    DateTime? nextRepeat = taskNextRepeatDate;
    if (nextRepeat != null) {
      // Add one cycle to the next repeat date
      // For now, assume weekly cycles (can be enhanced for daily/monthly)
      nextRepeat = nextRepeat.add(const Duration(days: 7));
    }

    return copyWith(
      taskIsDone: false,
      taskIsDoneAt: null,
      taskNextRepeatDate: nextRepeat,
    );
  }
}
