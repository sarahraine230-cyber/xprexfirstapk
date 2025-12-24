class VideoModel {
  final String id;
  final String authorAuthUserId;
  final String storagePath;
  final String? coverImageUrl;
  final String title;
  final String? description;
  final int duration;
  final int playbackCount;
  final int likesCount;
  final int commentsCount;
  final int savesCount;
  final int repostsCount;
  
  final DateTime createdAt;
  final DateTime updatedAt;
  
  final List<String> tags;

  String? authorUsername;
  String? authorDisplayName;
  String? authorAvatarUrl;
  bool? isLikedByCurrentUser;

  final String? repostedByUsername;
  final String? repostedByAvatarUrl;

  // --- NEW: PROCESSING CHECK ---
  // If the path DOES NOT end in '_optimized.mp4', it's still raw/processing.
  // (Adjust this string match if your backend naming convention differs)
  bool get isProcessing => !storagePath.endsWith('_optimized.mp4');

  VideoModel({
    required this.id,
    required this.authorAuthUserId,
    required this.storagePath,
    this.coverImageUrl,
    required this.title,
    this.description,
    required this.duration,
    this.playbackCount = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.savesCount = 0,
    this.repostsCount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    
    this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.isLikedByCurrentUser,
    this.repostedByUsername,
    this.repostedByAvatarUrl,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    // Safely handle profiles relation
    final profile = json['profiles'] as Map<String, dynamic>?;

    return VideoModel(
      id: json['id'].toString(),
      authorAuthUserId: json['author_auth_user_id'] as String,
      storagePath: json['storage_path'] as String,
      coverImageUrl: json['cover_image_url'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      duration: json['duration'] as int? ?? 0,
      playbackCount: json['playback_count'] as int? ?? 0,
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      savesCount: json['saves_count'] as int? ?? 0,
      repostsCount: json['reposts_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      
      authorUsername: profile?['username'] as String?,
      authorDisplayName: profile?['display_name'] as String?,
      authorAvatarUrl: profile?['avatar_url'] as String?,
      
      // Handle Supabase's "empty list if no match" quirk for relations
      isLikedByCurrentUser: false, // Populated via separate check usually
      
      repostedByUsername: json['reposted_by_username'] as String?,
      repostedByAvatarUrl: json['reposted_by_avatar_url'] as String?,
    );
  }
}
