import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';

class SaveService {
  final SupabaseClient _supabase = supabase;

  Future<bool> isVideoSaved(String videoId, String userId) async {
    try {
      final response = await _supabase
          .from('saved_videos')
          .select('id')
          .eq('video_id', videoId)
          .eq('user_auth_id', userId) // UPDATED
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
          .eq('user_auth_id', userId) // UPDATED
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
          'user_auth_id': userId, // UPDATED
          'created_at': DateTime.now().toIso8601String(),
        });
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error toggling save: $e');
      rethrow;
    }
 
  }
}
