import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:xprex/services/notification_service.dart';
import 'package:xprex/models/notification_model.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/screens/video_player_screen.dart';
import 'package:xprex/theme.dart';

class PulseScreen extends StatefulWidget {
  const PulseScreen({super.key});

  @override
  State<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends State<PulseScreen> {
  final _notificationService = NotificationService();
  final _videoService = VideoService(); // Needed to fetch video on tap
  
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPulse();
  }

  Future<void> _loadPulse() async {
    final data = await _notificationService.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = data;
        _isLoading = false;
      });
      // Optional: Mark all as read immediately when opening screen? 
      // Or mark individual on tap? Let's just mark all for MVP simplicity to clear badge state mentally.
      _notificationService.markAllAsRead();
    }
  }

  Future<void> _handleTap(NotificationModel item) async {
    // 1. Navigate to Profile
    if (item.type == 'follow') {
      context.push('/u/${item.actorId}');
      return;
    }

    // 2. Navigate to Video (Like/Comment/Repost)
    if (item.videoId != null) {
      // Show loading indicator dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // We need to fetch the full VideoModel to play it
        final video = await _videoService.getVideoById(item.videoId!);
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          if (video != null) {
            // Go to player
            Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (_) => VideoPlayerScreen(videos: [video], initialIndex: 0)
              )
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video no longer available'))
            );
          }
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Pulse', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 64, color: theme.colorScheme.surfaceContainerHighest),
                      const SizedBox(height: 16),
                      Text(
                        'No new heartbeats',
                        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPulse,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (ctx, i) => Divider(height: 1, indent: 72, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
                    itemBuilder: (context, index) {
                      final item = _notifications[index];
                      return _NotificationTile(
                        item: item, 
                        onTap: () => _handleTap(item),
                        theme: theme
                      );
                    },
                  ),
                ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel item;
  final VoidCallback onTap;
  final ThemeData theme;

  const _NotificationTile({required this.item, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: item.isRead ? null : theme.colorScheme.primary.withValues(alpha: 0.05), // Highlight unread
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage: item.actorAvatarUrl != null ? NetworkImage(item.actorAvatarUrl!) : null,
              child: item.actorAvatarUrl == null ? const Icon(Icons.person, size: 20) : null,
            ),
            const SizedBox(width: 12),
            
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                      children: [
                        TextSpan(text: item.actorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: ' ${item.message}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeago.format(item.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Trailing: Video Thumbnail or Follow Button
            if (item.type == 'follow')
              Icon(Icons.person_add, size: 20, color: theme.colorScheme.primary)
            else if (item.videoCoverUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  item.videoCoverUrl!,
                  width: 40,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
