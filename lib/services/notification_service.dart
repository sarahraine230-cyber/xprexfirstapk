import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationModel {
  final String id;
  final String type; // like, comment, follow, repost
  final bool isRead;
  final DateTime createdAt;
  final String actorName;
  final String? actorAvatarUrl;
  final String? videoCoverUrl;
  final String message;

  NotificationModel({
    required this.id,
    required this.type,
    required this.isRead,
    required this.createdAt,
    required this.actorName,
    this.actorAvatarUrl,
    this.videoCoverUrl,
    required this.message,
  });
}

class NotificationService {
  final SupabaseClient _supabase = supabase;

  Future<List<NotificationModel>> getNotifications() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return [];

    try {
      // Fetch notifications JOINED with Actor Profile and Video Details
      final response = await _supabase
          .from('notifications')
          .select('*, actor:profiles!actor_id(display_name, avatar_url), video:videos(cover_image_url)')
          .eq('recipient_id', uid)
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List).map((json) {
        final actor = json['actor'] as Map<String, dynamic>?;
        final video = json['video'] as Map<String, dynamic>?;
        final type = json['type'] as String;
        
        String msg = 'interacted with you';
        if (type == 'like') msg = 'liked your video';
        if (type == 'comment') msg = 'commented: "Nice!"'; // Simplified for MVP
        if (type == 'follow') msg = 'started following you';
        if (type == 'repost') msg = 'reposted your video';

        return NotificationModel(
          id: json['id'],
          type: type,
          isRead: json['is_read'] ?? false,
          createdAt: DateTime.parse(json['created_at']),
          actorName: actor?['display_name'] ?? 'Someone',
          actorAvatarUrl: actor?['avatar_url'],
          videoCoverUrl: video?['cover_image_url'],
          message: msg,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error fetching notifications: $e');
      return [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase.from('notifications').update({'is_read': true}).eq('id', notificationId);
    } catch (e) {
      // Silent fail
    }
  }
}
