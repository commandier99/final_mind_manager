import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/user_model.dart';
import '../services/user_services.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();
  StreamSubscription<User?>? _authSubscription;
  DateTime? _lastActivitySyncAt;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  bool get isLoggedIn => _auth.currentUser != null;
  bool get hasUserData => _currentUser != null;

  // Getter to directly access userId.
  String? get userId => _currentUser?.userId;

  String _currentLocaleTag() {
    return WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();
  }

  String _currentTimezoneOffsetLabel() {
    final offset = DateTime.now().timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final totalMinutes = offset.inMinutes.abs();
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hours:$minutes';
  }

  UserProvider() {
    _authSubscription = _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      notifyListeners();
      return;
    }

    await loadUserData(firebaseUser.uid);

    if (_currentUser != null) {
      await markUserActive(force: true);
    }
  }

  Future<void> loadUserData(String userId) async {
    try {
      _currentUser = await _userService.getUserById(userId);
    } catch (e) {
      _log('[UserProvider] Error loading user data: $e');
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<void> refreshUserData() async {
    final user = _auth.currentUser;
    _log('[DEBUG] UserProvider.refreshUserData: currentUser = ${user?.uid}');
    if (user != null) {
      await loadUserData(user.uid);
      _log(
        '[DEBUG] UserProvider.refreshUserData: loadUserData complete for userId = ${user.uid}',
      );
    } else {
      _log(
        '[DEBUG] UserProvider.refreshUserData: No user is currently signed in.',
      );
    }
  }

  Future<void> updateUserData(UserModel updatedUser) async {
    try {
      await _userService.saveUser(updatedUser);
      _currentUser = updatedUser;
      notifyListeners();
    } catch (e) {
      _log('[UserProvider] Error updating user data: $e');
    }
  }

  Future<void> togglePublicProfile(bool isPublic) async {
    if (_currentUser == null) return;

    final previousState = _currentUser!.userIsPublic;
    final previousSearchState = _currentUser!.userAllowSearch;

    try {
      _currentUser = _currentUser!.copyWith(
        userIsPublic: isPublic,
        userAllowSearch: isPublic,
      );
      notifyListeners();

      await _userService.updateUserFields(_currentUser!.userId, {
        'userIsPublic': isPublic,
        'userAllowSearch': isPublic,
      });

      _log('Public visibility updated -> $isPublic');
    } catch (e) {
      _log('[UserProvider] Error toggling public profile: $e');

      _currentUser = _currentUser!.copyWith(
        userIsPublic: previousState,
        userAllowSearch: previousSearchState,
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> setAllowSearch(bool allowSearch) async {
    if (_currentUser == null) return;

    final previousPublic = _currentUser!.userIsPublic;
    final previous = _currentUser!.userAllowSearch;
    try {
      _currentUser = _currentUser!.copyWith(
        userAllowSearch: allowSearch,
        userIsPublic: allowSearch,
      );
      notifyListeners();
      await _userService.updateUserFields(_currentUser!.userId, {
        'userAllowSearch': allowSearch,
        'userIsPublic': allowSearch,
      });
    } catch (e) {
      _currentUser = _currentUser!.copyWith(
        userAllowSearch: previous,
        userIsPublic: previousPublic,
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateUserFields(Map<String, dynamic> updates) async {
    if (_currentUser == null || updates.isEmpty) return;

    await _userService.updateUserFields(_currentUser!.userId, updates);
    await refreshUserData();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No authenticated user found.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  Future<void> markAsVerified() async {
    if (_currentUser == null) return;

    try {
      await _userService.markUserAsVerified(_currentUser!.userId);
      await refreshUserData();
    } catch (e) {
      _log('[UserProvider] Error marking user verified: $e');
    }
  }

  Future<void> deleteAccount() async {
    if (_currentUser == null) return;

    try {
      final userId = _currentUser!.userId;
      _log('[DEBUG] UserProvider: Starting account deletion for user $userId');

      try {
        await _userService.deleteUserAccount(userId);
        _log('[DEBUG] UserProvider: Firestore data deleted successfully');
      } catch (firestoreError) {
        _log('[UserProvider] Error deleting Firestore data: $firestoreError');
      }

      try {
        await _auth.currentUser?.delete();
        _log(
          '[DEBUG] UserProvider: Firebase Auth account deleted successfully',
        );
      } catch (authError) {
        _log('[UserProvider] Error deleting Firebase Auth account: $authError');
        await signOut();
      }

      _currentUser = null;
      notifyListeners();

      _log('[UserProvider] Account deletion completed');
    } catch (e) {
      _log('[UserProvider] Error deleting account: $e');
      rethrow;
    }
  }

  Future<String?> getUserProfilePicture(String userId) async {
    try {
      final user = await _userService.getUserById(userId);
      return user?.userProfilePicture;
    } catch (e) {
      _log('[UserProvider] Error getting user profile picture: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    _lastActivitySyncAt = null;
    notifyListeners();
  }

  Future<void> markUserActive({bool force = false}) async {
    if (_currentUser == null) return;

    final now = DateTime.now();
    if (!force && _lastActivitySyncAt != null) {
      final elapsed = now.difference(_lastActivitySyncAt!);
      if (elapsed < const Duration(minutes: 1)) {
        return;
      }
    }

    final updates = <String, dynamic>{
      'userLastActiveAt': FieldValue.serverTimestamp(),
    };

    final locale = _currentLocaleTag();
    final timezone = _currentTimezoneOffsetLabel();
    if (_currentUser!.userLocale != locale) {
      updates['userLocale'] = locale;
    }
    if (_currentUser!.userTimezone != timezone) {
      updates['userTimezone'] = timezone;
    }

    try {
      await _userService.updateUserFields(_currentUser!.userId, updates);
      _lastActivitySyncAt = now;
      _currentUser = _currentUser!.copyWith(
        userLastActiveAt: Timestamp.fromDate(now),
        userLocale: updates['userLocale'] ?? _currentUser!.userLocale,
        userTimezone: updates['userTimezone'] ?? _currentUser!.userTimezone,
      );
      notifyListeners();
    } catch (e) {
      _log('[UserProvider] Error marking user active: $e');
    }
  }
}
