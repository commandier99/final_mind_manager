import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../../features/authentication/datasources/providers/authentication_provider.dart';
import '../../services/firebase_messaging_service.dart';
import '../../services/deadline_reminder_service.dart';
import '../../features/users/datasources/providers/user_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  bool _showMindManager = false;
  bool _fadeOutInnovare = false;
  bool _bgIsWhite = false;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  Future<void> _startAnimation() async {
    // Show Innovare logo for 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // Fade out Innovare logo
    setState(() {
      _fadeOutInnovare = true;
    });
    
    // Wait for fade-out to finish, then switch background and fade in Mind Manager
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    setState(() {
      _bgIsWhite = true;
    });

    // Wait a bit for background transition before showing Mind Manager logo
    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    setState(() {
      _showMindManager = true;
    });

    // Keep Mind Manager logo on screen for 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    if (!mounted) return;

    // Request notification permission on app startup (non-blocking)
    unawaited(
      Permission.notification.status.then((status) {
        if (status.isDenied) {
          print('[SplashScreen] Requesting notification permission on app startup');
          Permission.notification.request().then((result) {
            print('[SplashScreen] Notification permission result: $result');
          });
        }
      }),
    );

    final authProvider = Provider.of<AuthenticationProvider>(
      context,
      listen: false,
    );

    // Wait for Firebase to restore the session from persistent storage
    final isAuthenticated = await authProvider.waitForAuthState();

    if (!mounted) return;

    if (isAuthenticated) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // Get current Firebase user and load their data
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        await userProvider.loadUserData(firebaseUser.uid);
        
        // Only register FCM token if user document exists in database
        if (userProvider.currentUser != null) {
          print('[SplashScreen] User loaded: ${userProvider.currentUser?.userId}');
          
          // Register FCM token only for existing users (prevents creating empty user docs)
          FirebaseMessagingService().registerTokenForUser(userProvider.currentUser!.userId);
          
          // Check for deadline reminders when app opens
            final deadlineReminderService = DeadlineReminderService(
              FirebaseMessagingService().localNotifications,
            );
            await deadlineReminderService.checkAndSendReminders();
            deadlineReminderService.startPeriodicReminders();
        } else {
          print('[SplashScreen] ⚠️ User document not found in database - skipping FCM registration');
        }
      }
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      color: _bgIsWhite ? Colors.white : Colors.black,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: _fadeOutInnovare ? 0 : 1,
              child: Image.asset(
                'assets/innovare_logo.jpg',
                height: 300,
                width: 300,
                fit: BoxFit.contain,
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: _showMindManager ? 1 : 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/mind_manager_logo.png',
                    height: 300,
                    width: 300,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
