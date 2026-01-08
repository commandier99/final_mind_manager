import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_daily_activity_model.dart';

class UserDailyActivityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _days(String userId) =>
      _firestore.collection('user_daily_activity').doc(userId).collection('days');

  String _todayId() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<UserDailyActivityModel?> getToday(String userId) async {
    print('[DEBUG] UserDailyActivityService.getToday: Fetching today\'s activity for userId: $userId, dateId: ${_todayId()}');
    try {
      final doc = await _days(userId).doc(_todayId()).get();
      if (!doc.exists || doc.data() == null) {
        print('[DEBUG] UserDailyActivityService.getToday: No activity record found for today');
        return null;
      }

      final data = doc.data() as Map<String, dynamic>;
      print('[DEBUG] UserDailyActivityService.getToday: Today\'s activity found - tasks: ${data['tasksCreatedCount'] ?? 0}, subtasks: ${data['subtasksCreatedCount'] ?? 0}');
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
      print('[ERROR] UserDailyActivityService.getToday: Failed to fetch today\'s activity - $e');
      rethrow;
    }
  }

  Future<void> ensureToday(String userId) async {
    print('[DEBUG] UserDailyActivityService.ensureToday: Ensuring today\'s activity record exists for userId: $userId');
    try {
      final ref = _days(userId).doc(_todayId());
      final doc = await ref.get();

      if (!doc.exists) {
        print('[DEBUG] UserDailyActivityService.ensureToday: Creating new daily activity record for today');
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
        print('[DEBUG] UserDailyActivityService.ensureToday: New daily activity record created');
      } else {
        print('[DEBUG] UserDailyActivityService.ensureToday: Today\'s activity record already exists');
      }
    } catch (e) {
      print('[ERROR] UserDailyActivityService.ensureToday: Failed to ensure today\'s record - $e');
      rethrow;
    }
  }

  Future<void> incrementToday(String userId, Map<String, dynamic> updates) async {
    print('[DEBUG] UserDailyActivityService.incrementToday: Incrementing today\'s activity for userId: $userId, updates: $updates');
    try {
      await ensureToday(userId);

      await _days(userId).doc(_todayId()).update({
        ...updates.map(
          (k, v) => MapEntry(k, FieldValue.increment(v)),
        ),
        'lastActivityAt': Timestamp.now(),
      });
      print('[DEBUG] UserDailyActivityService.incrementToday: Today\'s activity incremented successfully');
    } catch (e) {
      print('[ERROR] UserDailyActivityService.incrementToday: Failed to increment today\'s activity - $e');
      rethrow;
    }
  }
}
