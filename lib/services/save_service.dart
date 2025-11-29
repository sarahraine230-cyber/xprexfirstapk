import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/models/video_model.dart'; // Import VideoModel

class SaveService {
  final SupabaseClient _supabase = supabase;

  Future<bool> isVideoSaved(String videoId, String userId) async {
    try {
      final response = await _supabase
          .from('saved_videos')
          .select('id')
          .eq('video_id', videoId)
          .eq('user_auth_id', userId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('❌ Error checking save status: $e');
      return false;
    }
  }

  Future<bool> toggleSave(String videoId, String userId) async {
    try {
      final existing = await _supabase
          .from('saved_videos')
          .select('id')
          .eq('video_id', videoId)
          .eq('user_auth_id', userId)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('saved_videos')
            .delete()
            .eq('id', existing['id']);
        return false;
      } else {
        await _supabase.from('saved_videos').insert({
          'video_id': videoId,
          'user_auth_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error toggling save: $e');
      rethrow;
    }
  }

  // --- NEW: Fetch list of saved videos ---
  Future<List<VideoModel>> getSavedVideos(String userId) async {
    try {
      // We select the saved_video row, but we "expand" the linked video data
      // AND the author profile of that video so the UI looks complete.
      final response = await _supabase
          .from('saved_videos')
          .select('created_at, video:videos(*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url))')
          .eq('user_auth_id', userId)
          .order('created_at', ascending: false);

      final list = <VideoModel>[];
      for (final row in (response as List)) {
        // The video data is nested inside the 'video' key
        final videoJson = (row as Map<String, dynamic>)['video'];
        if (videoJson != null) {
          list.add(VideoModel.fromJson(videoJson as Map<String, dynamic>));
        }
      }
      return list;
    } catch (e) {
      debugPrint('❌ Error fetching saved videos: $e');
      return [];
    }
  }
}
