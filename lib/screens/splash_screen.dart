import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _checkedAuth = false;
  bool _animateIn = false;

  @override
  void initState() {
    super.initState();
    _checkAndNavigate();
    // Trigger entrance animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _animateIn = true);
    });
  }

  Future<void> _checkAndNavigate() async {
    // If user already authenticated, skip welcome UI and route accordingly
    try {
      final authService = ref.read(authServiceProvider);
      final profileService = ref.read(profileServiceProvider);

      if (authService.isAuthenticated && authService.isEmailVerified()) {
        // Ensure a minimal profile exists immediately for new accounts
        try {
          final uid = authService.currentUserId!;
          final email = authService.currentUser!.email ?? 'user@example.com';
          await profileService.ensureProfileExists(authUserId: uid, email: email);
        } catch (e) {
          // Non-fatal; fall through
        }
        if (!mounted) return;
        context.go('/');
      } else if (authService.isAuthenticated && !authService.isEmailVerified()) {
        if (!mounted) return;
        context.go('/email-verification');
      } else {
        // Not authenticated -> show welcome UI
        if (mounted) setState(() => _checkedAuth = true);
      }
    } catch (_) {
      if (mounted) setState(() => _checkedAuth = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top-left minimal logo
              _GradientText(
                'XpreX',
                style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.tertiary,
                ],
              ),
              const SizedBox(height: 16),
              // Tagline / description
              AnimatedOpacity(
                opacity: _animateIn ? 1 : 0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                child: Text(
                  "Dont just create. Xprex! Join Nigeria’s creator hub built for storytellers, thinkers, and visionaries. We reward quality — not clicks. Share what matters, and grow in a community that values real expression.",
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
              const Spacer(),
              // Buttons with slide-in animation
              AnimatedSlide(
                offset: _animateIn ? Offset.zero : const Offset(0, 0.1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOut,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_checkedAuth) ...[
                      // Create Account
                      FilledButton.icon(
                        onPressed: () => context.go('/signup'),
                        icon: Icon(Icons.bolt_rounded, color: theme.colorScheme.onTertiary),
                        label: Text(
                          'Create Account',
                          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onTertiary),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          backgroundColor: theme.colorScheme.tertiary,
                          foregroundColor: theme.colorScheme.onTertiary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // I already have an account
                      OutlinedButton.icon(
                        onPressed: () => context.go('/login'),
                        icon: Icon(Icons.login_rounded, color: theme.colorScheme.onSurface),
                        label: Text(
                          'I already have an account',
                          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.2), width: 1.2),
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          foregroundColor: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'By continuing, you agree to our Terms and Privacy Policy',
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(color: theme.colorScheme.primary),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple gradient text widget for logo styling
class _GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final List<Color> colors;

  const _GradientText(this.text, {required this.style, required this.colors});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(text, style: style?.copyWith(color: Colors.white)),
    );
  }
}
