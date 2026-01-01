import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/models/video_model.dart'; // Needed for casting
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
import 'package:xprex/screens/reset_password_screen.dart';
import 'package:xprex/screens/single_video_screen.dart'; 
import 'package:xprex/screens/video_player_screen.dart'; // NEW IMPORT

// 1. GLOBAL OBSERVER
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

// 2. STREAM LISTENER CLASS (Keeps Router alive on Auth Change)
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
      // --- 1. DEEP LINK NORMALIZATION ---
      if (state.uri.scheme == 'xprex') {
        if (state.uri.host == 'video') {
          return '/video${state.uri.path}'; // Returns "/video/123"
        }
      }

      final isAuth = authService.isAuthenticated;
      
      final isSplash = state.uri.path == '/splash';
      final isBrandSplash = state.uri.path == '/brand-splash';
      final isLogin = state.uri.path == '/login';
      final isSignup = state.uri.path == '/signup';
      final isVerify = state.uri.path == '/email-verification';
      final isReset = state.uri.path == '/reset-password';
      
      // Check if we are trying to view a video
      final isDeepLink = state.uri.path.startsWith('/video/');

      // --- 2. Unauthenticated Users ---
      if (!isAuth) {
        // Allow deep links (video playback) even if not logged in!
        if (isSplash || isBrandSplash || isLogin || isSignup || isVerify || isDeepLink) {
          return null;
        }
        return '/brand-splash';
      }

      // --- 3. Authenticated Users ---
      if (isVerify || isReset || isDeepLink) return null;

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
      // --- DEEP LINK ROUTE (Single Video) ---
      GoRoute(
        path: '/video/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'];
          if (id == null) return const MainShell(); 
          return SingleVideoScreen(videoId: id);
        },
      ),
      // --- NEW: PROFILE FEED PLAYER (Scrollable List) ---
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
