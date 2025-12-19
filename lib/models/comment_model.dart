class CommentModel {
  final String id;
  final String videoId;
  final String authorAuthUserId;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // --- NEW HIERARCHY FIELDS ---
  final String? parentId;
  
  // --- MUTABLE STATE ---
  int replyCount;
  int likesCount;
  bool isLiked;
  List<CommentModel> replies;

  // --- ENRICHED AUTHOR DATA (Now Non-Nullable for Safety) ---
  final String authorUsername; // Changed from String? to String
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  CommentModel({
    required this.id,
    required this.videoId,
    required this.authorAuthUserId,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.replyCount = 0,
    this.likesCount = 0,
    this.isLiked = false,
    this.replies = const [], 
    required this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    // Extract profile data safely
    String username = 'User';
    String? displayName;
    String? avatarUrl;

    if (json.containsKey('profiles') && json['profiles'] != null) {
      final profile = json['profiles'] as Map<String, dynamic>;
      username = profile['username'] as String? ?? 'User';
      displayName = profile['display_name'] as String?;
      avatarUrl = profile['avatar_url'] as String?;
    } else if (json.containsKey('username')) {
       // Fallback if data is flattened
       username = json['username'] ?? 'User';
    }

    return CommentModel(
      id: json['id'] as String,
      videoId: json['video_id'] as String,
      authorAuthUserId: json['user_id'] as String, // Note: DB column might be 'user_id'
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : DateTime.now(),
      
      parentId: json['parent_id'] as String?,
      replyCount: json['reply_count'] as int? ?? 0,
      likesCount: json['likes_count'] as int? ?? 0,
      isLiked: json['is_liked'] == true, 
      replies: [],
      
      authorUsername: username,
      authorDisplayName: displayName,
      authorAvatarUrl: avatarUrl,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'video_id': videoId,
    'user_id': authorAuthUserId,
    'text': text,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'parent_id': parentId,
    'author_username': authorUsername,
  };
}
