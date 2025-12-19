import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/models/video_model.dart';

class RepostService {
  final SupabaseClient _supabase = supabase;

  // Called by FeedScreen as "repostVideo(id)"
  Future<void> repostVideo(String videoId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    await toggleRepost(videoId, uid);
  }

  Future<bool> toggleRepost(String videoId, String userId) async {
    try {
      final existing = await _supabase
          .from('reposts')
          .select('id')
          .eq('video_id', videoId)
          .eq('user_id', userId) // Changed from user_auth_id to user_id to match standard schema
          .maybeSingle();

      if (existing != null) {
        await _supabase.from('reposts').delete().eq('id', existing['id']);
        return false;
      } else {
        await _supabase.from('reposts').insert({
          'video_id': videoId,
          'user_id': userId,
        });
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error toggling repost: $e');
      // If column name is user_auth_id in your DB, swap user_id above
      rethrow;
    }
  }

  // Called by ProfileScreen
  Future<List<VideoModel>> getRepostedVideos(String userId) async {
    try {
      // Fetch reposts and join related video + profile data
      final response = await _supabase
          .from('reposts')
          .select('created_at, video:videos(*, profiles(username, display_name, avatar_url))')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final list = <VideoModel>[];
      for (final row in (response as List)) {
        final videoJson = (row as Map<String, dynamic>)['video'];
        if (videoJson != null) {
          // Add repost info so UI knows who reposted if needed
          videoJson['reposted_at'] = row['created_at'];
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
