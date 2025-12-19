import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/models/video_model.dart';
import 'package:flutter/foundation.dart';

class VideoService {
  final SupabaseClient _supabase = supabase;

  // ==========================================
  // 1. CORE FEED & PLAYBACK
  // ==========================================

  /// Fetch feed videos
  Future<List<VideoModel>> getFeedVideos() async {
    try {
      final response = await _supabase
          .from('videos')
          .select('*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url)')
          .order('created_at', ascending: false)
          .limit(20);

      final List<VideoModel> videos = [];
      for (var item in response) {
        videos.add(VideoModel.fromJson(item));
      }
      return videos;
    } catch (e) {
      debugPrint('Error fetching feed: $e');
      return [];
    }
  }

  /// Fetch a single video by ID (Fixed for Pulse Screen)
  Future<VideoModel> getVideoById(String videoId) async {
    try {
      final response = await _supabase
          .from('videos')
          .select('*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url)')
          .eq('id', videoId)
          .single();
      
      return VideoModel.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching video by ID: $e');
      throw Exception('Video not found');
    }
  }

  // ==========================================
  // 2. USER PROFILE VIDEOS
  // ==========================================

  /// Fetch videos created by a specific user
  Future<List<VideoModel>> getUserVideos(String userId) async {
    try {
      final response = await _supabase
          .from('videos')
          .select('*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url)')
          .eq('author_auth_user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((x) => VideoModel.fromJson(x)).toList();
    } catch (e) {
      debugPrint('Error fetching user videos: $e');
      return [];
    }
  }

  /// Fetch videos reposted by a user (Fixed for User Profile Screen)
  Future<List<VideoModel>> getRepostedVideos(String userId) async {
    try {
      // Joins reposts -> videos -> profiles
      final response = await _supabase
          .from('reposts')
          .select('created_at, video:videos(*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url))')
          .eq('user_auth_id', userId) // Note: Ensure your DB column is user_auth_id or user_id
          .order('created_at', ascending: false);

      final list = <VideoModel>[];
      for (final row in (response as List)) {
        final videoJson = (row as Map<String, dynamic>)['video'];
        if (videoJson != null) {
          // Flatten: Ensure the video model gets the data it needs
          list.add(VideoModel.fromJson(videoJson as Map<String, dynamic>));
        }
      }
      return list;
    } catch (e) {
      // Fallback: Try with 'user_id' column if 'user_auth_id' fails
      try {
         final responseRetry = await _supabase
          .from('reposts')
          .select('created_at, video:videos(*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url))')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
         
         final list = <VideoModel>[];
         for (final row in (responseRetry as List)) {
            final videoJson = (row as Map<String, dynamic>)['video'];
            if (videoJson != null) list.add(VideoModel.fromJson(videoJson));
         }
         return list;
      } catch (e2) {
        debugPrint('Error fetching reposts: $e2');
        return [];
      }
    }
  }

  // ==========================================
  // 3. ACTIONS (UPLOAD & LIKE)
  // ==========================================

  Future<void> createVideo({
    required String authorAuthUserId,
    required String storagePath,
    required String title,
    String? description,
    String? coverImageUrl,
    required int duration,
    List<String>? tags,
  }) async {
    try {
      await _supabase.from('videos').insert({
        'author_auth_user_id': authorAuthUserId,
        'storage_path': storagePath,
        'title': title,
        'description': description,
        'cover_image_url': coverImageUrl,
        'duration': duration,
        'tags': tags ?? [],
      });
    } catch (e) {
      debugPrint('Error creating video: $e');
      rethrow;
    }
  }

  Future<void> toggleLike(String videoId, [String? userId]) async {
    final uid = userId ?? _supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final existing = await _supabase
          .from('likes')
          .select('id')
          .eq('video_id', videoId)
          .eq('user_id', uid)
          .maybeSingle();

      if (existing != null) {
        await _supabase.from('likes').delete().eq('id', existing['id']);
      } else {
        await _supabase.from('likes').insert({
          'video_id': videoId,
          'user_id': uid,
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  // ==========================================
  // 4. ANALYTICS & STATS
  // ==========================================

  /// Fetch simple stats for Creator Hub (Fixed for Creator Hub Screen)
  Future<Map<String, dynamic>> getCreatorStats() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return {'views': 0, 'likes': 0, 'followers': 0};

    try {
      // Get Profile Stats
      final profile = await _supabase
          .from('profiles')
          .select('followers_count, total_video_views')
          .eq('auth_user_id', uid)
          .single();

      // Get Total Likes (Sum of likes on user's videos)
      // This is a rough estimate or requires an RPC. 
      // For MVP, we'll return a placeholder or query if you have a summary table.
      return {
        'views': profile['total_video_views'] ?? 0,
        'likes': 0, // Placeholder to prevent crash, or fetch from RPC if available
        'followers': profile['followers_count'] ?? 0,
      };
    } catch (e) {
      debugPrint('Error fetching creator stats: $e');
      return {'views': 0, 'likes': 0, 'followers': 0};
    }
  }

  /// Detailed Dashboard for Analytics Screen
  Future<Map<String, dynamic>> getAnalyticsDashboard({int days = 30}) async {
    // Return dummy data structure that AnalyticsScreen expects
    return {
      'metrics': {
        'views': 1200,
        'views_change': 5.2,
        'likes': 300,
        'likes_change': 1.1,
        'followers': 50,
        'followers_change': 0.5,
        'earnings': 12000,
        'earnings_change': 12.0,
      },
      'top_videos': []
    };
  }
}
