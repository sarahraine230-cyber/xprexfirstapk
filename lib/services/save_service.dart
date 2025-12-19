import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/models/video_model.dart';

class SaveService {
  final SupabaseClient _supabase = supabase;

  // Now handles userId internally
  Future<bool> isSaved(String videoId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return false;

    try {
      final response = await _supabase
          .from('saved_videos')
          .select('id')
          .eq('video_id', videoId)
          .eq('user_id', uid)
          .maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('❌ Error checking save status: $e');
      return false;
    }
  }

  // Now handles userId internally
  Future<void> toggleSave(String videoId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      final existing = await _supabase
          .from('saved_videos')
          .select('id')
          .eq('video_id', videoId)
          .eq('user_id', uid)
          .maybeSingle();

      if (existing != null) {
        await _supabase.from('saved_videos').delete().eq('id', existing['id']);
      } else {
        await _supabase.from('saved_videos').insert({
          'video_id': videoId,
          'user_id': uid,
        });
      }
    } catch (e) {
      debugPrint('❌ Error toggling save: $e');
      rethrow;
    }
  }

  // Called by ProfileScreen
  Future<List<VideoModel>> getSavedVideos(String userId) async {
    try {
      final response = await _supabase
          .from('saved_videos')
          .select('created_at, video:videos(*, profiles(username, display_name, avatar_url))')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final list = <VideoModel>[];
      for (final row in (response as List)) {
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
