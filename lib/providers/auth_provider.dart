import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/services/auth_service.dart';
import 'package:xprex/models/user_profile.dart';
import 'package:xprex/services/profile_service.dart';

final authServiceProvider = Provider((ref) => AuthService());
final profileServiceProvider = Provider((ref) => ProfileService());

final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final currentUserProfileProvider = FutureProvider<UserProfile?>((ref) async {
  // REACTIVE LINK: This line forces the provider to rebuild whenever AuthState changes
  // This solves the "Ghost State" bug where old profile data persisted after logout.
  ref.watch(authStateProvider);

  final authService = ref.watch(authServiceProvider);
  final profileService = ref.watch(profileServiceProvider);
  
  final userId = authService.currentUserId;
  if (userId == null) return null;
  
  return await profileService.getProfileByAuthId(userId);
});
