import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/models/comment_model.dart';

class CommentService {
  final SupabaseClient _supabase = supabase;

  /// Fetches comments for a video.
  /// Renamed from getCommentsByVideo to getComments to match FeedScreen usage.
  Future<List<CommentModel>> getComments(String videoId) async {
    try {
      final response = await _supabase
          .from('comments')
          .select('*, profiles(username, display_name, avatar_url)')
          .eq('video_id', videoId)
          .order('created_at', ascending: false);

      final comments = (response as List)
          .map((json) => CommentModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return comments;
    } catch (e) {
      debugPrint('❌ Error fetching comments: $e');
      return [];
    }
  }

  Future<void> postComment(String videoId, String text) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await _supabase.from('comments').insert({
        'video_id': videoId,
        'user_id': uid,
        'text': text,
      });
      // Optionally trigger an RPC to increment counter if you have one
    } catch (e) {
      debugPrint('❌ Error posting comment: $e');
      rethrow;
    }
  }
}
