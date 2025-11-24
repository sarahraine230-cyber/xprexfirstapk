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
          .select('*, profiles!comments_author_auth_user_id_fkey(username, display_name, avatar_url)')
          .eq('video_id', videoId)
          .order('created_at', ascending: false);

      final comments = (response as List)
          .map((json) => CommentModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return comments;
    } catch (e) {
      // Graceful fallback when the FK-based embed doesn't exist in this environment
      final msg = e.toString();
      final shouldFallback = msg.contains('PGRST200') ||
          msg.contains('Could not find a relationship between') ||
          msg.contains("Searched for a foreign key relationship between 'comments' and 'profiles'");
      if (!shouldFallback) {
        debugPrint('❌ Error fetching comments: $e');
        rethrow;
      }

      debugPrint('ℹ️ Falling back to 2-step comments fetch without embed');
      // 1) Fetch raw comments
      final rows = await _supabase
          .from('comments')
          .select('*')
          .eq('video_id', videoId)
          .order('created_at', ascending: false);

      if (rows is! List) return [];

      // 2) Fetch author profiles in batch
      final authorIds = <String>{};
      for (final r in rows) {
        final m = (r as Map<String, dynamic>);
        final id = m['author_auth_user_id'];
        if (id is String) authorIds.add(id);
      }

      Map<String, Map<String, dynamic>> profilesByAuthId = {};
      if (authorIds.isNotEmpty) {
        final profs = await _supabase
            .from('profiles')
            .select('auth_user_id, username, display_name, avatar_url')
            .inFilter('auth_user_id', authorIds.toList());
        for (final p in (profs as List)) {
          final pm = (p as Map<String, dynamic>);
          final aid = pm['auth_user_id'] as String?;
          if (aid != null) profilesByAuthId[aid] = pm;
        }
      }

      // 3) Attach profiles to each comment row under the same key PostgREST uses ("profiles")
      final withProfiles = rows.map<Map<String, dynamic>>((r) {
        final m = Map<String, dynamic>.from(r as Map<String, dynamic>);
        final aid = m['author_auth_user_id'] as String?;
        if (aid != null && profilesByAuthId.containsKey(aid)) {
          m['profiles'] = profilesByAuthId[aid];
        }
        return m;
      }).toList();

      return withProfiles.map((json) => CommentModel.fromJson(json)).toList();
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

      try {
        final response = await _supabase
            .from('comments')
            .insert(data)
            .select('*, profiles!comments_author_auth_user_id_fkey(username, display_name, avatar_url)')
            .single();

        debugPrint('✅ Comment created');
        return CommentModel.fromJson(response);
      } catch (e2) {
        final msg = e2.toString();
        final shouldFallback = msg.contains('PGRST200') ||
            msg.contains('Could not find a relationship between') ||
            msg.contains("Searched for a foreign key relationship between 'comments' and 'profiles'");
        if (!shouldFallback) {
          rethrow;
        }
        debugPrint('ℹ️ Falling back to insert + enrich for comments');

        // Insert returning raw row (no embed)
        final inserted = await _supabase
            .from('comments')
            .insert(data)
            .select('*')
            .single();

        // Fetch author profile for enrichment
        final profile = await _supabase
            .from('profiles')
            .select('auth_user_id, username, display_name, avatar_url')
            .eq('auth_user_id', authorAuthUserId)
            .maybeSingle();

        final enriched = Map<String, dynamic>.from(inserted);
        if (profile != null) {
          enriched['profiles'] = profile;
        }
        debugPrint('✅ Comment created (fallback)');
        return CommentModel.fromJson(enriched);
      }
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
