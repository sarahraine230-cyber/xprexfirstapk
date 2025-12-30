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
      debugPrint('✅ Sign up initiated for: $email');
      return response;
    } catch (e) {
      debugPrint('❌ Sign up error: $e');
      rethrow;
    }
  }

  // --- NEW: OTP VERIFICATION ---
  Future<AuthResponse> verifySignupOtp({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.signup,
      );
      debugPrint('✅ OTP Verified for: $email');
      return response;
    } catch (e) {
      debugPrint('❌ OTP Verification error: $e');
      rethrow;
    }
  }

  // --- NEW: PASSWORD RECOVERY FLOW ---
  
  // Step 1: Send the OTP to the email
  Future<void> sendPasswordResetOtp(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      debugPrint('✅ Password reset OTP sent to: $email');
    } catch (e) {
      debugPrint('❌ Send reset OTP error: $e');
      rethrow;
    }
  }

  // Step 2: Verify the OTP (This logs the user in temporarily)
  Future<AuthResponse> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.recovery,
      );
      debugPrint('✅ Recovery OTP Verified. User logged in session.');
      return response;
    } catch (e) {
      debugPrint('❌ Recovery Verification error: $e');
      rethrow;
    }
  }

  // Step 3: Update the password (now that user is logged in via Step 2)
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      debugPrint('✅ Password successfully updated');
    } catch (e) {
      debugPrint('❌ Password update error: $e');
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

  Future<void> resendVerificationEmail({String? email}) async {
    try {
      final targetEmail = email ?? currentUser?.email;
      if (targetEmail == null) throw Exception('No email provided');
      
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: targetEmail,
      );
      debugPrint('✅ Verification code resent');
    } catch (e) {
      debugPrint('❌ Resend code error: $e');
      rethrow;
    }
  }

  bool isEmailVerified() => currentUser?.emailConfirmedAt != null;
}
