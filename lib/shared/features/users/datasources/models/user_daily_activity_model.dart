import 'package:cloud_firestore/cloud_firestore.dart';

class UserDailyActivityModel {
  final String userId;
  final String date; // yyyy-MM-dd as document ID

  // Tasks
  final int tasksCreatedCount;
  final int tasksCompletedCount;
  final int tasksDeletedCount;

  // Subtasks
  final int subtasksCreatedCount;
  final int subtasksCompletedCount;
  final int subtasksDeletedCount;

  // Time / focus
  final int focusMinutes;
  final int focusSessionsCount;

  // Optional
  final Timestamp? firstActivityAt;
  final Timestamp? lastActivityAt;

  const UserDailyActivityModel({
    required this.userId,
    required this.date,
    this.tasksCreatedCount = 0,
    this.tasksCompletedCount = 0,
    this.tasksDeletedCount = 0,
    this.subtasksCreatedCount = 0,
    this.subtasksCompletedCount = 0,
    this.subtasksDeletedCount = 0,
    this.focusMinutes = 0,
    this.focusSessionsCount = 0,
    this.firstActivityAt,
    this.lastActivityAt,
  });
}
