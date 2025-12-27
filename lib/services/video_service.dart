import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart'; 
import 'package:xprex/models/video_model.dart';

class VideoService {
  final _supabase = Supabase.instance.client;

  // --- FETCH FEED VIA EDGE FUNCTION ---
  Future<List<VideoModel>> getForYouFeed({int limit = 20}) async {
    try {
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

  // Basic SQL Fallback
  Future<List<VideoModel>> _getFallbackFeed(int limit) async {
    try {
      final response = await _supabase
          .from('videos')
          .select('*, profiles:author_auth_user_id(username, display_name, avatar_url)')
          .order('created_at', ascending: false)
          .limit(limit);
          
      return (response as List).map((e) => VideoModel.fromMap(e)).toList();
    } catch (e) {
      print('Fallback feed error: $e');
      return [];
    }
  }

  // --- ANALYTICS METHODS ---

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

  // --- PROFILE & VIDEO METHODS ---
  
  Future<List<VideoModel>> getUserVideos(String userId) async {
    final response = await _supabase
        .from('videos')
        .select('*, profiles:author_auth_user_id(username, display_name, avatar_url)')
        .eq('author_auth_user_id', userId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => VideoModel.fromMap(e)).toList();
  }

  // --- SURGERY COMPLETE: Method Restored ---
  Future<List<VideoModel>> getRepostedVideos(String userId) async {
    try {
      // Fetching from 'reposts' joining 'videos' and then 'profiles'
      // We use the explicit foreign key syntax to be safe
      final response = await _supabase
          .from('reposts')
          .select('created_at, video:videos(*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url))')
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

    try {
      await _supabase.from('video_views').insert({
        'video_id': videoId,
        'viewer_id': userId,
        'author_id': authorId,
      });
    } catch (_) {}

    await _supabase.rpc('increment_video_view', params: {'video_id': videoId});
  }

  Future<void> toggleLike(String videoId, String userId) async {
     final existing = await _supabase
         .from('likes')
         .select()
         .eq('video_id', videoId)
         .eq('user_id', userId)
         .maybeSingle();

     if (existing != null) {
       await _supabase.from('likes').delete().eq('id', existing['id']);
       await _supabase.rpc('decrement_video_like', params: {'video_id': videoId});
     } else {
       await _supabase.from('likes').insert({
         'video_id': videoId, 
         'user_id': userId
       });
       await _supabase.rpc('increment_video_like', params: {'video_id': videoId});
     }
  }
  
  Future<bool> isVideoLikedByUser(String videoId, String userId) async {
    final count = await _supabase
        .from('likes')
        .count()
        .eq('video_id', videoId)
        .eq('user_id', userId);
    return count > 0;
  }
  
  Future<int> getShareCount(String videoId) async {
    final res = await _supabase.from('videos').select('playback_count').eq('id', videoId).single();
    return (res['playback_count'] as int?) ?? 0; 
  }
  
  Future<void> recordShare(String videoId, String userId) async {
     // Implement logic if you have a shares table or counter
  }
  
  Future<VideoModel?> getVideoById(String id) async {
    try {
      final data = await _supabase.from('videos').select('*, profiles:author_auth_user_id(username, display_name, avatar_url)').eq('id', id).single();
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
  }) async {
    await _supabase.from('videos').insert({
      'author_auth_user_id': authorAuthUserId,
      'storage_path': storagePath,
      'title': title,
      'description': description,
      'cover_image_url': coverImageUrl,
      'duration': duration,
      'tags': tags, 
    });
  }
}
