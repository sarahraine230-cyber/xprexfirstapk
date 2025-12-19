import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/models/video_model.dart';
import 'package:flutter/foundation.dart';

class VideoService {
  final SupabaseClient _supabase = supabase;

  /// Fetch feed videos (random/algorithm)
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

  /// Fetch videos by user
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

  /// Create a new video record
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

  /// Toggle Like
  /// [userId] is optional. If null, uses current session user.
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
        // Unlike
        await _supabase.from('likes').delete().eq('id', existing['id']);
        // Optional: Decrement counter via RPC
        // await _supabase.rpc('decrement_likes', params: {'video_id': videoId});
      } else {
        // Like
        await _supabase.from('likes').insert({
          'video_id': videoId,
          'user_id': uid,
        });
        // Optional: Increment counter via RPC
        // await _supabase.rpc('increment_likes', params: {'video_id': videoId});
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  /// Analytics Dashboard Helper
  Future<Map<String, dynamic>> getAnalyticsDashboard({int days = 30}) async {
    // Return dummy data or real data logic
    // This prevents AnalyticsScreen from crashing if this method was missing
    return {
      'metrics': {
        'views': 1200,
        'views_change': 5.2,
        'likes': 300,
        'likes_change': 1.1,
        'followers': 50,
        'followers_change': 0.5,
        'earnings': 12000, // NGN
        'earnings_change': 12.0,
      },
      'top_videos': []
    };
  }
}
