import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/authentication_service.dart';
import '../../../../shared/features/users/datasources/models/user_model.dart';
import '../../../../shared/features/users/datasources/services/user_services.dart';
import '../../../../../../features/boards/datasources/services/board_services.dart';

class AuthenticationProvider extends ChangeNotifier {
  final AuthenticationService _authService = AuthenticationService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final UserService _userService = UserService();
  final BoardService _boardService = BoardService();

  User? _user;
  bool _isLoading = false;
  String? _error;

  // Callback to notify when user data needs to be loaded
  Function(String userId)? onUserAuthenticated;

  User? get firebaseUser => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null && _user!.emailVerified;

  AuthenticationProvider() {
    _initAuth();
  }

  void _initAuth() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final userCredential = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      _user = userCredential.user;

      if (_user != null && !_user!.emailVerified) {
        _error = 'Please verify your email before signing in.';
        await FirebaseAuth.instance.signOut();
        _user = null;
      } else if (_user != null) {
        // Trigger UserProvider to load user data
        onUserAuthenticated?.call(_user!.uid);
        print('✅ [AuthenticationProvider] User signed in, triggering user data load');
      }
    } catch (e) {
      _error = _getErrorMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String userName,
    required String userHandle,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final userCredential = await _authService.signUpWithEmail(
        email: email,
        password: password,
        userName: userName,
        userHandle: userHandle,
      );

      _user = userCredential.user;

      // Send verification email
      if (_user != null && !_user!.emailVerified) {
        await _user!.sendEmailVerification();
        // Sign out user until they verify
        await FirebaseAuth.instance.signOut();
        _user = null;
      }
    } catch (e) {
      _error = _getErrorMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signInWithGoogle() async {
    _setLoading(true);
    _error = null;

    try {
      print('🔵 [AuthenticationProvider] Starting Google Sign-In...');
      // Sign out first to force the account picker to show
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('⚠️ [AuthenticationProvider] Google Sign-In cancelled by user');
        _setLoading(false);
        return;
      }

      print('🔵 [AuthenticationProvider] Getting Google authentication...');
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      print('🔵 [AuthenticationProvider] Creating Firebase credential...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('🔵 [AuthenticationProvider] Signing in to Firebase...');
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      _user = userCredential.user;
      print('🔵 [AuthenticationProvider] Firebase sign-in complete. User: ${_user?.email}');

      if (_user != null) {
        // Check if user document already exists to determine if this is a new user
        print('🔵 [AuthenticationProvider] Checking if user document exists...');
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .get();
        final isNewUser = !userDoc.exists;
        
        // Always create/update user document for Google sign-in users
        print('🔵 [AuthenticationProvider] Creating/updating user document...');
        try {
          final newUser = UserModel(
            userId: _user!.uid,
            userEmail: _user!.email!,
            userName: _user!.displayName ?? 'User',
            userHandle: _user!.email!.split('@')[0],
            userCreatedAt: Timestamp.now(),
            userIsVerified: _user!.emailVerified,
            userProfilePicture: _user!.photoURL,
            userIsPublic: false,
            userAllowSearch: false,
            userIsActive: true,
            userIsBanned: false,
            userLocale: 'en',
            userTimezone: 'UTC',
          );
          await _userService.saveUser(newUser);
          print('✅ [AuthenticationProvider] User document and userStats saved for Google sign-in');
          
          // Only create a default "Personal" board for NEW users
          if (isNewUser) {
            try {
              await _boardService.addBoard(
                boardTitle: 'Personal',
                boardGoal: 'Personal tasks and projects',
                boardGoalDescription: 'A space to manage your personal tasks and projects',
              );
              print('✅ [AuthenticationProvider] Personal board created for NEW Google user ${_user!.uid}');
            } catch (e) {
              print('⚠️ [AuthenticationProvider] Error creating Personal board: $e');
              // Don't throw - user account was created successfully
            }
          } else {
            print('ℹ️ [AuthenticationProvider] Existing user, skipping Personal board creation');
          }
        } catch (e) {
          print('❌ [AuthenticationProvider] Error creating user document: $e');
          _error = 'Failed to create user profile: $e';
          return;
        }

        // Trigger UserProvider to load user data
        onUserAuthenticated?.call(_user!.uid);
        print('✅ [AuthenticationProvider] Google sign-in successful, triggering user data load');
      }
    } catch (e, stackTrace) {
      print('❌ [AuthenticationProvider] Google Sign-In error: $e');
      print('❌ [AuthenticationProvider] Stack trace: $stackTrace');
      _error = _getErrorMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resendVerificationEmail() async {
    _setLoading(true);
    _error = null;

    try {
      if (_user != null) {
        await _user!.sendEmailVerification();
      } else {
        _error = 'No user found. Please sign in again.';
      }
    } catch (e) {
      _error = _getErrorMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      await _googleSignIn.signOut();
      _user = null;
      _error = null;
    } catch (e) {
      _error = _getErrorMessage(e);
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'invalid-email':
          return 'The email address is invalid.';
        case 'weak-password':
          return 'The password is too weak.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        default:
          return error.message ?? 'An authentication error occurred.';
      }
    }
    return error.toString();
  }
}
