import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart'; 
import 'package:xprex/models/video_model.dart';

class VideoService {
  final _supabase = Supabase.instance.client;

  Future<List<VideoModel>> getForYouFeed({int limit = 20}) async {
    try {
      // NOTE: Ensure your Edge Function 'feed-algorithm' also selects is_premium!
      final response = await _supabase.functions.invoke('feed-algorithm');
      final data = response.data;
      if (data == null) return [];
      final List<dynamic> list = data as List<dynamic>;
      return list.map((json) => VideoModel.fromMap(json)).toList();
    } catch (e) {
      print('Error fetching feed from Edge Function: $e');
      return _getFallbackFeed(limit);
    }
  }

  Future<List<VideoModel>> getFollowingFeed({int limit = 20}) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return [];
    try {
      final followingRes = await _supabase
          .from('follows')
          .select('followee_auth_user_id')
          .eq('follower_auth_user_id', uid);
      
      final followingIds = (followingRes as List)
          .map((e) => e['followee_auth_user_id'].toString())
          .toList();
      
      if (followingIds.isEmpty) return [];

      final videosRes = await _supabase
          .from('videos')
          // [NEW] Added is_premium to select
          .select('*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url, is_premium)')
          .inFilter('author_auth_user_id', followingIds)
          .neq('privacy_level', 'private') 
          .order('created_at', ascending: false)
          .limit(limit);
      
      return (videosRes as List).map((e) => VideoModel.fromMap(e)).toList();
    } catch (e) {
      print('❌ Error fetching following feed: $e');
      return [];
    }
  }

  Future<List<VideoModel>> _getFallbackFeed(int limit) async {
    try {
      final response = await _supabase
          .from('videos')
          // [NEW] Added is_premium to select
          .select('*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url, is_premium)')
          .eq('privacy_level', 'public')
          .order('created_at', ascending: false)
          .limit(limit);
      
      return (response as List).map((e) => VideoModel.fromMap(e)).toList();
    } catch (e) {
      print('Fallback feed error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getCreatorStats() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};
    try {
      final data = await _supabase.rpc('get_creator_stats', params: {'target_user_id': userId});
      return data as Map<String, dynamic>;
    } catch (e) {
      print('Error fetching creator stats: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getAnalyticsDashboard({int days = 30}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};
    try {
      final data = await _supabase.rpc(
        'get_analytics_dashboard', 
        params: {'target_user_id': userId, 'days_range': days}
      );
      return data as Map<String, dynamic>;
    } catch (e) {
      print('Error fetching analytics dashboard: $e');
      return {};
    }
  }
  
  // --- UPDATED: SMART PRIVACY FILTER ---
  Future<List<VideoModel>> getUserVideos(String authorId) async {
    try {
      final viewerId = _supabase.auth.currentUser?.id;
      // 1. Base Query
      // [NEW] Added is_premium to select
      var query = _supabase
          .from('videos')
          .select('*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url, is_premium)')
          .eq('author_auth_user_id', authorId);
      
      // 2. Privacy Logic
      if (viewerId == authorId) {
        // CASE A: Author viewing own profile -> Show ALL (Public, Followers, Private)
      } else if (viewerId != null) {
        // CASE B: Logged in user viewing someone else
        final count = await _supabase
            .from('follows')
            .count()
            .eq('follower_auth_user_id', viewerId)
            .eq('followee_auth_user_id', authorId);
        
        final isFollowing = count > 0;

        if (isFollowing) {
          // Following -> Show Public + Followers
          query = query.inFilter('privacy_level', ['public', 'followers']);
        } else {
          // Stranger -> Show Public Only
          query = query.eq('privacy_level', 'public');
        }
      } else {
        // CASE C: Guest (Not logged in) -> Public Only
        query = query.eq('privacy_level', 'public');
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List).map((e) => VideoModel.fromMap(e)).toList();
    } catch (e) {
      print('Error fetching user videos: $e');
      return [];
    }
  }

  Future<List<VideoModel>> getRepostedVideos(String userId) async {
    try {
      // [NEW] Added is_premium to select (nested in video:videos)
      final response = await _supabase
          .from('reposts')
          .select('created_at, video:videos(*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url, is_premium))')
          .eq('user_auth_id', userId)
          .order('created_at', ascending: false);
      
      final list = <VideoModel>[];
      final data = response as List<dynamic>;
      for (final row in data) {
        final videoJson = (row as Map<String, dynamic>)['video'];
        if (videoJson != null) {
          list.add(VideoModel.fromMap(videoJson));
        }
      }
      return list;
    } catch (e) {
      print('Error fetching reposted videos: $e');
      return [];
    }
  }

  Future<void> recordView(String videoId, String authorId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    if (userId == authorId) return;

    try {
      await _supabase.from('video_views').insert({
        'video_id': videoId,
        'viewer_id': userId,
        'author_id': authorId,
      });
    } catch (_) {}
    try {
      await _supabase.rpc('increment_video_view', params: {'video_id': videoId});
    } catch (_) {}
  }

  Future<void> toggleLike(String videoId, String userId) async {
     final existing = await _supabase
         .from('likes')
         .select()
         .eq('video_id', videoId)
         .eq('user_auth_id', userId) 
         .maybeSingle();
     
     if (existing != null) {
       await _supabase.from('likes').delete().eq('id', existing['id']);
       try { await _supabase.rpc('decrement_video_like', params: {'video_id': videoId});
       } catch (_) {}
     } else {
       await _supabase.from('likes').insert({'video_id': videoId, 'user_auth_id': userId});
       try { await _supabase.rpc('increment_video_like', params: {'video_id': videoId});
       } catch (_) {}
     }
  }
  
  Future<bool> isVideoLikedByUser(String videoId, String userId) async {
    final count = await _supabase.from('likes').count().eq('video_id', videoId).eq('user_auth_id', userId);
    return count > 0;
  }
  
  Future<int> getShareCount(String videoId) async {
    final res = await _supabase.from('videos').select('shares_count').eq('id', videoId).single();
    return (res['shares_count'] as int?) ?? 0; 
  }
  
  Future<void> recordShare(String videoId, String userId) async {
     try {
       await _supabase.from('shares').insert({'video_id': videoId, 'user_auth_id': userId});
       try { await _supabase.rpc('increment_video_share', params: {'video_id': videoId});
       } catch (_) {}
     } catch (e) {
       print('Error recording share: $e');
     }
  }
  
  Future<VideoModel?> getVideoById(String id) async {
    try {
      // [NEW] Added is_premium to select
      final data = await _supabase
          .from('videos')
          .select('*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url, is_premium)')
          .eq('id', id)
          .single();
      return VideoModel.fromMap(data);
    } catch (e) {
      return null;
    }
  }
  
  Future<void> createVideo({
    required String authorAuthUserId,
    required String storagePath,
    required String title,
    required String description,
    required String coverImageUrl,
    required int duration,
    required List<String> tags,
    required int categoryId,
    required String privacyLevel,
    required bool allowComments,
  }) async {
    await _supabase.from('videos').insert({
      'author_auth_user_id': authorAuthUserId,
      'storage_path': storagePath,
      'title': title,
      'description': description,
      'cover_image_url': coverImageUrl,
      'duration': duration,
      'tags': tags,
      'privacy_level': privacyLevel,
      'allow_comments': allowComments,
    });
  }
}
