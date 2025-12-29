import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/screens/email_verification_screen.dart'; // For Enum access
import 'package:xprex/theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- ERROR PARSER (Preserved) ---
  String _getFriendlyErrorMessage(Object error) {
    final e = error.toString().toLowerCase();
    if (e.contains('socket') || e.contains('errno = 7') || e.contains('connection refused') || e.contains('network request failed')) {
      return 'No internet connection.\nPlease check your mobile data or Wi-Fi.';
    }
    if (e.contains('timeout')) return 'Connection timed out.\nPlease try again.';
    if (error is AuthException) {
      if (error.message.toLowerCase().contains('invalid login credentials')) return 'Incorrect email or password.';
      if (error.message.toLowerCase().contains('email not confirmed')) return 'Please verify your email address before logging in.';
    }
    if (e.contains('invalid login credentials')) return 'Incorrect email or password.';
    if (e.contains('user not found')) return 'No account found with this email.';
    return 'Unable to log in. Please try again later.';
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;

      if (authService.isEmailVerified()) {
        final profileService = ref.read(profileServiceProvider);
        final profile = await profileService.getProfileByAuthId(authService.currentUserId!);
        if (profile == null) {
          context.go('/profile-setup');
        } else {
          context.go('/');
        }
      } else {
         // Pass email to verification screen
         context.push(
            '/email-verification',
            extra: {
              'email': _emailController.text.trim(),
              'purpose': VerificationPurpose.signup,
            },
          );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getFriendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  // --- FORGOT PASSWORD SHEET ---
  void _showForgotPasswordSheet() {
    final emailCtrl = TextEditingController(text: _emailController.text); // Pre-fill if they typed it
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, 
          top: 24, left: 24, right: 24
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Reset Password", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text("Enter your email to receive a recovery code."),
            const SizedBox(height: 20),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Email Address",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty || !email.contains('@')) return;
                
                Navigator.pop(ctx); // Close sheet
                _sendResetCode(email);
              },
              child: const Text("Send Code"),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _sendResetCode(String email) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).sendPasswordResetOtp(email);
      if (!mounted) return;
      
      // Navigate to Verification in RECOVERY mode
      context.push(
        '/email-verification',
        extra: {
          'email': email,
          'purpose': VerificationPurpose.recovery,
        },
      );
    } catch (e) {
      setState(() => _errorMessage = "Failed to send code. Please try again.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                Icon(Icons.play_circle_filled, size: 80, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text('Welcome Back', style: theme.textTheme.displaySmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text('Log in to continue', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                const SizedBox(height: 48),
                
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Email is required';
                    if (!value.contains('@')) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Password is required';
                    return null;
                  },
                ),
                
                // FORGOT PASSWORD BUTTON
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _showForgotPasswordSheet,
                    child: const Text("Forgot Password?"),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 20, color: theme.colorScheme.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!, 
                            style: TextStyle(color: theme.colorScheme.onErrorContainer, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                    : Text('Log In', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimary)),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Don\'t have an account? ', style: theme.textTheme.bodyMedium),
                    TextButton(
                      onPressed: () => context.go('/signup'),
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
