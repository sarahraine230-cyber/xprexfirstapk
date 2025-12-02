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

  Future<UserProfile> ensureProfileExists({
    required String authUserId,
    required String email,
  }) async {
    try {
      final existing = await getProfileByAuthId(authUserId);
      if (existing != null) {
        return existing;
      }

      final suffix = authUserId.replaceAll('-', '').substring(0, 6);
      String candidate = 'xp$suffix';

      try {
        final available = await isUsernameAvailable(candidate);
        if (!available) {
          candidate = 'user_$suffix';
        }
      } catch (_) {}

      debugPrint('ℹ️ Creating missing profile for authUserId=$authUserId using username=$candidate');
      return await createProfile(
        authUserId: authUserId,
        email: email,
        username: candidate,
        displayName: candidate,
        avatarUrl: null,
        bio: null,
      );
    } catch (e) {
      debugPrint('❌ ensureProfileExists error: $e');
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

  // =====================
  // Follows API
  // =====================
  Future<bool> isFollowing({required String followerAuthUserId, required String followeeAuthUserId}) async {
    try {
      final existing = await _supabase
          .from('follows')
          .select('id')
          .eq('follower_auth_user_id', followerAuthUserId)
          .eq('followee_auth_user_id', followeeAuthUserId)
          .maybeSingle();
      return existing != null;
    } catch (e) {
      debugPrint('❌ Error checking follow status: $e');
      return false;
    }
  }

  Future<void> followUser({required String followerAuthUserId, required String followeeAuthUserId}) async {
    try {
      if (followerAuthUserId == followeeAuthUserId) return;
      await _supabase.from('follows').insert({
        'follower_auth_user_id': followerAuthUserId,
        'followee_auth_user_id': followeeAuthUserId,
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ Followed user $followeeAuthUserId');
    } catch (e) {
      debugPrint('❌ Follow failed: $e');
      rethrow;
    }
  }

  Future<void> unfollowUser({required String followerAuthUserId, required String followeeAuthUserId}) async {
    try {
      await _supabase
          .from('follows')
          .delete()
          .eq('follower_auth_user_id', followerAuthUserId)
          .eq('followee_auth_user_id', followeeAuthUserId);
      debugPrint('✅ Unfollowed user $followeeAuthUserId');
    } catch (e) {
      debugPrint('❌ Unfollow failed: $e');
      rethrow;
    }
  }

  Future<int> getFollowerCount(String followeeAuthUserId) async {
    try {
      final res = await _supabase
          .from('follows')
          .select('id')
          .eq('followee_auth_user_id', followeeAuthUserId);
      if (res is List) return res.length;
      return 0;
    } catch (e) {
      debugPrint('❌ Error getting follower count: $e');
      return 0;
    }
  }

  // --- NEW LIST FETCHERS ---

  Future<List<UserProfile>> getFollowersList(String userId) async {
    try {
      // 1. Get all follower IDs
      final follows = await _supabase
          .from('follows')
          .select('follower_auth_user_id')
          .eq('followee_auth_user_id', userId);
      
      final ids = (follows as List).map((e) => e['follower_auth_user_id']).toList();
      if (ids.isEmpty) return [];

      // 2. Fetch profiles for those IDs
      final profiles = await _supabase
          .from('profiles')
          .select()
          .inFilter('auth_user_id', ids);
      
      return (profiles as List).map((json) => UserProfile.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching followers list: $e');
      return [];
    }
  }

  Future<List<UserProfile>> getFollowingList(String userId) async {
    try {
      // 1. Get all followee IDs
      final follows = await _supabase
          .from('follows')
          .select('followee_auth_user_id')
          .eq('follower_auth_user_id', userId);
      
      final ids = (follows as List).map((e) => e['followee_auth_user_id']).toList();
      if (ids.isEmpty) return [];

      // 2. Fetch profiles
      final profiles = await _supabase
          .from('profiles')
          .select()
          .inFilter('auth_user_id', ids);
      
      return (profiles as List).map((json) => UserProfile.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching following list: $e');
      return [];
    }
  }
}
