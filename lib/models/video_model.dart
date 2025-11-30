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
  // --- COUNTERS ---
  final int savesCount;
  final int repostsCount;
  
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // --- RECOMMENDATION ENGINE ---
  final List<String> tags;

  // --- AUTHOR INFO ---
  String? authorUsername;
  String? authorDisplayName;
  String? authorAvatarUrl;
  bool? isLikedByCurrentUser;

  // --- REPOST INFO (RPC) ---
  final String? repostedByUsername;
  final String? repostedByAvatarUrl;

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
    // --- DEFAULTS ---
    this.tags = const [],
    
    this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.isLikedByCurrentUser,
    this.repostedByUsername,
    this.repostedByAvatarUrl,
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
      savesCount: json['saves_count'] as int? ?? 0,
      repostsCount: json['reposts_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      
      // --- MAP TAGS ---
      // Safely handle nulls and convert dynamic list to List<String>
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],

      // --- MAP RPC FIELDS (For Feed) ---
      repostedByUsername: json['reposted_by_username'] as String?,
      repostedByAvatarUrl: json['reposted_by_avatar_url'] as String?,
    );

    // 1. Handle nested profiles (Standard Query)
    if (json.containsKey('profiles')) {
      final profile = json['profiles'] as Map<String, dynamic>?;
      if (profile != null) {
        video.authorUsername = profile['username'] as String?;
        video.authorDisplayName = profile['display_name'] as String?;
        video.authorAvatarUrl = profile['avatar_url'] as String?;
      }
    }
    
    // 2. Handle flattened profile fields (RPC/Feed Query)
    if (json.containsKey('author_username')) video.authorUsername = json['author_username'] as String?;
    if (json.containsKey('author_display_name')) video.authorDisplayName = json['author_display_name'] as String?;
    if (json.containsKey('author_avatar_url')) video.authorAvatarUrl = json['author_avatar_url'] as String?;
    
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
    'saves_count': savesCount,
    'reposts_count': repostsCount,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    // --- SERIALIZE NEW FIELDS ---
    'tags': tags,
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
    int? savesCount,
    int? repostsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    String? authorUsername,
    String? authorDisplayName,
    String? authorAvatarUrl,
    bool? isLikedByCurrentUser,
    String? repostedByUsername,
    String? repostedByAvatarUrl,
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
    savesCount: savesCount ?? this.savesCount,
    repostsCount: repostsCount ?? this.repostsCount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    tags: tags ?? this.tags,
    authorUsername: authorUsername ?? this.authorUsername,
    authorDisplayName: authorDisplayName ?? this.authorDisplayName,
    authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
    isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
    repostedByUsername: repostedByUsername ?? this.repostedByUsername,
    repostedByAvatarUrl: repostedByAvatarUrl ?? this.repostedByAvatarUrl,
  );
}
