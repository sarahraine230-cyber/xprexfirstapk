import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/models/user_profile.dart';

class ProfileService {
  final SupabaseClient _supabase = supabase;

  Future<UserProfile?> getProfileByAuthId(String authUserId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('auth_user_id', authUserId)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error fetching profile: $e');
      rethrow;
    }
  }

  Future<UserProfile?> getProfileByUsername(String username) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('username', username)
          .maybeSingle();

      if (response == null) return null;
      return UserProfile.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error fetching profile by username: $e');
      rethrow;
    }
  }

  Future<bool> isUsernameAvailable(String username) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('username')
          .ilike('username', username)
          .maybeSingle();

      return response == null;
    } catch (e) {
      debugPrint('❌ Error checking username: $e');
      return false;
    }
  }

  Future<UserProfile> createProfile({
    required String authUserId,
    required String email,
    required String username,
    required String displayName,
    String? avatarUrl,
    String? bio,
  }) async {
    try {
      final now = DateTime.now();
      final data = {
        'auth_user_id': authUserId,
        'email': email,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'bio': bio,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('profiles')
          .insert(data)
          .select()
          .single();

      debugPrint('✅ Profile created for: $username');
      return UserProfile.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error creating profile: $e');
      rethrow;
    }
  }

  Future<UserProfile> updateProfile({
    required String authUserId,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    bool? isPremium,
    String? monetizationStatus,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (username != null) data['username'] = username;
      if (displayName != null) data['display_name'] = displayName;
      if (avatarUrl != null) data['avatar_url'] = avatarUrl;
      if (bio != null) data['bio'] = bio;
      if (isPremium != null) data['is_premium'] = isPremium;
      if (monetizationStatus != null) data['monetization_status'] = monetizationStatus;

      final response = await _supabase
          .from('profiles')
          .update(data)
          .eq('auth_user_id', authUserId)
          .select()
          .single();

      debugPrint('✅ Profile updated');
      return UserProfile.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error updating profile: $e');
      rethrow;
    }
  }

  Future<void> incrementTotalVideoViews(String authUserId, int increment) async {
    try {
      await _supabase.rpc('increment_video_views', params: {
        'user_id': authUserId,
        'increment_by': increment,
      });
    } catch (e) {
      debugPrint('❌ Error incrementing video views: $e');
    }
  }

  Future<Map<String, dynamic>> getMonetizationEligibility(String authUserId) async {
    try {
      final profile = await getProfileByAuthId(authUserId);
      if (profile == null) {
        throw Exception('Profile not found');
      }

      final now = DateTime.now();
      final accountAge = now.difference(profile.createdAt).inDays;

      final criteria = {
        'min_followers': profile.followersCount >= 1000,
        'min_video_views': profile.totalVideoViews >= 10000,
        'min_account_age': accountAge >= 30,
        'email_verified': true,
        'age_confirmed': true,
        'no_active_flags': true,
      };

      final metCount = criteria.values.where((v) => v).length;
      final totalCount = criteria.length;
      final progress = (metCount / totalCount * 100).round();

      final isEligible = metCount == totalCount;

      return {
        'eligible': isEligible,
        'progress': progress,
        'criteria': criteria,
        'current_status': profile.monetizationStatus,
        'followers': profile.followersCount,
        'video_views': profile.totalVideoViews,
        'account_age_days': accountAge,
      };
    } catch (e) {
      debugPrint('❌ Error checking monetization eligibility: $e');
      rethrow;
    }
  }
}
