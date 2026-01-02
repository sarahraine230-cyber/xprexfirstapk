import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/models/comment_model.dart';

class CommentService {
  final SupabaseClient _supabase = supabase;

  /// Fetches ROOT comments (parent_id is null) for a specific video.
  /// Also checks if the current user has liked them.
  Future<List<CommentModel>> getCommentsByVideo(String videoId) async {
    try {
      // 1. Fetch Root Comments (no parent)
      // [NEW] Added is_premium to select
      final response = await _supabase
          .from('comments')
          .select('*, profiles!comments_author_auth_user_id_fkey(username, display_name, avatar_url, is_premium)')
          .eq('video_id', videoId)
          .filter('parent_id', 'is', null)
          .order('created_at', ascending: false);

      final comments = (response as List)
          .map((json) => CommentModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // 2. Enrich with "isLiked" status if user is logged in
      await _enrichIsLiked(comments);

      return comments;
    } catch (e) {
      debugPrint('❌ Error fetching root comments: $e');
      // If the embed failed (foreign key issue), fall back to manual join
      if (e.toString().contains('PGRST200') || e.toString().contains('relationship')) {
        return _fallbackFetchComments(videoId, isRoot: true);
      }
      rethrow;
    }
  }

  /// Fetches REPLIES for a specific parent comment.
  Future<List<CommentModel>> getReplies(String parentId) async {
    try {
      // [NEW] Added is_premium to select
      final response = await _supabase
          .from('comments')
          .select('*, profiles!comments_author_auth_user_id_fkey(username, display_name, avatar_url, is_premium)')
          .eq('parent_id', parentId) // FILTER: Children of this parent
          .order('created_at', ascending: true); // Oldest first for conversation flow

      final replies = (response as List)
          .map((json) => CommentModel.fromJson(json as Map<String, dynamic>))
          .toList();

      await _enrichIsLiked(replies);

      return replies;
    } catch (e) {
      debugPrint('❌ Error fetching replies: $e');
      if (e.toString().contains('PGRST200') || e.toString().contains('relationship')) {
        return _fallbackFetchComments(parentId, isRoot: false);
      }
      rethrow;
    }
  }

  /// Helper: Checks which comments in the list are liked by the current user
  Future<void> _enrichIsLiked(List<CommentModel> comments) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null || comments.isEmpty) return;

    try {
      final ids = comments.map((c) => c.id).toList();
      // Fetch only the likes that belong to this user for these specific comments
      final likes = await _supabase
          .from('comment_likes')
          .select('comment_id')
          .eq('user_auth_id', uid)
          .inFilter('comment_id', ids);

      final likedIds = (likes as List).map((m) => m['comment_id'] as String).toSet();

      for (var c in comments) {
        c.isLiked = likedIds.contains(c.id);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to enrich comment likes: $e');
    }
  }

  Future<CommentModel> createComment({
    required String videoId,
    required String authorAuthUserId,
    required String text,
    String? parentId, // Optional: if provided, this is a reply
  }) async {
    try {
      final now = DateTime.now();
      final data = {
        'video_id': videoId,
        'author_auth_user_id': authorAuthUserId,
        'text': text,
        'parent_id': parentId, // Save relationship
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      try {
        // [NEW] Added is_premium to select
        final response = await _supabase
            .from('comments')
            .insert(data)
            .select('*, profiles!comments_author_auth_user_id_fkey(username, display_name, avatar_url, is_premium)')
            .single();
            
        debugPrint('✅ Comment/Reply created');
        return CommentModel.fromJson(response);
      } catch (e2) {
        // Fallback for manual profile fetch
        if (e2.toString().contains('relationship')) {
           final inserted = await _supabase
            .from('comments')
            .insert(data)
            .select('*')
            .single();
            
           // [NEW] Added is_premium to select
           final profile = await _supabase
            .from('profiles')
            .select('auth_user_id, username, display_name, avatar_url, is_premium')
            .eq('auth_user_id', authorAuthUserId)
            .maybeSingle();

            final enriched = Map<String, dynamic>.from(inserted);
            if (profile != null) enriched['profiles'] = profile;
            
            return CommentModel.fromJson(enriched);
        }
        rethrow;
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

  /// Toggles like status on a specific comment
  Future<bool> toggleCommentLike(String commentId) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw Exception('User not logged in');

    try {
      // Check if already liked
      final existing = await _supabase
          .from('comment_likes')
          .select()
          .eq('comment_id', commentId)
          .eq('user_auth_id', uid)
          .maybeSingle();

      if (existing != null) {
        // Unlike
        await _supabase
            .from('comment_likes')
            .delete()
            .eq('comment_id', commentId)
            .eq('user_auth_id', uid);
        return false;
      } else {
        // Like
        await _supabase.from('comment_likes').insert({
          'comment_id': commentId,
          'user_auth_id': uid,
        });
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error toggling comment like: $e');
      rethrow;
    }
  }

  // --- Fallback Method (preserved from previous version, updated for hierarchy) ---
  Future<List<CommentModel>> _fallbackFetchComments(String id, {required bool isRoot}) async {
     debugPrint('ℹ️ Falling back to 2-step comments fetch');
     final builder = _supabase.from('comments').select('*');
     
     final List<dynamic> rows;
     if (isRoot) {
       rows = await builder
           .eq('video_id', id)
           .filter('parent_id', 'is', null) 
           .order('created_at', ascending: false);
     } else {
       rows = await builder
           .eq('parent_id', id)
           .order('created_at', ascending: true);
     }
     
      // 2) Fetch author profiles in batch
      final authorIds = <String>{};
      for (final r in rows) {
        final m = (r as Map<String, dynamic>);
        final aid = m['author_auth_user_id'];
        if (aid is String) authorIds.add(aid);
      }

      Map<String, Map<String, dynamic>> profilesByAuthId = {};
      if (authorIds.isNotEmpty) {
        // [NEW] Added is_premium to select
        final profs = await _supabase
            .from('profiles')
            .select('auth_user_id, username, display_name, avatar_url, is_premium')
            .inFilter('auth_user_id', authorIds.toList());

        for (final p in (profs as List)) {
          final pm = (p as Map<String, dynamic>);
          final aid = pm['auth_user_id'] as String?;
          if (aid != null) profilesByAuthId[aid] = pm;
        }
      }

      // 3) Merge
      final withProfiles = rows.map<Map<String, dynamic>>((r) {
        final m = Map<String, dynamic>.from(r as Map<String, dynamic>);
        final aid = m['author_auth_user_id'] as String?;
        if (aid != null && profilesByAuthId.containsKey(aid)) {
          m['profiles'] = profilesByAuthId[aid];
        }
        return m;
      }).toList();

      final results = withProfiles.map((json) => CommentModel.fromJson(json)).toList();
      await _enrichIsLiked(results);
      return results;
  }
}
