import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/providers/auth_provider.dart';

/// Lightweight branding splash shown on every app open.
/// After a short delay, routes users based on auth state:
/// - Authenticated + verified => feed ('/')
/// - Authenticated + unverified => '/email-verification'
/// - Not authenticated => '/splash' (existing welcome/onboarding screen)
class BrandSplashScreen extends ConsumerStatefulWidget {
  const BrandSplashScreen({super.key});

  @override
  ConsumerState<BrandSplashScreen> createState() => _BrandSplashScreenState();
}

class _BrandSplashScreenState extends ConsumerState<BrandSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();

    // Small brand pause before routing
    _timer = Timer(const Duration(seconds: 2), _routeNext);
  }

  void _routeNext() {
    final auth = ref.read(authServiceProvider);
    try {
      if (auth.isAuthenticated) {
        if (auth.isEmailVerified()) {
          if (!mounted) return;
          context.go('/');
        } else {
          if (!mounted) return;
          context.go('/email-verification');
        }
      } else {
        if (!mounted) return;
        // Show existing welcome SplashScreen next for logged-out users
        context.go('/splash');
      }
    } catch (e) {
      if (!mounted) return;
      // Fallback
      context.go('/splash');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App mark
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.12),
                      theme.colorScheme.tertiary.withValues(alpha: 0.12),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Image.asset(
                  'assets/images/edgy_tech_monogram_X_logo_sharp_angles_vibrant_gradient_turquoise_1763918747193.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'XpreX',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
