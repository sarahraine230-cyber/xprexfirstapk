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
  final int sharesCount;
  
  // --- NEW FIELDS ---
  final String privacyLevel; // 'public', 'followers', 'private'
  final bool allowComments;
  
  final DateTime createdAt;
  final DateTime updatedAt;
  
  final List<String> tags;

  String? authorUsername;
  String? authorDisplayName;
  String? authorAvatarUrl;
  bool? isLikedByCurrentUser;

  final String? repostedByUsername;
  final String? repostedByAvatarUrl;

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
    this.sharesCount = 0,
    // --- NEW DEFAULTS ---
    this.privacyLevel = 'public',
    this.allowComments = true,
    
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

  factory VideoModel.fromMap(Map<String, dynamic> json) {
    // Handle Supabase join structures
    Map<String, dynamic>? profileMap;
    final profileData = json['profiles'];
    if (profileData is List) {
      if (profileData.isNotEmpty) {
        profileMap = profileData.first as Map<String, dynamic>;
      }
    } else if (profileData is Map) {
      profileMap = profileData as Map<String, dynamic>;
    }

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
      sharesCount: json['shares_count'] as int? ?? 0,
      
      // --- MAP NEW FIELDS ---
      privacyLevel: json['privacy_level'] as String? ?? 'public',
      allowComments: json['allow_comments'] as bool? ?? true,
      
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      
      authorUsername: profileMap?['username'] as String?,
      authorDisplayName: profileMap?['display_name'] as String?,
      authorAvatarUrl: profileMap?['avatar_url'] as String?,
      
      isLikedByCurrentUser: false, 
      
      repostedByUsername: json['repost_username'] as String?,
      repostedByAvatarUrl: json['repost_avatar_url'] as String?,
    );
  }
}
