import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/models/video_model.dart';

class VideoService {
  final SupabaseClient _supabase = supabase;
  static bool _sharesFeatureAvailable = true;
  static bool _savesFeatureAvailable = true;
  static bool _repostsFeatureAvailable = true;

  // --- ANALYTICS: RECORD VIEW ---
  Future<void> recordView(String videoId, String authorId) async {
    try {
      final viewerId = _supabase.auth.currentUser?.id;
      await _supabase.from('video_views').insert({
        'video_id': videoId,
        'author_id': authorId,
        'viewer_id': viewerId, 
      });
      await incrementPlaybackCount(videoId);
    } catch (e) {
      debugPrint('⚠️ Failed to record view stats: $e');
    }
  }

  // --- ANALYTICS: CREATOR STATS (Hub) ---
  Future<Map<String, dynamic>> getCreatorStats() async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return {};
      final data = await _supabase.rpc('get_creator_stats', params: {'target_user_id': uid});
      return data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Error fetching creator stats: $e');
      return {};
    }
  }

  // --- ANALYTICS: FULL DASHBOARD (Dynamic Date Range) ---
  Future<Map<String, dynamic>> getAnalyticsDashboard({int days = 30}) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return {};
      
      final data = await _supabase.rpc('get_analytics_dashboard', params: {
        'target_user_id': uid,
        'days_range': days, 
      });
      return data as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Error fetching analytics dashboard: $e');
      return {};
    }
  }

  Future<List<VideoModel>> getFeedVideos({int limit = 20, int offset = 0}) async {
    try {
      final response = await _supabase
          .from('videos')
          .select('*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url)')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final videos = (response as List)
          .map((json) => VideoModel.fromJson(json as Map<String, dynamic>))
          .toList();
      return videos;
    } catch (e) {
      debugPrint('❌ Error fetching feed videos: $e');
      rethrow;
    }
  }

  Future<List<VideoModel>> getForYouFeed({int limit = 20, int offset = 0}) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return getFeedVideos(limit: limit, offset: offset);

      final response = await _supabase.rpc(
        'get_for_you_feed',
        params: {'viewer_id': uid, 'limit_val': limit, 'offset_val': offset},
      );
      final videos = (response as List)
          .map((json) => VideoModel.fromJson(json as Map<String, dynamic>))
          .toList();
      return videos;
    } catch (e) {
      debugPrint('❌ Error fetching For You feed: $e');
      return getFeedVideos(limit: limit, offset: offset);
    }
  }

  Future<List<VideoModel>> getFollowingFeed({int limit = 20, int offset = 0}) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return [];

      final response = await _supabase.rpc(
        'get_following_feed',
        params: {'viewer_id': uid, 'limit_val': limit, 'offset_val': offset},
      );
      return (response as List)
          .map((json) => VideoModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching following feed: $e');
      return [];
    }
  }

  Future<List<VideoModel>> getUserVideos(String authUserId) async {
    try {
      final response = await _supabase
          .from('videos')
          .select('*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url)')
          .eq('author_auth_user_id', authUserId)
          .order('created_at', ascending: false);
      return (response as List)
          .map((json) => VideoModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching user videos: $e');
      rethrow;
    }
  }

  Future<VideoModel?> getVideoById(String videoId) async {
    try {
      final response = await _supabase
          .from('videos')
          .select('*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url)')
          .eq('id', videoId)
          .maybeSingle();
      if (response == null) return null;
      return VideoModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error fetching video: $e');
      rethrow;
    }
  }

  // --- UPDATED: createVideo NOW ACCEPTS categoryId ---
  Future<VideoModel> createVideo({
    required String authorAuthUserId,
    required String storagePath,
    required String title,
    String? description,
    String? coverImageUrl,
    required int duration,
    required int categoryId, // <--- NEW REQUIREMENT
    List<String> tags = const [],
  }) async {
    try {
      final now = DateTime.now();
      final data = {
        'author_auth_user_id': authorAuthUserId,
        'storage_path': storagePath,
        'title': title,
        'description': description,
        'cover_image_url': coverImageUrl,
        'duration': duration,
        'tags': tags,
        'category_id': categoryId, // <--- SAVING TO DB
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      final response = await _supabase
          .from('videos')
          .insert(data)
          .select('*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url)')
          .single();
      debugPrint('✅ Video created: $title');
      return VideoModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error creating video: $e');
      rethrow;
    }
  }

  Future<void> incrementPlaybackCount(String videoId) async {
    try {
      await _supabase.rpc('increment_video_views', params: {'video_id': videoId});
    } catch (e) {
      try {
         await _supabase.rpc('increment_playback_count', params: {'row_id': videoId});
      } catch (_) {}
    }
  }

  Future<bool> toggleLike(String videoId, String userAuthId) async {
    try {
      final existing = await _supabase.from('likes').select().eq('video_id', videoId).eq('user_auth_id', userAuthId).maybeSingle();
      if (existing != null) {
        await _supabase.from('likes').delete().eq('video_id', videoId).eq('user_auth_id', userAuthId);
        return false;
      } else {
        await _supabase.from('likes').insert({'video_id': videoId, 'user_auth_id': userAuthId});
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error toggling like: $e');
      rethrow;
    }
  }

  Future<bool> isVideoLikedByUser(String videoId, String userAuthId) async {
    try {
      final response = await _supabase.from('likes').select().eq('video_id', videoId).eq('user_auth_id', userAuthId).maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> deleteVideo(String videoId) async {
    try {
      await _supabase.from('videos').delete().eq('id', videoId);
      debugPrint('✅ Video deleted');
    } catch (e) {
      debugPrint('❌ Error deleting video: $e');
      rethrow;
    }
  }

  Future<int> getShareCount(String videoId) async {
    try {
      if (!_sharesFeatureAvailable) return 0;
      final response = await _supabase.from('shares').select('id').eq('video_id', videoId);
      if (response is List) return response.length;
      return 0;
    } catch (e) {
      if (_sharesFeatureAvailable) {
        _sharesFeatureAvailable = false;
      }
      return 0;
    }
  }

  Future<void> recordShare(String videoId, String userAuthId) async {
    try {
      if (!_sharesFeatureAvailable) return;
      await _supabase.from('shares').insert({
        'video_id': videoId,
        'user_auth_id': userAuthId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      if (_sharesFeatureAvailable) {
        _sharesFeatureAvailable = false;
      }
    }
  }

  Future<bool> toggleSave(String videoId, String userAuthId) async {
    try {
      if (!_savesFeatureAvailable) return false;
      final existing = await _supabase.from('saved_videos').select('id').eq('video_id', videoId).eq('user_auth_id', userAuthId).maybeSingle();
      if (existing != null) {
        await _supabase.from('saved_videos').delete().eq('video_id', videoId).eq('user_auth_id', userAuthId);
        return false;
      } else {
        await _supabase.from('saved_videos').insert({'video_id': videoId, 'user_auth_id': userAuthId});
        return true;
      }
    } catch (e) {
      if (_savesFeatureAvailable) {
        _savesFeatureAvailable = false;
      }
      rethrow;
    }
  }

  Future<bool> isVideoSavedByUser(String videoId, String userAuthId) async {
    try {
      if (!_savesFeatureAvailable) return false;
      final res = await _supabase.from('saved_videos').select('id').eq('video_id', videoId).eq('user_auth_id', userAuthId).maybeSingle();
      return res != null;
    } catch (e) {
      if (_savesFeatureAvailable) {
        _savesFeatureAvailable = false;
      }
      return false;
    }
  }

  Future<bool> toggleRepost(String videoId, String userAuthId) async {
    try {
      if (!_repostsFeatureAvailable) return false;
      final existing = await _supabase.from('reposts').select('id').eq('video_id', videoId).eq('user_auth_id', userAuthId).maybeSingle();
      if (existing != null) {
        await _supabase.from('reposts').delete().eq('video_id', videoId).eq('user_auth_id', userAuthId);
        return false;
      } else {
        await _supabase.from('reposts').insert({'video_id': videoId, 'user_auth_id': userAuthId});
        return true;
      }
    } catch (e) {
      if (_repostsFeatureAvailable) {
        _repostsFeatureAvailable = false;
      }
      rethrow;
    }
  }

  Future<List<VideoModel>> getRepostedVideos(String userAuthId) async {
    try {
      if (!_repostsFeatureAvailable) return [];
      final rows = await _supabase
          .from('reposts')
          .select('created_at, video:videos(*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url))')
          .eq('user_auth_id', userAuthId)
          .order('created_at', ascending: false);
      final list = <VideoModel>[];
      for (final row in (rows as List)) {
        final videoJson = (row as Map<String, dynamic>)['video'] as Map<String, dynamic>?;
        if (videoJson != null) {
          list.add(VideoModel.fromJson(videoJson));
        }
      }
      return list;
    } catch (e) {
      if (_repostsFeatureAvailable) {
        _repostsFeatureAvailable = false;
      }
      return [];
    }
  }
}
