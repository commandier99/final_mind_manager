import 'package:cloud_firestore/cloud_firestore.dart';
import 'task_stats_model.dart';

const Object _taskCopyWithUnset = Object();

class Task {
  static const String statusToDo = 'To Do';
  static const String statusInProgress = 'In Progress';
  static const String statusPaused = 'Paused';
  static const String statusSubmitted = 'Submitted';
  static const String statusCompleted = 'Completed';
  static const String statusRejected = 'Rejected';
  static const String outcomeNone = 'none';
  static const String outcomeSuccessful = 'successful';
  static const String outcomeFailed = 'failed';
  static const String laneDrafts = 'drafts';
  static const String lanePublished = 'published';

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
  final DateTime?
  taskReminderSentAt; // When deadline reminder was sent (to prevent duplicates)

  final bool taskIsDone;
  final DateTime? taskIsDoneAt;

  final bool taskFailed; // Whether task was marked as failed by manager
  final String? taskOutcome; // none | successful | failed

  final TaskStats taskStats; // TaskStats model for task stats

  // Status field - tracks task workflow state
  final String taskStatus; // e.g. 'To Do', 'In Progress', 'Paused', 'Rejected', 'Completed'

  // Approval fields - optional, only used if task requires approval
  final bool
  taskAllowsSubmissions; // Whether users can submit files for this task
  final bool taskRequiresSubmission; // Whether a submission is mandatory
  final bool taskRequiresApproval; // Whether this task needs approval
  final String
  taskApprovalStatus; // none | pending | approved | rejected | changes_requested
  final String? taskSubmissionId; // Reference to task submission if exists
  final String? taskLatestSubmissionThoughtId;

  // Repeating Fields
  final bool taskIsRepeating; // Does the task repeat?
  final String? taskRepeatInterval; // Repeat interval (e.g., "daily", "weekly")
  final DateTime? taskRepeatEndDate; // End date for repeating
  final DateTime? taskNextRepeatDate; // Date for the next repeat
  final String?
  taskRepeatTime; // Time of day for repeat (HH:mm format, e.g., "14:30")

  // Acceptance status for assigned tasks
  final String?
  taskAssignmentStatus; // pending | accepted | declined | null for self-assigned
  final String? taskProposedAssigneeId;
  final String? taskProposedAssigneeName;

  // Board task lane:
  // - 'drafts': manager/supervisor draft/prep space
  // - 'published': member-facing published task
  final String taskBoardLane;

  // Task dependency IDs that must be completed before this task can start/done
  final List<String> taskDependencyIds;

  // Revision linkage fields (optional)
  final String? taskRevisionOfTaskId;
  final String? taskRevisionOfSubmissionId;

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
    this.taskOutcome = outcomeNone,
    required this.taskStats, // TaskStats passed as a parameter
    this.taskStatus = statusToDo,
    this.taskAllowsSubmissions = true,
    this.taskRequiresSubmission = false,
    this.taskRequiresApproval = false,
    this.taskApprovalStatus = 'none',
    this.taskSubmissionId,
    this.taskLatestSubmissionThoughtId,
    this.taskIsRepeating = false,
    this.taskRepeatInterval,
    this.taskRepeatEndDate,
    this.taskNextRepeatDate,
    this.taskRepeatTime,
    this.taskAssignmentStatus,
    this.taskProposedAssigneeId,
    this.taskProposedAssigneeName,
    this.taskBoardLane = lanePublished,
    this.taskDependencyIds = const [],
    this.taskRevisionOfTaskId,
    this.taskRevisionOfSubmissionId,
  });

  // Helper to map legacy Firestore statuses to core statuses
  static String normalizeTaskStatus(String status) {
    switch (status.toUpperCase()) {
      case 'TODO':
      case 'TO DO':
        return statusToDo;
      case 'IN_PROGRESS':
      case 'IN PROGRESS':
        return statusInProgress;
      case 'ON_PAUSE':
      case 'PAUSED':
        return statusPaused;
      case 'SUBMITTED':
        return statusSubmitted;
      case 'DONE':
      case 'COMPLETED':
        return statusCompleted;
      case 'REJECTED':
        return statusRejected;
      // Legacy states map to In Progress
      case 'IN_REVIEW':
      case 'UNDER_REVISION':
        return statusInProgress;
      default:
        return statusToDo;
    }
  }

  static String normalizeTaskBoardLane(String lane) {
    switch (lane.trim().toLowerCase()) {
      case laneDrafts:
        return laneDrafts;
      case lanePublished:
      default:
        return lanePublished;
    }
  }

  static String normalizeTaskApprovalStatus(String status) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return 'pending';
      case 'approved':
        return 'approved';
      case 'rejected':
        return 'rejected';
      case 'changes_requested':
      case 'revision_requested':
        return 'changes_requested';
      case 'none':
      default:
        return 'none';
    }
  }

  // Computed deadline state getters
  static String normalizeTaskOutcome(String outcome) {
    switch (outcome.trim().toLowerCase()) {
      case outcomeSuccessful:
        return outcomeSuccessful;
      case outcomeFailed:
        return outcomeFailed;
      case outcomeNone:
      default:
        return outcomeNone;
    }
  }

  String get effectiveTaskOutcome =>
      normalizeTaskOutcome(taskOutcome ?? outcomeNone);

  bool get isOverdue {
    if (taskIsDone || taskDeadline == null) return false;
    return DateTime.now().isAfter(taskDeadline!);
  }

  bool get isDueToday {
    if (taskIsDone || taskDeadline == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(
      taskDeadline!.year,
      taskDeadline!.month,
      taskDeadline!.day,
    );
    return deadlineDay == today;
  }

  bool get isDueUpcoming {
    if (taskIsDone || taskDeadline == null || isOverdue || isDueToday) {
      return false;
    }
    return DateTime.now().isBefore(taskDeadline!);
  }

  bool get hasMissedDeadline {
    if (taskIsDone || taskDeadline == null) return false;
    return taskDeadlineMissed || DateTime.now().isAfter(taskDeadline!);
  }

  bool get isRejected =>
      normalizeTaskApprovalStatus(taskApprovalStatus) == 'rejected' ||
      normalizeTaskStatus(taskStatus) == statusRejected;

  bool get isWorkDisabled {
    return hasMissedDeadline ||
        taskFailed ||
        effectiveTaskOutcome == outcomeFailed ||
        isRejected;
  }

  String? get workDisabledReason {
    if (taskFailed || effectiveTaskOutcome == outcomeFailed || isRejected) {
      return 'Task rejected. Only the board manager can delete it.';
    }
    if (hasMissedDeadline) {
      return 'Deadline missed. Request a deadline extension to continue.';
    }
    return null;
  }

  // Factory to create Task from Firestore document
  factory Task.fromMap(Map<String, dynamic> data, String documentId) {
    final taskBoardId = data['taskBoardId'] as String? ?? '';
    final allowsSubmissions = data['taskAllowsSubmissions'] as bool?;
    final requiresApproval = data['taskRequiresApproval'] as bool? ?? false;
    final hasSubmissionId = (data['taskSubmissionId'] as String?) != null;
    final taskIsDone = data['taskIsDone'] as bool? ?? false;
    final taskFailed = data['taskFailed'] as bool? ?? false;

    return Task(
      taskId: documentId,
      taskBoardId: taskBoardId,
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
      taskIsDone: taskIsDone,
      taskIsDoneAt: (data['taskIsDoneAt'] as Timestamp?)?.toDate(),
      taskFailed: taskFailed,
      taskOutcome: normalizeTaskOutcome(
        data['taskOutcome'] as String? ??
            (taskFailed
                ? outcomeFailed
                : (taskIsDone && !(requiresApproval && hasSubmissionId)
                      ? outcomeSuccessful
                      : outcomeNone)),
      ),
      taskStats: data['taskStats'] != null
          ? TaskStats.fromMap(Map<String, dynamic>.from(data['taskStats']))
          : TaskStats(), // Fallback to empty TaskStats if null
      taskStatus: normalizeTaskStatus(
        data['taskStatus'] as String? ?? statusToDo,
      ),
      taskAllowsSubmissions: allowsSubmissions ?? true,
      taskRequiresSubmission: data['taskRequiresSubmission'] as bool? ?? false,
      taskRequiresApproval: requiresApproval,
      taskApprovalStatus: normalizeTaskApprovalStatus(
        data['taskApprovalStatus'] as String? ?? 'none',
      ),
      taskSubmissionId: data['taskSubmissionId'] as String?,
      taskLatestSubmissionThoughtId:
          data['taskLatestSubmissionThoughtId'] as String?,
      taskIsRepeating: data['taskIsRepeating'] as bool? ?? false,
      taskRepeatInterval: data['taskRepeatInterval'] as String?,
      taskRepeatEndDate: (data['taskRepeatEndDate'] as Timestamp?)?.toDate(),
      taskNextRepeatDate: (data['taskNextRepeatDate'] as Timestamp?)?.toDate(),
      taskRepeatTime: data['taskRepeatTime'] as String?,
      taskAssignmentStatus:
          data['taskAssignmentStatus'] as String? ??
          data['taskAcceptanceStatus'] as String?,
      taskProposedAssigneeId: data['taskProposedAssigneeId'] as String?,
      taskProposedAssigneeName: data['taskProposedAssigneeName'] as String?,
      taskBoardLane: normalizeTaskBoardLane(
        data['taskBoardLane'] as String? ?? lanePublished,
      ),
      taskDependencyIds: List<String>.from(
        data['taskDependencyIds'] ?? const [],
      ),
      taskRevisionOfTaskId: data['taskRevisionOfTaskId'] as String?,
      taskRevisionOfSubmissionId: data['taskRevisionOfSubmissionId'] as String?,
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
      'taskFailed':
          normalizeTaskOutcome(taskOutcome ?? outcomeNone) == outcomeFailed,
      'taskOutcome': normalizeTaskOutcome(taskOutcome ?? outcomeNone),
      'taskStats': taskStats.toMap(),
      'taskStatus': normalizeTaskStatus(taskStatus),
      'taskAllowsSubmissions': taskAllowsSubmissions,
      'taskRequiresSubmission': taskRequiresSubmission,
      'taskRequiresApproval': taskRequiresApproval,
      'taskApprovalStatus': normalizeTaskApprovalStatus(taskApprovalStatus),
      if (taskSubmissionId != null) 'taskSubmissionId': taskSubmissionId,
      if (taskLatestSubmissionThoughtId != null)
        'taskLatestSubmissionThoughtId': taskLatestSubmissionThoughtId,
      'taskIsRepeating': taskIsRepeating,
      if (taskRepeatInterval != null) 'taskRepeatInterval': taskRepeatInterval,
      if (taskRepeatEndDate != null)
        'taskRepeatEndDate': Timestamp.fromDate(taskRepeatEndDate!),
      if (taskNextRepeatDate != null)
        'taskNextRepeatDate': Timestamp.fromDate(taskNextRepeatDate!),
      if (taskRepeatTime != null) 'taskRepeatTime': taskRepeatTime,
      if (taskAssignmentStatus != null)
        'taskAssignmentStatus': taskAssignmentStatus,
      if (taskProposedAssigneeId != null)
        'taskProposedAssigneeId': taskProposedAssigneeId,
      if (taskProposedAssigneeName != null)
        'taskProposedAssigneeName': taskProposedAssigneeName,
      'taskBoardLane': normalizeTaskBoardLane(taskBoardLane),
      'taskDependencyIds': taskDependencyIds,
      if (taskRevisionOfTaskId != null)
        'taskRevisionOfTaskId': taskRevisionOfTaskId,
      if (taskRevisionOfSubmissionId != null)
        'taskRevisionOfSubmissionId': taskRevisionOfSubmissionId,
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
    String? taskOutcome,
    TaskStats? taskStats,
    String? taskStatus,
    bool? taskAllowsSubmissions,
    bool? taskRequiresSubmission,
    bool? taskRequiresApproval,
    String? taskApprovalStatus,
    String? taskSubmissionId,
    String? taskLatestSubmissionThoughtId,
    bool? taskIsRepeating,
    String? taskRepeatInterval,
    DateTime? taskRepeatEndDate,
    DateTime? taskNextRepeatDate,
    String? taskRepeatTime,
    Object? taskAssignmentStatus = _taskCopyWithUnset,
    Object? taskProposedAssigneeId = _taskCopyWithUnset,
    Object? taskProposedAssigneeName = _taskCopyWithUnset,
    String? taskBoardLane,
    List<String>? taskDependencyIds,
    String? taskRevisionOfTaskId,
    String? taskRevisionOfSubmissionId,
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
      taskOutcome: normalizeTaskOutcome(
        taskOutcome ?? this.taskOutcome ?? outcomeNone,
      ),
      taskStats: taskStats ?? this.taskStats,
      taskStatus: normalizeTaskStatus(taskStatus ?? this.taskStatus),
      taskAllowsSubmissions:
          taskAllowsSubmissions ?? this.taskAllowsSubmissions,
      taskRequiresSubmission:
          taskRequiresSubmission ?? this.taskRequiresSubmission,
      taskRequiresApproval: taskRequiresApproval ?? this.taskRequiresApproval,
      taskApprovalStatus: normalizeTaskApprovalStatus(
        taskApprovalStatus ?? this.taskApprovalStatus,
      ),
      taskSubmissionId: taskSubmissionId ?? this.taskSubmissionId,
      taskLatestSubmissionThoughtId:
          taskLatestSubmissionThoughtId ?? this.taskLatestSubmissionThoughtId,
      taskIsRepeating: taskIsRepeating ?? this.taskIsRepeating,
      taskRepeatInterval: taskRepeatInterval ?? this.taskRepeatInterval,
      taskRepeatEndDate: taskRepeatEndDate ?? this.taskRepeatEndDate,
      taskNextRepeatDate: taskNextRepeatDate ?? this.taskNextRepeatDate,
      taskRepeatTime: taskRepeatTime ?? this.taskRepeatTime,
      taskAssignmentStatus: identical(
            taskAssignmentStatus,
            _taskCopyWithUnset,
          )
          ? this.taskAssignmentStatus
          : taskAssignmentStatus as String?,
      taskProposedAssigneeId: identical(
            taskProposedAssigneeId,
            _taskCopyWithUnset,
          )
          ? this.taskProposedAssigneeId
          : taskProposedAssigneeId as String?,
      taskProposedAssigneeName: identical(
            taskProposedAssigneeName,
            _taskCopyWithUnset,
          )
          ? this.taskProposedAssigneeName
          : taskProposedAssigneeName as String?,
      taskBoardLane: normalizeTaskBoardLane(
        taskBoardLane ?? this.taskBoardLane,
      ),
      taskDependencyIds: taskDependencyIds ?? this.taskDependencyIds,
      taskRevisionOfTaskId: taskRevisionOfTaskId ?? this.taskRevisionOfTaskId,
      taskRevisionOfSubmissionId:
          taskRevisionOfSubmissionId ?? this.taskRevisionOfSubmissionId,
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
