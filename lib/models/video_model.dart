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
  // --- NEW FIELDS ---
  final int savesCount;
  final int repostsCount;
  
  final DateTime createdAt;
  final DateTime updatedAt;
  
  String? authorUsername;
  String? authorDisplayName;
  String? authorAvatarUrl;
  bool? isLikedByCurrentUser;

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
    // --- NEW DEFAULTS ---
    this.savesCount = 0,
    this.repostsCount = 0,
    
    required this.createdAt,
    required this.updatedAt,
    this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.isLikedByCurrentUser,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    final video = VideoModel(
      id: json['id'] as String,
      authorAuthUserId: json['author_auth_user_id'] as String,
      storagePath: json['storage_path'] as String,
      coverImageUrl: json['cover_image_url'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      duration: json['duration'] as int,
      playbackCount: json['playback_count'] as int? ?? 0,
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      // --- MAP NEW FIELDS ---
      savesCount: json['saves_count'] as int? ?? 0,
      repostsCount: json['reposts_count'] as int? ?? 0,
      
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );

    if (json.containsKey('profiles')) {
      final profile = json['profiles'] as Map<String, dynamic>?;
      if (profile != null) {
        video.authorUsername = profile['username'] as String?;
        video.authorDisplayName = profile['display_name'] as String?;
        video.authorAvatarUrl = profile['avatar_url'] as String?;
      }
    }
    
    return video;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'author_auth_user_id': authorAuthUserId,
    'storage_path': storagePath,
    'cover_image_url': coverImageUrl,
    'title': title,
    'description': description,
    'duration': duration,
    'playback_count': playbackCount,
    'likes_count': likesCount,
    'comments_count': commentsCount,
    // --- SERIALIZE NEW FIELDS ---
    'saves_count': savesCount,
    'reposts_count': repostsCount,
    
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  VideoModel copyWith({
    String? id,
    String? authorAuthUserId,
    String? storagePath,
    String? coverImageUrl,
    String? title,
    String? description,
    int? duration,
    int? playbackCount,
    int? likesCount,
    int? commentsCount,
    // --- ADD COPY PARAMETERS ---
    int? savesCount,
    int? repostsCount,
    
    DateTime? createdAt,
    DateTime? updatedAt,
    String? authorUsername,
    String? authorDisplayName,
    String? authorAvatarUrl,
    bool? isLikedByCurrentUser,
  }) => VideoModel(
    id: id ?? this.id,
    authorAuthUserId: authorAuthUserId ?? this.authorAuthUserId,
    storagePath: storagePath ?? this.storagePath,
    coverImageUrl: coverImageUrl ?? this.coverImageUrl,
    title: title ?? this.title,
    description: description ?? this.description,
    duration: duration ?? this.duration,
    playbackCount: playbackCount ?? this.playbackCount,
    likesCount: likesCount ?? this.likesCount,
    commentsCount: commentsCount ?? this.commentsCount,
    // --- COPY NEW FIELDS ---
    savesCount: savesCount ?? this.savesCount,
    repostsCount: repostsCount ?? this.repostsCount,
    
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    authorUsername: authorUsername ?? this.authorUsername,
    authorDisplayName: authorDisplayName ?? this.authorDisplayName,
    authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
    isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
  );
}
