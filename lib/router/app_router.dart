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
// --- NEW IMPORTS FOR CREATOR ONBOARDING ---
import 'package:xprex/screens/verification_request_screen.dart';
import 'package:xprex/screens/bank_details_screen.dart';

final RouteObserver<PageRoute<dynamic>> routeObserver = RouteObserver<PageRoute<dynamic>>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: '/brand',
    observers: [routeObserver],
    redirect: (context, state) {
      final path = state.uri.path;
      
      return authState.when(
        data: (auth) {
          final isAuthenticated = auth.session != null;
          final isEmailVerified = auth.session?.user.emailConfirmedAt != null;
          
          // Allow brand and splash routes for all users
          final isAllowedPublic = path == '/brand' || path == '/splash';

          if (!isAuthenticated && !path.startsWith('/login') && !path.startsWith('/signup') && !isAllowedPublic) {
            return '/login';
          }
          
          if (isAuthenticated && !isEmailVerified && path != '/email-verification') {
            return '/email-verification';
          }
          
          return null;
        },
        loading: () => null,
        error: (_, __) => '/login',
      );
    },
    routes: [
      GoRoute(
        path: '/brand',
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
        builder: (context, state) => const EmailVerificationScreen(),
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
          if (id == null) {
            return const SplashScreen();
          }
          return UserProfileScreen(userId: id);
        },
      ),
      // --- NEW CREATOR ONBOARDING ROUTES ---
      GoRoute(
        path: '/verify',
        builder: (context, state) => const VerificationRequestScreen(),
      ),
      GoRoute(
        path: '/setup/bank',
        builder: (context, state) => const BankDetailsScreen(),
      ),
      // --- MONETIZATION VIDEO SCREEN ROUTE ---
      GoRoute(
        path: '/monetization/video-earnings',
        builder: (context, state) {
          // We extract the 'period' string passed as an object
          final period = state.extra as String; 
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
