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
    try {
      final authService = ref.read(authServiceProvider);
      final profileService = ref.read(profileServiceProvider);

      // Give a small delay to let the animation play (optional UX choice)
      await Future.delayed(const Duration(milliseconds: 800));

      if (authService.isAuthenticated && authService.isEmailVerified()) {
        try {
          final uid = authService.currentUserId!;
          final email = authService.currentUser!.email ?? 'user@example.com';
          
          // CORRECTED: Matches ProfileService definition
          await profileService.ensureProfileExists(authUserId: uid, email: email);
        } catch (e) {
          debugPrint('Profile check warning: $e');
          // We continue even if this fails, to avoid locking the user out
        }
        
        if (!mounted) return;
        context.go('/');
      } else if (authService.isAuthenticated && !authService.isEmailVerified()) {
        if (!mounted) return;
        context.go('/verify-email');
      } else {
         // User is not logged in; stay on splash/welcome screen
      }
    } catch (e) {
      debugPrint('Splash check error: $e');
    } finally {
      if (mounted) setState(() => _checkedAuth = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, theme.colorScheme.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(seconds: 1),
                    opacity: _animateIn ? 1.0 : 0.0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo Placeholder
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            ]
                          ),
                          child: const Icon(Icons.play_arrow_rounded, size: 60, color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        _GradientText(
                          'XpreX',
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                          colors: [Colors.white, theme.colorScheme.primaryContainer],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Unleash Your Creativity',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white70,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Bottom Action Area
              if (_checkedAuth) 
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: 200,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    if (!ref.read(authServiceProvider).isAuthenticated) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: () => context.push('/signup'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          child: const Text('Get Started'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () => context.push('/login'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          child: const Text('I already have an account'),
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
