import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/models/video_model.dart';

class VideoService {
  final SupabaseClient _supabase = supabase;
  
  // Feature flags to disable noisy logs if tables are missing during dev
  static bool _sharesFeatureAvailable = true;
  static bool _savesFeatureAvailable = true;
  static bool _repostsFeatureAvailable = true;

  /// Standard raw feed (Time-based). 
  /// Useful for "Newest" tab or fallback.
  Future<List<VideoModel>> getFeedVideos({
    int limit = 20,
    int offset = 0,
  }) async {
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

  [span_0](start_span)/// THE ALGORITHM: "For You" Feed[span_0](end_span)
  /// Uses the SQL Logic to score videos based on User Interests + Freshness + Popularity.
  Future<List<VideoModel>> getForYouFeed({int limit = 20, int offset = 0}) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      // If no user, fallback to standard time-based feed
      if (uid == null) return getFeedVideos(limit: limit, offset: offset);

      final response = await _supabase.rpc(
        'get_for_you_feed',
        params: {
          'viewer_id': uid,
          'limit_val': limit,
          'offset_val': offset,
        },
      );

      final videos = (response as List)
          .map((json) => VideoModel.fromJson(json as Map<String, dynamic>))
          .toList();
      
      return videos;
    } catch (e) {
      debugPrint('❌ Error fetching For You feed: $e');
      // Graceful fallback to raw feed if RPC fails
      return getFeedVideos(limit: limit, offset: offset);
    }
  }

  [span_1](start_span)/// "Following" Feed[span_1](end_span)
  /// Shows videos created by or REPOSTED by people you follow.
  Future<List<VideoModel>> getFollowingFeed({int limit = 20, int offset = 0}) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return [];

      final response = await _supabase.rpc(
        'get_following_feed',
        params: {
          'viewer_id': uid,
          'limit_val': limit,
          'offset_val': offset,
        },
      );

      final videos = (response as List)
          .map((json) => VideoModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return videos;
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
      final videos = (response as List)
          .map((json) => VideoModel.fromJson(json as Map<String, dynamic>))
          .toList();
      return videos;
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

  [span_2](start_span)/// UPDATED: Accepts tags for the recommendation engine[span_2](end_span)
  Future<VideoModel> createVideo({
    required String authorAuthUserId,
    required String storagePath,
    required String title,
    String? description,
    String? coverImageUrl,
    required int duration,
    // --- NEW: Tags for the algorithm ---
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
        // --- Save Tags ---
        'tags': tags,
        
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
      await _supabase
          .from('videos')
          .update({
            'playback_count': 1, // Note: this sets it to 1, usually you want to increment via RPC or logic
          })
          .eq('id', videoId);
    } catch (e) {
      debugPrint('❌ Error incrementing playback count: $e');
    }
  }

  Future<bool> toggleLike(String videoId, String userAuthId) async {
    try {
      final existing = await _supabase
          .from('likes')
          .select()
          .eq('video_id', videoId)
          .eq('user_auth_id', userAuthId)
          .maybeSingle();
      if (existing != null) {
        await _supabase
            .from('likes')
            .delete()
            .eq('video_id', videoId)
            .eq('user_auth_id', userAuthId);
        debugPrint('✅ Video unliked');
        return false;
      } else {
        await _supabase.from('likes').insert({
          'video_id': videoId,
          'user_auth_id': userAuthId,
        });
        debugPrint('✅ Video liked');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error toggling like: $e');
      rethrow;
    }
  }

  Future<bool> isVideoLikedByUser(String videoId, String userAuthId) async {
    try {
      final response = await _supabase
          .from('likes')
          .select()
          .eq('video_id', videoId)
          .eq('user_auth_id', userAuthId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('❌ Error checking like status: $e');
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

  // --- Shares API ---
  Future<int> getShareCount(String videoId) async {
    try {
      if (!_sharesFeatureAvailable) return 0;
      final response = await _supabase
          .from('shares')
          .select('id')
          .eq('video_id', videoId);
      if (response is List) return response.length;
      return 0;
    } catch (e) {
      if (_sharesFeatureAvailable) {
        debugPrint('⚠️ getShareCount disabled: $e');
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
      debugPrint('✅ Share recorded');
    } catch (e) {
      if (_sharesFeatureAvailable) {
        debugPrint('⚠️ recordShare disabled: $e');
        _sharesFeatureAvailable = false;
      }
    }
  }

  // --- Saves / Bookmarks ---
  Future<bool> toggleSave(String videoId, String userAuthId) async {
    try {
      if (!_savesFeatureAvailable) return false;
      final existing = await _supabase
          .from('saves')
          .select('id')
          .eq('video_id', videoId)
          .eq('user_auth_id', userAuthId)
          .maybeSingle();
      if (existing != null) {
        await _supabase
            .from('saves')
            .delete()
            .eq('video_id', videoId)
            .eq('user_auth_id', userAuthId);
        debugPrint('✅ Removed bookmark');
        return false;
      } else {
        await _supabase.from('saves').insert({
          'video_id': videoId,
          'user_auth_id': userAuthId,
        });
        debugPrint('✅ Saved video');
        return true;
      }
    } catch (e) {
      if (_savesFeatureAvailable) {
        debugPrint('❌ toggleSave failed: $e');
        _savesFeatureAvailable = false;
      }
      rethrow;
    }
  }

  Future<bool> isVideoSavedByUser(String videoId, String userAuthId) async {
    try {
      if (!_savesFeatureAvailable) return false;
      final res = await _supabase
          .from('saves')
          .select('id')
          .eq('video_id', videoId)
          .eq('user_auth_id', userAuthId)
          .maybeSingle();
      return res != null;
    } catch (e) {
      if (_savesFeatureAvailable) {
        debugPrint('⚠️ isVideoSavedByUser disabled: $e');
        _savesFeatureAvailable = false;
      }
      return false;
    }
  }

  // --- Reposts ---
  Future<bool> toggleRepost(String videoId, String userAuthId) async {
    try {
      if (!_repostsFeatureAvailable) return false;
      final existing = await _supabase
          .from('reposts')
          .select('id')
          .eq('video_id', videoId)
          .eq('reposter_auth_user_id', userAuthId)
          .maybeSingle();
      if (existing != null) {
        await _supabase
            .from('reposts')
            .delete()
            .eq('video_id', videoId)
            .eq('reposter_auth_user_id', userAuthId);
        debugPrint('✅ Repost removed');
        return false;
      } else {
        await _supabase.from('reposts').insert({
          'video_id': videoId,
          'reposter_auth_user_id': userAuthId,
        });
        debugPrint('✅ Reposted video');
        return true;
      }
    } catch (e) {
      if (_repostsFeatureAvailable) {
        debugPrint('❌ toggleRepost failed: $e');
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
          .eq('reposter_auth_user_id', userAuthId)
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
        debugPrint('⚠️ getRepostedVideos disabled: $e');
        _repostsFeatureAvailable = false;
      }
      return [];
    }
  }
}
