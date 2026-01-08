import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/features/users/datasources/models/user_model.dart';
import '../../../../shared/features/users/datasources/services/user_services.dart';

class AuthenticationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  // Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign up with email and password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String userName,
    required String userHandle,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Create user document in Firestore using UserModel and UserService
    if (userCredential.user != null) {
      final newUser = UserModel(
        userId: userCredential.user!.uid,
        userEmail: email,
        userName: userName,
        userHandle: userHandle,
        userCreatedAt: Timestamp.now(),
        userIsVerified: false,
        userIsPublic: false,
        userAllowSearch: false,
        userIsActive: true,
        userIsBanned: false,
        userLocale: 'en',
        userTimezone: 'UTC',
      );
      
      await _userService.saveUser(newUser);
      print('✅ [AuthenticationService] User created with UserModel and UserService');
    }

    return userCredential;
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Check if user is signed in
  bool isUserSignedIn() {
    return _auth.currentUser != null;
  }

  // Stream of auth state changes
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}
