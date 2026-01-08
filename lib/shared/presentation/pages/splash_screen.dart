import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../features/authentication/datasources/providers/authentication_provider.dart';

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

    final authProvider = Provider.of<AuthenticationProvider>(
      context,
      listen: false,
    );

    // Check if user is authenticated and email is verified
    if (authProvider.isAuthenticated) {
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
