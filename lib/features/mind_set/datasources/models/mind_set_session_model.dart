import 'package:cloud_firestore/cloud_firestore.dart';
import 'mind_set_session_stats_model.dart';

class MindSetSession {
  final String sessionId;
  final String sessionUserId;
  final String sessionType; // on_the_spot, go_with_flow, follow_through
  final String sessionMode; // Checklist, Pomodoro, Eat the Frog
  final String sessionFlowStyle; // flow, list
  final List<MindSetModeChange> sessionModeHistory;
  final String sessionTitle;
  final String sessionPurpose;
  final String sessionWhy;
  final String sessionStatus; // active, completed, cancelled
  final DateTime sessionCreatedAt;
  final DateTime? sessionStartedAt;
  final DateTime? sessionEndedAt;
  final String? sessionActiveTaskId;
  final List<String> sessionTaskIds;
  final MindSetSessionStats sessionStats;

  const MindSetSession({
    required this.sessionId,
    required this.sessionUserId,
    required this.sessionType,
    required this.sessionMode,
    this.sessionFlowStyle = 'list',
    this.sessionModeHistory = const [],
    required this.sessionTitle,
    required this.sessionPurpose,
    required this.sessionWhy,
    required this.sessionStatus,
    required this.sessionCreatedAt,
    this.sessionStartedAt,
    this.sessionEndedAt,
    this.sessionActiveTaskId,
    this.sessionTaskIds = const [],
    required this.sessionStats,
  });

  factory MindSetSession.fromMap(Map<String, dynamic> data) {
    final historyData = data['sessionModeHistory'] as List<dynamic>?;

    return MindSetSession(
      sessionId: data['sessionId'] as String,
      sessionUserId: data['sessionUserId'] as String,
      sessionType: data['sessionType'] as String,
      sessionMode: data['sessionMode'] as String,
      sessionFlowStyle:
          data['sessionFlowStyle'] as String? ?? 'list',
      sessionModeHistory: historyData
              ?.map(
                (entry) => MindSetModeChange.fromMap(
                  Map<String, dynamic>.from(entry as Map),
                ),
              )
              .toList() ??
          const [],
      sessionTitle: data['sessionTitle'] as String? ?? '',
      sessionPurpose: data['sessionPurpose'] as String? ?? '',
      sessionWhy: data['sessionWhy'] as String? ?? '',
      sessionStatus: data['sessionStatus'] as String? ?? 'active',
      sessionCreatedAt:
          (data['sessionCreatedAt'] as Timestamp).toDate(),
      sessionStartedAt: data['sessionStartedAt'] != null
          ? (data['sessionStartedAt'] as Timestamp).toDate()
          : null,
      sessionEndedAt: data['sessionEndedAt'] != null
          ? (data['sessionEndedAt'] as Timestamp).toDate()
          : null,
      sessionActiveTaskId:
          data['sessionActiveTaskId'] as String?,
      sessionTaskIds:
          List<String>.from(data['sessionTaskIds'] ?? const []),
      sessionStats: MindSetSessionStats.fromMap(
        (data['sessionStats']
                as Map<String, dynamic>? ??
            const {}),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'sessionUserId': sessionUserId,
      'sessionType': sessionType,
      'sessionMode': sessionMode,
      'sessionFlowStyle': sessionFlowStyle,
      'sessionModeHistory':
          sessionModeHistory.map((e) => e.toMap()).toList(),
      'sessionTitle': sessionTitle,
      'sessionPurpose': sessionPurpose,
      'sessionWhy': sessionWhy,
      'sessionStatus': sessionStatus,
      'sessionCreatedAt':
          Timestamp.fromDate(sessionCreatedAt),
      'sessionStartedAt': sessionStartedAt != null
          ? Timestamp.fromDate(sessionStartedAt!)
          : null,
      'sessionEndedAt': sessionEndedAt != null
          ? Timestamp.fromDate(sessionEndedAt!)
          : null,
      'sessionActiveTaskId': sessionActiveTaskId,
      'sessionTaskIds': sessionTaskIds,
      'sessionStats': sessionStats.toMap(),
    };
  }

  MindSetSession copyWith({
    String? sessionId,
    String? sessionUserId,
    String? sessionType,
    String? sessionMode,
    String? sessionFlowStyle,
    List<MindSetModeChange>? sessionModeHistory,
    String? sessionTitle,
    String? sessionPurpose,
    String? sessionWhy,
    String? sessionStatus,
    DateTime? sessionCreatedAt,
    DateTime? sessionStartedAt,
    DateTime? sessionEndedAt,
    String? sessionActiveTaskId,
    List<String>? sessionTaskIds,
    MindSetSessionStats? sessionStats,
  }) {
    return MindSetSession(
      sessionId: sessionId ?? this.sessionId,
      sessionUserId:
          sessionUserId ?? this.sessionUserId,
      sessionType: sessionType ?? this.sessionType,
      sessionMode: sessionMode ?? this.sessionMode,
      sessionFlowStyle:
          sessionFlowStyle ?? this.sessionFlowStyle,
      sessionModeHistory:
          sessionModeHistory ?? this.sessionModeHistory,
      sessionTitle: sessionTitle ?? this.sessionTitle,
      sessionPurpose:
          sessionPurpose ?? this.sessionPurpose,
      sessionWhy: sessionWhy ?? this.sessionWhy,
      sessionStatus:
          sessionStatus ?? this.sessionStatus,
      sessionCreatedAt:
          sessionCreatedAt ?? this.sessionCreatedAt,
      sessionStartedAt:
          sessionStartedAt ?? this.sessionStartedAt,
      sessionEndedAt:
          sessionEndedAt ?? this.sessionEndedAt,
      sessionActiveTaskId:
          sessionActiveTaskId ?? this.sessionActiveTaskId,
      sessionTaskIds:
          sessionTaskIds ?? this.sessionTaskIds,
      sessionStats:
          sessionStats ?? this.sessionStats,
    );
  }
}

class MindSetModeChange {
  final String mode;
  final DateTime changedAt;

  const MindSetModeChange({
    required this.mode,
    required this.changedAt,
  });

  factory MindSetModeChange.fromMap(
      Map<String, dynamic> data) {
    return MindSetModeChange(
      mode: data['mode'] as String? ?? 'Checklist',
      changedAt:
          (data['changedAt'] as Timestamp?)
                  ?.toDate() ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mode': mode,
      'changedAt':
          Timestamp.fromDate(changedAt),
    };
  }
}
