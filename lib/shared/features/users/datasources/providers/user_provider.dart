import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/user_services.dart';
import 'package:mind_manager_final/features/notifications/datasources/services/push_messaging_service.dart';

class UserProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  bool get isLoggedIn => _auth.currentUser != null;
  bool get hasUserData => _currentUser != null;

  // Getter to directly access userId
  String? get userId => _currentUser?.userId;

  UserProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      notifyListeners();
    } else {
      await loadUserData(firebaseUser.uid);
      await PushMessagingService().registerTokenForUser(firebaseUser.uid);
    }
  }

  Future<void> loadUserData(String userId) async {
    try {
      _currentUser = await _userService.getUserById(userId);
    } catch (e) {
      if (kDebugMode) print('⚠️ [UserProvider] Error loading user data: $e');
      _currentUser = null;
    }
    notifyListeners();
  }

  Future<void> refreshUserData() async {
    final user = _auth.currentUser;
    print('[DEBUG] UserProvider.refreshUserData: currentUser = \\${user?.uid}');
    if (user != null) {
      await loadUserData(user.uid);
      print('[DEBUG] UserProvider.refreshUserData: loadUserData complete for userId = \\${user.uid}');
    } else {
      print('[DEBUG] UserProvider.refreshUserData: No user is currently signed in.');
    }
  }

  Future<void> updateUserData(UserModel updatedUser) async {
    try {
      await _userService.saveUser(updatedUser);
      _currentUser = updatedUser;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('⚠️ [UserProvider] Error updating user data: $e');
    }
  }

  Future<void> togglePublicProfile(bool isPublic) async {
    if (_currentUser == null) return;
    
    // Store the previous state in case we need to revert
    final previousState = _currentUser!.userIsPublic;
    
    try {
      // Optimistically update the UI
      _currentUser = _currentUser!.copyWith(
        userIsPublic: isPublic,
        userAllowSearch: isPublic,
      );
      notifyListeners();
      
      // Then update the database
      await _userService.updateUserFields(_currentUser!.userId, {
        'userIsPublic': isPublic,
        'userAllowSearch': isPublic,
      });
      
      if (kDebugMode) print('🌐 [UserProvider] Public visibility updated → $isPublic');
    } catch (e) {
      if (kDebugMode) print('⚠️ [UserProvider] Error toggling public profile: $e');
      
      // Revert to previous state on failure
      _currentUser = _currentUser!.copyWith(
        userIsPublic: previousState,
        userAllowSearch: previousState,
      );
      notifyListeners();
      
      rethrow;
    }
  }

  Future<void> markAsVerified() async {
    if (_currentUser == null) return;
    try {
      await _userService.markUserAsVerified(_currentUser!.userId);
      await refreshUserData();
    } catch (e) {
      if (kDebugMode) print('⚠️ [UserProvider] Error marking user verified: $e');
    }
  }

  Future<void> deleteAccount() async {
    if (_currentUser == null) return;
    try {
      final userId = _currentUser!.userId;
      
      print('[DEBUG] UserProvider: Starting account deletion for user $userId');
      
      // Delete all user data from Firestore FIRST (while still authenticated)
      try {
        await _userService.deleteUserAccount(userId);
        print('[DEBUG] UserProvider: Firestore data deleted successfully');
      } catch (firestoreError) {
        print('⚠️ [UserProvider] Error deleting Firestore data: $firestoreError');
        // Continue to delete auth account even if Firestore deletion fails
        // This prevents the user from being stuck
      }
      
      // Delete Firebase Auth account AFTER Firestore data
      try {
        await _auth.currentUser?.delete();
        print('[DEBUG] UserProvider: Firebase Auth account deleted successfully');
      } catch (authError) {
        print('⚠️ [UserProvider] Error deleting Firebase Auth account: $authError');
        // If auth deletion fails, at least sign out
        await signOut();
      }
      
      // Clear local state
      _currentUser = null;
      notifyListeners();
      
      if (kDebugMode) print('✅ [UserProvider] Account deletion completed');
    } catch (e) {
      if (kDebugMode) print('⚠️ [UserProvider] Error deleting account: $e');
      rethrow;
    }
  }

  /// Get profile picture for a specific user by ID
  Future<String?> getUserProfilePicture(String userId) async {
    try {
      final user = await _userService.getUserById(userId);
      return user?.userProfilePicture;
    } catch (e) {
      if (kDebugMode) print('⚠️ [UserProvider] Error getting user profile picture: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }
}
