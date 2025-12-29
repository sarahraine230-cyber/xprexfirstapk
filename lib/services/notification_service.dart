import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/models/notification_model.dart';

class NotificationService {
  final SupabaseClient _supabase = supabase;

  Future<List<NotificationModel>> getNotifications() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return [];

    try {
      // We fetch notifications and JOIN the actor's profile and the video details
      final response = await _supabase
          .from('notifications')
          .select('*, actor:profiles!actor_id(username, avatar_url), video:videos(cover_image_url)')
          .eq('recipient_id', uid)
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List)
          .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching notifications: $e');
      return [];
    }
  }

  // --- NEW: FETCH UNREAD COUNT ---
  Future<int> getUnreadCount() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return 0;

    try {
      final count = await _supabase
          .from('notifications')
          .count(CountOption.exact)
          .eq('recipient_id', uid)
          .eq('is_read', false);
      
      return count;
    } catch (e) {
      debugPrint('⚠️ Error fetching unread count: $e');
      return 0;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase.from('notifications').update({'is_read': true}).eq('id', notificationId);
    } catch (e) {
      debugPrint('⚠️ Failed to mark notification as read: $e');
    }
  }
  
  Future<void> markAllAsRead() async {
     final uid = _supabase.auth.currentUser?.id;
     if (uid == null) return;
     try {
       await _supabase.from('notifications').update({'is_read': true}).eq('recipient_id', uid);
     } catch (e) {
       debugPrint('⚠️ Failed to mark all as read: $e');
     }
  }
}
