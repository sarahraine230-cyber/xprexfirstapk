import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/models/comment_model.dart';

class CommentService {
  final SupabaseClient _supabase = supabase;

  Future<List<CommentModel>> getCommentsByVideo(String videoId) async {
    try {
      final response = await _supabase
          .from('comments')
          .select('*, profiles!author_auth_user_id(username, display_name, avatar_url)')
          .eq('video_id', videoId)
          .order('created_at', ascending: false);

      final comments = (response as List)
          .map((json) => CommentModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return comments;
    } catch (e) {
      debugPrint('❌ Error fetching comments: $e');
      rethrow;
    }
  }

  Future<CommentModel> createComment({
    required String videoId,
    required String authorAuthUserId,
    required String text,
  }) async {
    try {
      final now = DateTime.now();
      final data = {
        'video_id': videoId,
        'author_auth_user_id': authorAuthUserId,
        'text': text,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('comments')
          .insert(data)
          .select('*, profiles!author_auth_user_id(username, display_name, avatar_url)')
          .single();

      debugPrint('✅ Comment created');
      return CommentModel.fromJson(response);
    } catch (e) {
      debugPrint('❌ Error creating comment: $e');
      rethrow;
    }
  }

  Future<void> deleteComment(String commentId) async {
    try {
      await _supabase.from('comments').delete().eq('id', commentId);
      debugPrint('✅ Comment deleted');
    } catch (e) {
      debugPrint('❌ Error deleting comment: $e');
      rethrow;
    }
  }
}
