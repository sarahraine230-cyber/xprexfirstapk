import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';

enum VerificationPurpose { signup, recovery }

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String? email;
  final VerificationPurpose purpose;
  final bool autoResend;

  const EmailVerificationScreen({
    super.key, 
    this.email,
    this.purpose = VerificationPurpose.signup,
    this.autoResend = false,
  });

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController(); // For recovery
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // State to track if we verified the code and are now setting password
  bool _isSettingPassword = false;

  @override
  void initState() {
    super.initState();
    // Auto-resend if requested (e.g. from failed login)
    if (widget.autoResend) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resendCode());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    // If we are already in password setting mode, this submits the new password
    if (_isSettingPassword) {
      _handlePasswordUpdate();
      return;
    }

    final code = _codeController.text.trim();
    if (code.length < 8) {
      setState(() => _errorMessage = "Please enter the full 8-digit code");
      return;
    }

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
        
        // 2. INSTEAD OF DIALOG: Switch UI state to show Password Input
        // The router update ensures we stay on this screen despite being logged in.
        setState(() {
          _isLoading = false;
          _isSettingPassword = true; // This toggles the UI in build()
        });
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

  Future<void> _handlePasswordUpdate() async {
    final newPass = _newPasswordController.text;
    if (newPass.length < 6) {
      setState(() => _errorMessage = "Password must be at least 6 characters");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).updatePassword(newPass);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password updated!")));
      context.go('/'); // Now safe to go home
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to update password. Try again.";
          _isLoading = false;
        });
      }
    }
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
    
    // UI LOGIC: Are we verifying code OR setting password?
    final title = _isSettingPassword 
        ? "New Password" 
        : (widget.purpose == VerificationPurpose.signup ? "Verify Email" : "Reset Password");
        
    final desc = _isSettingPassword
        ? "Enter your new password below."
        : (widget.purpose == VerificationPurpose.signup 
            ? "Enter the code sent to ${widget.email ?? 'your email'}."
            : "Enter the code sent to ${widget.email ?? 'your email'} to reset your password.");

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isSettingPassword ? Icons.lock_reset : Icons.mark_email_unread_outlined, 
                size: 80, 
                color: theme.colorScheme.primary
              ),
              const SizedBox(height: 32),
              Text(title, style: theme.textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(desc, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
              
              const SizedBox(height: 48),
              
              // --- INPUT FIELD SWITCHER ---
              if (_isSettingPassword)
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "New Password",
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                )
              else
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  onChanged: (value) {
                    if (value.length == 8) _handleSubmit();
                  },
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 4, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: "00000000",
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
                  : Text(_isSettingPassword ? 'Save Password' : 'Verify Code'),
              ),
              
              if (!_isSettingPassword) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading ? null : _resendCode,
                  child: const Text('Resend Code'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
