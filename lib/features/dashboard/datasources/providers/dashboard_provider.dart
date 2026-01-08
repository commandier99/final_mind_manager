/*import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../shared/features/user/user_stats_model.dart';
import '../services/dashboard_services.dart';

class DashboardProvider extends ChangeNotifier {
  final DashboardServices _services = DashboardServices();

  UserStatsModel? _userStats;
  UserStatsModel? get userStats => _userStats;

  Stream<UserStatsModel>? _statsStream;

  /// Listen to a user's stats safely
  void listenToUserStats(String? userId) {
    if (userId == null || userId.isEmpty) return;

    _statsStream = _services.streamUserStats(userId);
    _statsStream!.listen((stats) {
      _userStats = stats;
      notifyListeners();
    });
  }

  /// Fetch user stats once safely
  Future<void> fetchUserStats(String? userId) async {
    if (userId == null || userId.isEmpty) return;

    _userStats = await _services.getUserStats(userId);
    notifyListeners();
  }

  /// Helper to automatically listen using the current FirebaseAuth user
  void initWithCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      listenToUserStats(user.uid);
    }
  }
}
*/