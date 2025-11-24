import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/models/video_model.dart';

class VideoService {
  final SupabaseClient _supabase = supabase;
  static bool _sharesFeatureAvailable = true; // disable noisy logs after first failure
  static bool _savesFeatureAvailable = true;
  static bool _repostsFeatureAvailable = true;

  Future<List<VideoModel>> getFeedVideos({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('videos')
          .select('*, profiles!author_auth_user_id(username, display_name, avatar_url)')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final videos = (response as List)
          .map((json) => VideoModel.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint('✅ Fetched ${videos.length} videos');
      return videos;
    } catch (e) {
      debugPrint('❌ Error fetching feed videos: $e');
      rethrow;
    }
  }

  Future<List<VideoModel>> getUserVideos(String authUserId) async {
    try {
      final response = await _supabase
          .from('videos')
          .select('*, profiles!author_auth_user_id(username, display_name, avatar_url)')
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
          .select('*, profiles!author_auth_user_id(username, display_name, avatar_url)')
          .eq('id', videoId)
          .maybeSingle();

      if (response == null) return null;
      return VideoModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error fetching video: $e');
      rethrow;
    }
  }

  Future<VideoModel> createVideo({
    required String authorAuthUserId,
    required String storagePath,
    required String title,
    String? description,
    String? coverImageUrl,
    required int duration,
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
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('videos')
          .insert(data)
          .select('*, profiles!author_auth_user_id(username, display_name, avatar_url)')
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
            'playback_count': 1,
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

  // --- Shares API (best-effort, table may not exist) ---
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
        debugPrint('⚠️ getShareCount disabled (shares table missing or RLS): $e');
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
      // Do not break UX; suppress further logs
      if (_sharesFeatureAvailable) {
        debugPrint('⚠️ recordShare disabled (non-fatal): $e');
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
        debugPrint('❌ toggleSave failed (disabling saves): $e');
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
        debugPrint('❌ toggleRepost failed (disabling reposts): $e');
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
          .select('created_at, video:videos(*, profiles!author_auth_user_id(username, display_name, avatar_url))')
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
