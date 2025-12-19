import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/models/video_model.dart'; // Import VideoModel

class RepostService {
  final SupabaseClient _supabase = supabase;

  Future<bool> isVideoReposted(String videoId, String userId) async {
    try {
      final response = await _supabase
          .from('reposts')
          .select('id')
          .eq('video_id', videoId)
          .eq('user_auth_id', userId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('❌ Error checking repost status: $e');
      return false;
    }
  }

  Future<bool> toggleRepost(String videoId, String userId) async {
    try {
      final existing = await _supabase
          .from('reposts')
          .select('id')
          .eq('video_id', videoId)
          .eq('user_auth_id', userId)
          .maybeSingle();

      if (existing != null) {
        await _supabase.from('reposts').delete().eq('id', existing['id']);
        return false;
      } else {
        await _supabase.from('reposts').insert({
          'video_id': videoId,
          'user_auth_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error toggling repost: $e');
      rethrow;
    }
  }

  // --- NEW: Fetch list of reposted videos ---
  Future<List<VideoModel>> getRepostedVideos(String userId) async {
    try {
      final response = await _supabase
          .from('reposts')
          .select('created_at, video:videos(*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url))')
          .eq('user_auth_id', userId)
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
      debugPrint('❌ Error fetching reposted videos: $e');
      return [];
    }
  }
}
