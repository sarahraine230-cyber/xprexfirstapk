import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';

enum VerificationPurpose { signup, recovery }

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String? email;
  final VerificationPurpose purpose;

  const EmailVerificationScreen({
    super.key, 
    this.email,
    this.purpose = VerificationPurpose.signup, // Default to signup
  });

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final code = _codeController.text.trim();
    // CHANGED: Expecting 8 digits now
    if (code.length < 8) {
      // Only show error if triggered manually (via button)
      // If auto-triggered, the length check is implicit.
      setState(() => _errorMessage = "Please enter the full 8-digit code");
      return;
    }

    // Prevent double submission
    if (_isLoading) return;

    setState(() { _isLoading = true; _errorMessage = null; });
    final authService = ref.read(authServiceProvider);

    try {
      if (widget.purpose == VerificationPurpose.signup) {
        // --- SIGNUP FLOW ---
        await authService.verifySignupOtp(
          email: widget.email!, 
          token: code,
        );
        if (!mounted) return;
        context.go('/profile-setup');
      
      } else {
        // --- RECOVERY FLOW ---
        // 1. Verify code (this logs user in)
        await authService.verifyRecoveryOtp(
          email: widget.email!,
          token: code,
        );
        
        // 2. Prompt for New Password
        if (!mounted) return;
        _showNewPasswordDialog();
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Invalid code. Please try again.";
          _isLoading = false;
        });
      }
    }
  }

  void _showNewPasswordDialog() {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Reset Password"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Code verified! Enter your new password."),
            const SizedBox(height: 16),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "New Password",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (passCtrl.text.length < 6) return;
              Navigator.pop(ctx); // Close dialog
              
              try {
                // 3. Update Password
                await ref.read(authServiceProvider).updatePassword(passCtrl.text);
                if (!mounted) return;
                
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated! Logging you in...")));
                context.go('/'); // Go to Home
              } catch (e) {
                 if (mounted) {
                   setState(() {
                     _errorMessage = "Failed to update password. Try again.";
                     _isLoading = false;
                   });
                 }
              }
            },
            child: const Text("Save & Login"),
          )
        ],
      ),
    );
  }

  Future<void> _resendCode() async {
    setState(() => _isLoading = true);
    try {
      if (widget.purpose == VerificationPurpose.signup) {
        await ref.read(authServiceProvider).resendVerificationEmail(email: widget.email);
      } else {
        await ref.read(authServiceProvider).sendPasswordResetOtp(widget.email!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code resent!')));
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Failed to resend code.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.purpose == VerificationPurpose.signup ? "Verify Email" : "Reset Password";
    final desc = widget.purpose == VerificationPurpose.signup 
        ? "Enter the code sent to ${widget.email ?? 'your email'} to verify your account."
        : "Enter the code sent to ${widget.email ?? 'your email'} to reset your password.";

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mark_email_unread_outlined, size: 80, color: theme.colorScheme.primary),
              const SizedBox(height: 32),
              Text(title, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(desc, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
              
              const SizedBox(height: 48),
              
              // CODE INPUT
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 8, // CHANGED from 6 to 8
                onChanged: (value) {
                  // NEW: Auto-submit when 8 digits are reached
                  if (value.length == 8) {
                    _handleSubmit();
                  }
                },
                textAlign: TextAlign.center,
                // CHANGED: Reduced letterSpacing to fit 8 digits (was 8, now 4)
                style: const TextStyle(fontSize: 24, letterSpacing: 4, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "00000000", // CHANGED to 8 zeros
                  counterText: "",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
              ],

              const SizedBox(height: 32),
              
              FilledButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                  : const Text('Verify Code'),
              ),
              
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: _isLoading ? null : _resendCode,
                child: const Text('Resend Code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
