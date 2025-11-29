import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';

class RepostService {
  final SupabaseClient _supabase = supabase;

  Future<bool> isVideoReposted(String videoId, String userId) async {
    try {
      final response = await _supabase
          .from('reposts')
          .select('id')
          .eq('video_id', videoId)
          .eq('user_auth_id', userId) // UPDATED
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
          .eq('user_auth_id', userId) // UPDATED
          .maybeSingle();

      if (existing != null) {
        await _supabase.from('reposts').delete().eq('id', existing['id']);
        return false;
      } else {
        await _supabase.from('reposts').insert({
          'video_id': videoId,
          'user_auth_id': userId, // UPDATED
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error toggling repost: $e');
      rethrow;
    }
  }
}
