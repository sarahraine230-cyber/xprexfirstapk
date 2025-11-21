import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';

class AuthService {
  final SupabaseClient _supabase = supabase;

  User? get currentUser => _supabase.auth.currentUser;
  String? get currentUserId => currentUser?.id;
  bool get isAuthenticated => currentUser != null;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      debugPrint('✅ Sign up successful for: $email');
      return response;
    } catch (e) {
      debugPrint('❌ Sign up error: $e');
      rethrow;
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ Sign in successful for: $email');
      return response;
    } catch (e) {
      debugPrint('❌ Sign in error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      debugPrint('✅ Sign out successful');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      rethrow;
    }
  }

  Future<void> resendVerificationEmail() async {
    try {
      if (currentUser?.email == null) {
        throw Exception('No user email found');
      }
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: currentUser!.email!,
      );
      debugPrint('✅ Verification email resent');
    } catch (e) {
      debugPrint('❌ Resend verification error: $e');
      rethrow;
    }
  }

  Future<void> refreshSession() async {
    try {
      await _supabase.auth.refreshSession();
      debugPrint('✅ Session refreshed');
    } catch (e) {
      debugPrint('❌ Session refresh error: $e');
      rethrow;
    }
  }

  bool isEmailVerified() => currentUser?.emailConfirmedAt != null;
}
