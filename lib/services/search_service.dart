import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/models/profile_model.dart';

class SearchService {
  final SupabaseClient _supabase = supabase;

  Future<List<ProfileModel>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      // .select() fetches all columns, including 'is_premium', so this is safe.
      final response = await _supabase
          .from('profiles')
          .select()
          .or('username.ilike.%$query%,display_name.ilike.%$query%')
          .limit(20);

      return (response as List)
          .map((e) => ProfileModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error searching users: $e');
      return [];
    }
  }

  Future<List<VideoModel>> searchVideos(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      // 1. Search Title/Description
      // [NEW] Added is_premium to the profile join so video authors show the badge
      final textResponse = await _supabase
          .from('videos')
          .select('*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url, is_premium)')
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .order('likes_count', ascending: false)
          .limit(20);

      // 2. Search Tags (Array contains)
      // [NEW] Added is_premium here too
      final tagResponse = await _supabase
          .from('videos')
          .select('*, profiles!videos_author_auth_user_id_fkey(username, display_name, avatar_url, is_premium)')
          .contains('tags', [query.toLowerCase()]) 
          .limit(20);

      // 3. Merge results to remove duplicates
      final Map<String, VideoModel> merged = {};
      for (var json in textResponse) {
        final v = VideoModel.fromJson(json);
        merged[v.id] = v;
      }
      for (var json in tagResponse) {
        final v = VideoModel.fromJson(json);
        merged[v.id] = v;
      }

      return merged.values.toList();
    } catch (e) {
      debugPrint('❌ Error searching videos: $e');
      return [];
    }
  }
}
