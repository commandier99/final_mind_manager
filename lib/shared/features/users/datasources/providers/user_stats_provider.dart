import 'package:flutter/foundation.dart';
import '../models/user_stats_model.dart';
import '../services/user_stats_services.dart';

class UserStatsProvider extends ChangeNotifier {
  final UserStatsService _service = UserStatsService();

  UserStatsModel? _stats;
  UserStatsModel? get stats => _stats;

  bool get hasStats => _stats != null;

  Future<void> loadStats(String userId) async {
    _stats = await _service.getStats(userId);
    notifyListeners();
  }

  Future<void> incrementStats(String userId, Map<String, dynamic> updates) async {
    await _service.increment(userId, updates);
    await loadStats(userId);
  }

  void clear() {
    _stats = null;
    notifyListeners();
  }
}
