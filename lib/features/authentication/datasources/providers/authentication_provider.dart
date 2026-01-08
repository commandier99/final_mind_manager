import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/authentication_service.dart';
import '../../../../shared/features/users/datasources/models/user_model.dart';
import '../../../../shared/features/users/datasources/services/user_services.dart';

class AuthenticationProvider extends ChangeNotifier {
  final AuthenticationService _authService = AuthenticationService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final UserService _userService = UserService();

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
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _setLoading(false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      _user = userCredential.user;

      if (_user != null) {
        // Check if user document exists, if not create it
        final existingUser = await _userService.getUserById(_user!.uid);
        if (existingUser == null) {
          // Create user document for Google sign-in users
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
          print('✅ [AuthenticationProvider] Created user document for Google sign-in');
        }

        // Trigger UserProvider to load user data
        onUserAuthenticated?.call(_user!.uid);
        print('✅ [AuthenticationProvider] Google sign-in successful, triggering user data load');
      }
    } catch (e) {
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
