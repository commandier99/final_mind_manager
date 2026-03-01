import 'package:flutter/foundation.dart';
import '../models/poke_model.dart';
import '../services/poke_service.dart';
import '../../../../../features/notifications/datasources/helpers/notification_helper.dart';

class PokeProvider extends ChangeNotifier {
  final PokeService _pokeService = PokeService();

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  List<PokeModel> _createdPokes = const [];
  List<PokeModel> get createdPokes => _createdPokes;

  Future<void> createPoke({
    required PokeModel poke,
    String? notificationUserId,
    String? notificationTitle,
    String? relatedId,
    Map<String, dynamic>? notificationMetadata,
  }) async {
    _isSubmitting = true;
    notifyListeners();
    try {
      await _pokeService.createPoke(poke);

      final shouldNotifyNow =
          poke.timing == PokeModel.timingNow &&
          notificationUserId != null &&
          notificationUserId.isNotEmpty &&
          notificationUserId != 'None';

      if (shouldNotifyNow) {
        await NotificationHelper.createInAppOnly(
          userId: notificationUserId,
          title: notificationTitle ?? 'Poke',
          message: poke.message,
          category: NotificationHelper.categoryReminder,
          relatedId: relatedId,
          metadata: notificationMetadata,
        );
      }
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void streamCreatedByUser(String userId) {
    _pokeService.streamCreatedByUser(userId).listen((items) {
      _createdPokes = items;
      notifyListeners();
    });
  }
}

