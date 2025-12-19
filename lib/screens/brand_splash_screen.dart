import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/providers/auth_provider.dart';

/// Lightweight branding splash shown on every app open.
/// Uses the transparent logo asset for a seamless look.
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
      // FORCE BLACK BACKGROUND
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App mark - Uses the NEW transparent asset
              SizedBox(
                width: 120,
                height: 120,
                child: Image.asset(
                  // MAKE SURE YOU UPLOAD THIS FILE TO assets/images/
                  'assets/images/splash_logo.png', 
                  fit: BoxFit.contain,
                  // Fallback: If you haven't uploaded it yet, this prevents a crash 
                  // by showing an error icon instead of crashing the app.
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.error_outline, 
                    color: Colors.red, 
                    size: 50
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'XpreX',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 28,
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
