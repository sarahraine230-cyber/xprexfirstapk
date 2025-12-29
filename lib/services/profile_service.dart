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

  // --- RESTORED & FIXED ---
  Future<void> ensureProfileExists({required String authUserId, required String email}) async {
    try {
      final exists = await getProfileByAuthId(authUserId);
      if (exists == null) {
        // Create a minimal profile if none exists
        final newProfile = UserProfile(
          id: authUserId, // FIXED: Added required 'id' (matches authUserId)
          authUserId: authUserId,
          email: email,
          username: 'user_${authUserId.substring(0, 5)}', // Temporary username
          displayName: email.split('@')[0],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await createProfile(newProfile);
      }
    } catch (e) {
      debugPrint('Error ensuring profile exists: $e');
      // Don't rethrow here to allow app flow to continue if possible
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

  Future<void> createProfile(UserProfile profile) async {
    try {
      await _supabase.from('profiles').insert(profile.toJson());
      debugPrint('✅ Profile created for: ${profile.username}');
    } catch (e) {
      debugPrint('❌ Error creating profile: $e');
      rethrow;
    }
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> updates) async {
    try {
      await _supabase.from('profiles').update(updates).eq('auth_user_id', userId);
      debugPrint('✅ Profile updated');
    } catch (e) {
      debugPrint('❌ Error updating profile: $e');
      rethrow;
    }
  }

  // --- SOCIAL GRAPH METHODS ---

  Future<bool> isFollowing({required String followerId, required String followeeId}) async {
    try {
      final response = await _supabase
          .from('follows')
          .select()
          .eq('follower_auth_user_id', followerId)
          .eq('followee_auth_user_id', followeeId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('❌ Error checking follow status: $e');
      return false;
    }
  }

  Future<void> followUser({required String followerId, required String followeeId}) async {
    try {
      await _supabase.from('follows').insert({
        'follower_auth_user_id': followerId,
        'followee_auth_user_id': followeeId,
      });
      // Increment counts via RPC
      try { await _supabase.rpc('increment_followers', params: {'target_user_id': followeeId});
      } catch (_) {}
      try { await _supabase.rpc('increment_following', params: {'target_user_id': followerId});
      } catch (_) {}
    } catch (e) {
      debugPrint('❌ Error following user: $e');
      rethrow;
    }
  }

  Future<void> unfollowUser({required String followerId, required String followeeId}) async {
    try {
      await _supabase.from('follows').delete()
          .eq('follower_auth_user_id', followerId)
          .eq('followee_auth_user_id', followeeId);
      // Decrement counts via RPC
      try { await _supabase.rpc('decrement_followers', params: {'target_user_id': followeeId});
      } catch (_) {}
      try { await _supabase.rpc('decrement_following', params: {'target_user_id': followerId});
      } catch (_) {}
    } catch (e) {
      debugPrint('❌ Error unfollowing user: $e');
      rethrow;
    }
  }

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
