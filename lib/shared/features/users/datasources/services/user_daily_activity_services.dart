import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/user_daily_activity_model.dart';

void _log(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class UserDailyActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _days(String userId) => _firestore
      .collection('user_daily_activity')
      .doc(userId)
      .collection('days');

  String _todayId() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<UserDailyActivityModel?> getToday(String userId) async {
    _log(
      "[DEBUG] UserDailyActivityService.getToday: Fetching today's activity for userId: $userId, dateId: ${_todayId()}",
    );
    try {
      final doc = await _days(userId).doc(_todayId()).get();
      if (!doc.exists || doc.data() == null) {
        _log(
          "[DEBUG] UserDailyActivityService.getToday: No activity record found for today",
        );
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      _log(
        "[DEBUG] UserDailyActivityService.getToday: Today's activity found - tasks: ${data['tasksCreatedCount'] ?? 0}, subtasks: ${data['subtasksCreatedCount'] ?? 0}",
      );
      return UserDailyActivityModel(
        userId: userId,
        date: data['date'],
        tasksCreatedCount: data['tasksCreatedCount'] ?? 0,
        tasksCompletedCount: data['tasksCompletedCount'] ?? 0,
        tasksDeletedCount: data['tasksDeletedCount'] ?? 0,
        subtasksCreatedCount: data['subtasksCreatedCount'] ?? 0,
        subtasksCompletedCount: data['subtasksCompletedCount'] ?? 0,
        subtasksDeletedCount: data['subtasksDeletedCount'] ?? 0,
        focusMinutes: data['focusMinutes'] ?? 0,
        focusSessionsCount: data['focusSessionsCount'] ?? 0,
        firstActivityAt: data['firstActivityAt'],
        lastActivityAt: data['lastActivityAt'],
      );
    } catch (e) {
      _log(
        "[ERROR] UserDailyActivityService.getToday: Failed to fetch today's activity - $e",
      );
      rethrow;
    }
  }

  Future<void> ensureToday(String userId) async {
    _log(
      "[DEBUG] UserDailyActivityService.ensureToday: Ensuring today's activity record exists for userId: $userId",
    );
    try {
      final ref = _days(userId).doc(_todayId());
      final doc = await ref.get();

      if (!doc.exists) {
        _log(
          "[DEBUG] UserDailyActivityService.ensureToday: Creating new daily activity record for today",
        );
        await ref.set({
          'userId': userId,
          'date': _todayId(),
          'tasksCreatedCount': 0,
          'tasksCompletedCount': 0,
          'tasksDeletedCount': 0,
          'subtasksCreatedCount': 0,
          'subtasksCompletedCount': 0,
          'subtasksDeletedCount': 0,
          'focusMinutes': 0,
          'focusSessionsCount': 0,
          'firstActivityAt': Timestamp.now(),
          'lastActivityAt': Timestamp.now(),
        });
        _log(
          "[DEBUG] UserDailyActivityService.ensureToday: New daily activity record created",
        );
      } else {
        _log(
          "[DEBUG] UserDailyActivityService.ensureToday: Today's activity record already exists",
        );
      }
    } catch (e) {
      _log(
        "[ERROR] UserDailyActivityService.ensureToday: Failed to ensure today's record - $e",
      );
      rethrow;
    }
  }

  Future<void> incrementToday(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    _log(
      "[DEBUG] UserDailyActivityService.incrementToday: Incrementing today's activity for userId: $userId, updates: $updates",
    );
    try {
      await ensureToday(userId);

      await _days(userId).doc(_todayId()).update({
        ...updates.map((k, v) => MapEntry(k, FieldValue.increment(v))),
        'lastActivityAt': Timestamp.now(),
      });
      _log(
        "[DEBUG] UserDailyActivityService.incrementToday: Today's activity incremented successfully",
      );
    } catch (e) {
      _log(
        "[ERROR] UserDailyActivityService.incrementToday: Failed to increment today's activity - $e",
      );
      rethrow;
    }
  }

  Future<List<UserDailyActivityModel>> getRecentDays(
    String userId, {
    int days = 14,
  }) async {
    try {
      final snapshot = await _days(
        userId,
      ).orderBy('date', descending: true).limit(days).get();

      final records = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return UserDailyActivityModel(
          userId: userId,
          date: (data['date'] as String?) ?? doc.id,
          tasksCreatedCount: data['tasksCreatedCount'] ?? 0,
          tasksCompletedCount: data['tasksCompletedCount'] ?? 0,
          tasksDeletedCount: data['tasksDeletedCount'] ?? 0,
          subtasksCreatedCount: data['subtasksCreatedCount'] ?? 0,
          subtasksCompletedCount: data['subtasksCompletedCount'] ?? 0,
          subtasksDeletedCount: data['subtasksDeletedCount'] ?? 0,
          focusMinutes: data['focusMinutes'] ?? 0,
          focusSessionsCount: data['focusSessionsCount'] ?? 0,
          firstActivityAt: data['firstActivityAt'],
          lastActivityAt: data['lastActivityAt'],
        );
      }).toList();

      // Ensure a complete day-by-day series (fill missing dates with zeros).
      final byDate = <String, UserDailyActivityModel>{
        for (final item in records) item.date: item,
      };
      final today = DateTime.now();
      final filled = <UserDailyActivityModel>[];
      for (var i = days - 1; i >= 0; i--) {
        final day = DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(Duration(days: i));
        final dateId =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        filled.add(
          byDate[dateId] ??
              UserDailyActivityModel(userId: userId, date: dateId),
        );
      }

      return filled;
    } catch (e) {
      _log('[ERROR] UserDailyActivityService.getRecentDays: Failed - $e');
      rethrow;
    }
  }
}
