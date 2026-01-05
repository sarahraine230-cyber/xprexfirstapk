import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/models/video_model.dart';
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
import 'package:xprex/screens/verification_personal_info_screen.dart'; // NEW
import 'package:xprex/screens/reset_password_screen.dart';
import 'package:xprex/screens/single_video_screen.dart'; 
import 'package:xprex/screens/video_player_screen.dart';

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authService = ref.read(authServiceProvider);
  
  return GoRouter(
    initialLocation: '/brand-splash',
    observers: [routeObserver],
    refreshListenable: GoRouterRefreshStream(authService.authStateChanges),
    
    redirect: (context, state) {
      // --- DEEP LINK NORMALIZATION ---
      if (state.uri.scheme == 'xprex') {
        // 1. VIDEO LINK: xprex://video/123 -> /video/123
        if (state.uri.host == 'video') {
          return '/video${state.uri.path}';
        }
        // 2. PROFILE LINK: xprex://u/123 -> /u/123
        if (state.uri.host == 'u') {
          return '/u${state.uri.path}';
        }
      }

      final isAuth = authService.isAuthenticated;
      
      final isSplash = state.uri.path == '/splash';
      final isBrandSplash = state.uri.path == '/brand-splash';
      
      final isLogin = state.uri.path == '/login';
      final isSignup = state.uri.path == '/signup';
      final isVerify = state.uri.path == '/email-verification';
      final isReset = state.uri.path == '/reset-password';
      
      final isDeepLink = state.uri.path.startsWith('/video/');
      final isProfileLink = state.uri.path.startsWith('/u/');

      if (!isAuth) {
        if (isSplash || isBrandSplash || isLogin || isSignup || isVerify || isDeepLink || isProfileLink) {
          return null;
        }
        return '/brand-splash';
      }

      if (isVerify || isReset || isDeepLink || isProfileLink) return null;
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
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/video/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null) return const MainShell(); 
          return SingleVideoScreen(videoId: id);
        },
      ),
      GoRoute(
        path: '/video-player',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>;
          return VideoPlayerScreen(
            videos: args['videos'] as List<VideoModel>,
            initialIndex: args['index'] as int,
            repostContextUsername: args['repostContextUsername'] as String?,
          );
        },
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
      // --- NEW: PERSONAL INFO STEP ---
      GoRoute(
        path: '/setup/personal',
        builder: (context, state) => const VerificationPersonalInfoScreen(),
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
