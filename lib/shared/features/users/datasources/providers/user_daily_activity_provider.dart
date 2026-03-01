import 'package:flutter/foundation.dart';
import '../models/user_daily_activity_model.dart';
import '../services/user_daily_activity_services.dart';

class UserDailyActivityProvider extends ChangeNotifier {
  final UserDailyActivityService _service = UserDailyActivityService();

  UserDailyActivityModel? _today;
  UserDailyActivityModel? get today => _today;
  List<UserDailyActivityModel> _recentDays = [];
  List<UserDailyActivityModel> get recentDays => _recentDays;

  Future<void> loadToday(String userId) async {
    await _service.ensureToday(userId);
    _today = await _service.getToday(userId);
    notifyListeners();
  }

  Future<void> increment(String userId, Map<String, dynamic> updates) async {
    await _service.incrementToday(userId, updates);
    await loadToday(userId);
  }

  Future<void> loadRecentDays(String userId, {int days = 14}) async {
    _recentDays = await _service.getRecentDays(userId, days: days);
    notifyListeners();
  }

  void clear() {
    _today = null;
    _recentDays = [];
    notifyListeners();
  }
}
