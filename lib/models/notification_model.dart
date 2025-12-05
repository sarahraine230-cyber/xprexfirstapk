class NotificationModel {
  final String id;
  final String type; // like, comment, follow, repost
  final bool isRead;
  final DateTime createdAt;
  
  // Navigation IDs
  final String actorId;
  final String? videoId;
  
  // Display Data
  final String actorName;
  final String? actorAvatarUrl;
  final String? videoCoverUrl;
  final String message;

  NotificationModel({
    required this.id,
    required this.type,
    required this.isRead,
    required this.createdAt,
    required this.actorId,
    this.videoId,
    required this.actorName,
    this.actorAvatarUrl,
    this.videoCoverUrl,
    required this.message,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    final video = json['video'] as Map<String, dynamic>?;
    final type = json['type'] as String;
    
    String msg = 'interacted with you';
    if (type == 'like') msg = 'liked your video';
    if (type == 'comment') msg = 'commented on your video';
    if (type == 'follow') msg = 'started following you';
    if (type == 'repost') msg = 'reposted your video';

    return NotificationModel(
      id: json['id'],
      type: type,
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      actorId: json['actor_id'], // Critical for navigation
      videoId: json['video_id'], // Critical for navigation
      actorName: actor?['username'] ?? 'Someone',
      actorAvatarUrl: actor?['avatar_url'],
      videoCoverUrl: video?['cover_image_url'],
      message: msg,
    );
  }
}
