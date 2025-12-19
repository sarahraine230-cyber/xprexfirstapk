import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/providers/auth_provider.dart';

/// Lightweight branding splash shown on every app open.
/// After a short delay, routes users based on auth state.
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
    return Scaffold(
      // FORCE BLACK BACKGROUND (Non-negotiable)
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App mark - Clean, no container box
              SizedBox(
                width: 120,
                height: 120,
                child: Image.asset(
                  'assets/images/edgy_tech_monogram_X_logo_sharp_angles_vibrant_gradient_turquoise_1763918747193.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'XpreX',
                style: TextStyle(
                  fontFamily: 'Inter', // Ensuring font consistency
                  fontSize: 28, // Matches headlineMedium size roughly
                  fontWeight: FontWeight.w800,
                  color: Colors.white, // Force White text
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
