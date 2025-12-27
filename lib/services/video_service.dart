import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart'; // Ensure you have your config here
import 'package:xprex/models/video_model.dart';

class VideoService {
  final _supabase = Supabase.instance.client;

  // --- NEW: FETCH FEED VIA EDGE FUNCTION ---
  Future<List<VideoModel>> getForYouFeed({int limit = 20}) async {
    try {
      // Call the Edge Function 'feed-algorithm'
      final response = await _supabase.functions.invoke('feed-algorithm');
      
      final data = response.data;
      
      if (data == null) {
        return [];
      }

      // Convert JSON list to VideoModels
      // The Edge function returns a list of video objects directly
      final List<dynamic> list = data as List<dynamic>;
      return list.map((json) => VideoModel.fromMap(json)).toList();
      
    } catch (e) {
      print('Error fetching feed from Edge Function: $e');
      // FALLBACK: If Edge Function fails (e.g. timeout), fall back to basic SQL query
      // This ensures the app never shows a blank screen on error.
      return _getFallbackFeed(limit);
    }
  }

  // Basic SQL Fallback (Just recent videos)
  Future<List<VideoModel>> _getFallbackFeed(int limit) async {
    try {
      final response = await _supabase
          .from('videos')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
          
      return (response as List).map((e) => VideoModel.fromMap(e)).toList();
    } catch (e) {
      print('Fallback feed error: $e');
      return [];
    }
  }

  // --- OTHER METHODS (Keep your existing methods below) ---
  
  Future<List<VideoModel>> getUserVideos(String userId) async {
    final response = await _supabase
        .from('videos')
        .select()
        .eq('author_auth_user_id', userId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => VideoModel.fromMap(e)).toList();
  }

  Future<void> recordView(String videoId, String authorId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // 1. Record the view in the 'video_views' history table
    // (We use upsert or ignore if duplicates are allowed, 
    // but generally we want unique views per session/day)
    try {
      await _supabase.from('video_views').insert({
        'video_id': videoId,
        'viewer_id': userId,
        'author_id': authorId,
        // 'duration_seconds': ... (passed in ideally)
      });
    } catch (_) {
      // Ignore duplicate key errors if unique constraint exists
    }

    // 2. Increment the counter on the video itself (RPC is safer for concurrency)
    await _supabase.rpc('increment_video_view', {'video_id': videoId});
  }

  // ... (Keep toggleLike, getShareCount, etc.) ...
  
  // Helper for Like Toggle (example)
  Future<void> toggleLike(String videoId, String userId) async {
     // Check if liked
     final existing = await _supabase
         .from('likes')
         .select()
         .eq('video_id', videoId)
         .eq('user_id', userId)
         .maybeSingle();

     if (existing != null) {
       // Unlike
       await _supabase.from('likes').delete().eq('id', existing['id']);
       await _supabase.rpc('decrement_video_like', {'video_id': videoId});
     } else {
       // Like
       await _supabase.from('likes').insert({
         'video_id': videoId, 
         'user_id': userId
       });
       await _supabase.rpc('increment_video_like', {'video_id': videoId});
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
    // Assuming you don't have a shares table, but likely a column in videos?
    // If purely a counter:
    final res = await _supabase.from('videos').select('playback_count').eq('id', videoId).single();
    // Placeholder logic if share count column doesn't exist yet
    return 0; 
  }
  
  Future<void> recordShare(String videoId, String userId) async {
     // Implement logic if you have a shares table or counter
  }
  
  Future<VideoModel?> getVideoById(String id) async {
    try {
      final data = await _supabase.from('videos').select().eq('id', id).single();
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
      'tags': tags, // Make sure DB column is text[] or jsonb
      'category_id': categoryId, // Ensure DB has this column
    });
  }
}
