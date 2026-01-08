import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../datasources/providers/authentication_provider.dart';

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final authProvider = Provider.of<AuthenticationProvider>(
      context,
      listen: false,
    );

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (_isSignUp) {
      await authProvider.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        userName: _usernameController.text.trim(),
        userHandle: _usernameController.text.trim(),
      );

      if (authProvider.error != null) {
        _showSnack(authProvider.error!);
        return;
      }

      // Signup successful - show verification message and switch to login mode
      _showSnack(
        'Account created! Please check your email to verify your account before logging in.',
      );

      // Switch to login mode
      setState(() {
        _isSignUp = false;
      });
      return;
    } else {
      await authProvider.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (authProvider.error != null) {
        _showSnack(authProvider.error!);
        return;
      }
    }

    _handleAuthResult(authProvider);
  }

  Future<void> _resendVerification() async {
    final authProvider = Provider.of<AuthenticationProvider>(
      context,
      listen: false,
    );
    await authProvider.resendVerificationEmail();

    if (!mounted) return;

    if (authProvider.error != null) {
      _showSnack(authProvider.error!);
    } else {
      _showSnack('Verification email sent!');
    }
  }

  void _handleAuthResult(AuthenticationProvider authProvider) {
    if (!mounted) return;

    if (authProvider.error != null) {
      _showSnack(authProvider.error!);
      return;
    }

    if (authProvider.isAuthenticated) {
      // Navigate immediately without showing snackbar to avoid deactivated widget error
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleGoogleSignIn(AuthenticationProvider authProvider) async {
    try {
      await authProvider.signInWithGoogle();

      // Check for email verification error
      if (authProvider.error != null &&
          authProvider.error!.contains('verify your email')) {
        _showSnack(authProvider.error!);
        return;
      }

      _handleAuthResult(authProvider);
    } catch (e) {
      // Check if it's an email verification error
      if (e.toString().contains('email-not-verified') ||
          e.toString().contains('verify your email')) {
        _showSnack(
          'Please check your email and verify your account before signing in.',
        );
      } else {
        _showSnack('Google sign-in failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthenticationProvider>(context);
    final isLoading = authProvider.isLoading;

    final showResendButton = !_isSignUp &&
        authProvider.firebaseUser != null &&
        !authProvider.firebaseUser!.emailVerified;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          _isSignUp ? 'Mind Manager | Sign Up' : 'Mind Manager | Sign In',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/mind_manager_logo.png',
                    height: 250,
                    width: 250,
                    fit: BoxFit.contain,
                  ),
                ),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (val) =>
                            val == null || val.isEmpty
                                ? 'Enter your email'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: (val) =>
                            val == null || val.isEmpty
                                ? 'Enter your password'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      if (_isSignUp) ...[
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                          ),
                          obscureText: _obscureConfirmPassword,
                          validator: (val) =>
                              val != _passwordController.text
                                  ? 'Passwords do not match'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (val) =>
                              val == null || val.isEmpty
                                  ? 'Enter a username'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isSignUp ? Colors.blue[800] : Colors.white,
                            foregroundColor: _isSignUp ? Colors.white : Colors.blue[800],
                            side: _isSignUp 
                              ? null 
                              : BorderSide(color: Colors.blue[800]!),
                          ),
                          child: isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _isSignUp ? Colors.white : Colors.blue[800],
                                  ),
                                )
                              : Text(
                                  _isSignUp ? 'Sign Up' : 'Sign In',
                                  style: const TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => setState(() => _isSignUp = !_isSignUp),
                        child: Text(
                          _isSignUp
                              ? 'Already have an account? Sign In'
                              : "Don't have an account? Sign Up",
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('OR'),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                await _handleGoogleSignIn(authProvider);
                              },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/google_logo.png',
                              height: 24,
                              width: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text('Continue with Google'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (showResendButton)
                        TextButton(
                          onPressed: isLoading ? null : _resendVerification,
                          child: const Text('Resend verification email'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
