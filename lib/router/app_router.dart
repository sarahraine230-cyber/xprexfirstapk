import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/screens/splash_screen.dart';
import 'package:xprex/screens/brand_splash_screen.dart';
import 'package:xprex/screens/login_screen.dart';
import 'package:xprex/screens/signup_screen.dart';
import 'package:xprex/screens/email_verification_screen.dart'; 
import 'package:xprex/screens/profile_setup_screen.dart';
import 'package:xprex/screens/main_shell.dart';
import 'package:xprex/screens/monetization_screen.dart';
import 'package:xprex/screens/user_profile_screen.dart';
import 'package:xprex/screens/monetization/video_earnings_screen.dart';
import 'package:xprex/screens/monetization/payout_history_screen.dart';
import 'package:xprex/screens/monetization/ad_manager_screen.dart';
import 'package:xprex/screens/verification_request_screen.dart';
import 'package:xprex/screens/bank_details_screen.dart';
import 'package:xprex/screens/reset_password_screen.dart'; // IMPORT NEW SCREEN

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authStateAsync = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: '/brand-splash',
    observers: [routeObserver],
    
    redirect: (context, state) {
      if (authStateAsync.isLoading || authStateAsync.hasError) {
        if (state.uri.path == '/splash' || state.uri.path == '/brand-splash') {
          return null;
        }
        return '/brand-splash';
      }

      final authState = authStateAsync.valueOrNull;
      final session = authState?.session;
      final isAuth = session != null;
      
      final isSplash = state.uri.path == '/splash';
      final isBrandSplash = state.uri.path == '/brand-splash';
      final isLogin = state.uri.path == '/login';
      final isSignup = state.uri.path == '/signup';
      final isVerify = state.uri.path == '/email-verification';
      final isReset = state.uri.path == '/reset-password'; // NEW CHECK

      // 1. Unauthenticated Users
      if (!isAuth) {
        if (isSplash || isBrandSplash || isLogin || isSignup || isVerify) return null;
        return '/brand-splash';
      }

      // 2. Authenticated Users
      
      // CRITICAL FIX: Allow Verification AND Reset Password screens.
      // This ensures users can finish the recovery flow without being kicked to Home.
      if (isVerify || isReset) return null;

      // Redirect splash/auth screens to Home
      if (isSplash || isLogin || isSignup) return '/';
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/brand-splash',
        builder: (context, state) => const BrandSplashScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/email-verification',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          return EmailVerificationScreen(
            email: args?['email'] as String?,
            purpose: args?['purpose'] as VerificationPurpose? ?? VerificationPurpose.signup,
            autoResend: args?['autoResend'] as bool? ?? false, 
          );
        },
      ),
      // --- NEW ROUTE ---
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => MainShell(key: mainShellKey),
      ),
      GoRoute(
        path: '/monetization',
        builder: (context, state) => const MonetizationScreen(),
      ),
      GoRoute(
        path: '/u/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null) return const SplashScreen();
          return UserProfileScreen(userId: id);
        },
      ),
      GoRoute(
        path: '/verify',
        builder: (context, state) => const VerificationRequestScreen(),
      ),
      GoRoute(
        path: '/setup/bank',
        builder: (context, state) => const BankDetailsScreen(),
      ),
      GoRoute(
        path: '/monetization/video-earnings',
        builder: (context, state) {
          final period = state.extra as String? ?? 'Monthly'; 
          return VideoEarningsScreen(period: period);
        },
      ),
      GoRoute(
        path: '/monetization/payout-history',
        builder: (context, state) => const PayoutHistoryScreen(),
      ),
      GoRoute(
        path: '/monetization/ad-manager',
        builder: (context, state) => const AdManagerScreen(),
      ),
    ],
  );
});
