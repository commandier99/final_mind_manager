import 'package:cloud_firestore/cloud_firestore.dart';
import 'board_stats_model.dart';
import 'board_roles.dart';

class Board {
  static const int defaultMemberTaskLimit = 5;
  final String boardId;
  final String boardManagerId;
  final String boardManagerName;
  final DateTime boardCreatedAt;
  final String boardTitle;
  final String boardGoal;
  final String boardGoalDescription;

  final BoardStats stats;

  final List<String> memberIds;
  final DateTime? boardDeletedAt;
  final bool boardIsDeleted;

  // Visibility and join settings
  final bool boardIsPublic;
  final bool boardRequiresApproval;
  final String? boardDescription;
  final int boardMemberLimit; // 0 = unlimited

  // Board type: 'personal' or 'team'
  // Personal boards auto-assign tasks to the owner (no dropdown)
  // Team boards show assignment dropdown even with 1 member
  final String boardType;

  // Board purpose: 'project' or 'category'
  // Project boards focus on a deliverable; Category boards are for sorting tasks
  final String boardPurpose;

  // Role-based access control
  // memberRoles: userId -> role mapping
  // Roles: 'manager', 'member', 'supervisor'
  final Map<String, String> memberRoles;
  final Map<String, int>
  memberTaskLimits; // userId -> max tasks they can be assigned
  final int boardTaskCapacity; // uniform active task cap for members, 0 = unlimited

  final DateTime boardLastModifiedAt;
  final String boardLastModifiedBy;

  Board({
    required this.boardId,
    required this.boardManagerId,
    required this.boardManagerName,
    required this.boardCreatedAt,
    required this.boardTitle,
    required this.boardGoal,
    required this.boardGoalDescription,
    required this.stats,
    this.memberIds = const [],
    this.boardDeletedAt,
    this.boardIsDeleted = false,
    this.boardIsPublic = false,
    this.boardRequiresApproval = true,
    this.boardDescription,
    this.boardMemberLimit = 0,
    this.boardType = 'team', // Default to team for backward compatibility
    this.boardPurpose =
        'project', // Default to project for backward compatibility
    this.memberRoles = const {},
    this.memberTaskLimits = const {},
    this.boardTaskCapacity = defaultMemberTaskLimit,
    required this.boardLastModifiedAt,
    required this.boardLastModifiedBy,
  });

  bool get isDeleted => boardIsDeleted;

  String roleOf(String? userId) {
    if (userId == null || userId.isEmpty) return BoardRoles.member;
    if (userId == boardManagerId) return BoardRoles.manager;
    return BoardRoles.normalize(memberRoles[userId]);
  }

  bool isManager(String? userId) => roleOf(userId) == BoardRoles.manager;

  bool isSupervisor(String? userId) => roleOf(userId) == BoardRoles.supervisor;

  bool canDraftTasks(String? userId) =>
      isManager(userId) || isSupervisor(userId);

  bool canPublishTasks(String? userId) => isManager(userId);

  bool canReviewSubmissions(String? userId) =>
      isManager(userId) || isSupervisor(userId);

  bool canPokeMembers(String? userId) =>
      isManager(userId) || isSupervisor(userId);

  int taskLimitForUser(
    String? userId, {
    int fallbackLimit = defaultMemberTaskLimit,
  }) {
    if (userId == null || userId.isEmpty) return 0;
    if (isManager(userId)) return 0; // manager is unlimited
    final configured = boardTaskCapacity;
    if (configured > 0) return configured;
    return fallbackLimit;
  }

  factory Board.fromMap(Map<String, dynamic> data, String documentId) {
    final rawRoles = Map<String, dynamic>.from(data['memberRoles'] ?? {});
    final normalizedRoles = <String, String>{};
    rawRoles.forEach((userId, role) {
      normalizedRoles[userId] = BoardRoles.normalize(role?.toString());
    });

    final managerId = data['boardManagerId'] ?? '';
    if (managerId is String && managerId.isNotEmpty) {
      normalizedRoles[managerId] = BoardRoles.manager;
    }

    return Board(
      boardId: documentId,
      boardManagerId: managerId,
      boardManagerName: data['boardManagerName'] ?? 'Unknown',
      boardCreatedAt: (data['boardCreatedAt'] as Timestamp).toDate(),
      boardTitle: data['boardTitle'],
      boardGoal: data['boardGoal'],
      boardGoalDescription: data['boardGoalDescription'],
      stats: data['stats'] != null
          ? BoardStats.fromMap(Map<String, dynamic>.from(data['stats']))
          : BoardStats(),
      memberIds: List<String>.from(data['memberIds'] ?? []),
      boardDeletedAt: data['boardDeletedAt'] != null
          ? (data['boardDeletedAt'] as Timestamp).toDate()
          : null,
      boardIsDeleted: data['boardIsDeleted'] ?? false,
      boardIsPublic: data['boardIsPublic'] ?? false,
      boardRequiresApproval: data['boardRequiresApproval'] ?? true,
      boardDescription: data['boardDescription'] as String?,
      boardMemberLimit: data['boardMemberLimit'] ?? 0,
      boardType:
          data['boardType'] ??
          'team', // Default to team for backward compatibility
      boardPurpose: data['boardPurpose'] ?? 'project',
      memberRoles: normalizedRoles,
      memberTaskLimits: Map<String, int>.from(data['memberTaskLimits'] ?? {}),
      boardTaskCapacity:
          (data['boardTaskCapacity'] as num?)?.toInt() ??
          defaultMemberTaskLimit,
      boardLastModifiedAt:
          (data['boardLastModifiedAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      boardLastModifiedBy: data['boardLastModifiedBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'boardId': boardId,
      'boardManagerId': boardManagerId,
      'boardManagerName': boardManagerName,
      'boardCreatedAt': Timestamp.fromDate(boardCreatedAt),
      'boardTitle': boardTitle,
      'boardGoal': boardGoal,
      'boardGoalDescription': boardGoalDescription,
      'stats': stats.toMap(),
      'memberIds': memberIds,
      if (boardDeletedAt != null)
        'boardDeletedAt': Timestamp.fromDate(boardDeletedAt!),
      'boardIsDeleted': boardIsDeleted,
      'boardIsPublic': boardIsPublic,
      'boardRequiresApproval': boardRequiresApproval,
      if (boardDescription != null) 'boardDescription': boardDescription,
      'boardMemberLimit': boardMemberLimit,
      'boardType': boardType,
      'boardPurpose': boardPurpose,
      'memberRoles': memberRoles,
      'memberTaskLimits': memberTaskLimits,
      'boardTaskCapacity': boardTaskCapacity,
      'boardLastModifiedAt': Timestamp.fromDate(boardLastModifiedAt),
      'boardLastModifiedBy': boardLastModifiedBy,
    };
  }

  Board copyWith({
    String? boardTitle,
    String? boardGoal,
    String? boardGoalDescription,
    BoardStats? stats,
    List<String>? memberIds,
    DateTime? boardDeletedAt,
    bool? boardIsDeleted,
    bool? boardIsPublic,
    bool? boardRequiresApproval,
    String? boardDescription,
    int? boardMemberLimit,
    String? boardType,
    String? boardPurpose,
    Map<String, String>? memberRoles,
    Map<String, int>? memberTaskLimits,
    int? boardTaskCapacity,
    DateTime? boardLastModifiedAt,
    String? boardLastModifiedBy,
  }) {
    return Board(
      boardId: boardId,
      boardManagerId: boardManagerId,
      boardManagerName: boardManagerName,
      boardCreatedAt: boardCreatedAt,
      boardTitle: boardTitle ?? this.boardTitle,
      boardGoal: boardGoal ?? this.boardGoal,
      boardGoalDescription: boardGoalDescription ?? this.boardGoalDescription,
      stats: stats ?? this.stats,
      memberIds: memberIds ?? this.memberIds,
      boardDeletedAt: boardDeletedAt ?? this.boardDeletedAt,
      boardIsDeleted: boardIsDeleted ?? this.boardIsDeleted,
      boardIsPublic: boardIsPublic ?? this.boardIsPublic,
      boardRequiresApproval:
          boardRequiresApproval ?? this.boardRequiresApproval,
      boardDescription: boardDescription ?? this.boardDescription,
      boardMemberLimit: boardMemberLimit ?? this.boardMemberLimit,
      boardType: boardType ?? this.boardType,
      boardPurpose: boardPurpose ?? this.boardPurpose,
      memberRoles: memberRoles ?? this.memberRoles,
      memberTaskLimits: memberTaskLimits ?? this.memberTaskLimits,
      boardTaskCapacity: boardTaskCapacity ?? this.boardTaskCapacity,
      boardLastModifiedAt: boardLastModifiedAt ?? this.boardLastModifiedAt,
      boardLastModifiedBy: boardLastModifiedBy ?? this.boardLastModifiedBy,
    );
  }
}
