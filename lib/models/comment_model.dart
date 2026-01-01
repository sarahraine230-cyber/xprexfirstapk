class CommentModel {
  final String id;
  final String videoId;
  final String authorAuthUserId;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // --- NEW HIERARCHY FIELDS ---
  final String? parentId; // Null for root comments, set for replies
  
  // --- MUTABLE STATE (For Instant UI Updates) ---
  int replyCount;
  int likesCount;
  bool isLiked; // Track if current user liked this
  List<CommentModel> replies; // Stores loaded replies for this comment

  // --- ENRICHED AUTHOR DATA ---
  String? authorUsername;
  String? authorDisplayName;
  String? authorAvatarUrl;
  bool authorIsPremium; // [NEW] Verification Badge

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
    this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
    this.authorIsPremium = false,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final comment = CommentModel(
      id: json['id'] as String,
      videoId: json['video_id'] as String,
      authorAuthUserId: json['author_auth_user_id'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      
      // Map new database columns
      parentId: json['parent_id'] as String?,
      replyCount: json['reply_count'] as int? ?? 0,
      likesCount: json['likes_count'] as int? ?? 0,
      
      // This will be populated by the Service logic later
      isLiked: json['is_liked'] == true, 
      replies: [], // Start with empty list of replies
    );

    // Profile Enrichment (from join)
    if (json.containsKey('profiles')) {
      final profile = json['profiles'] as Map<String, dynamic>?;
      if (profile != null) {
        comment.authorUsername = profile['username'] as String?;
        comment.authorDisplayName = profile['display_name'] as String?;
        comment.authorAvatarUrl = profile['avatar_url'] as String?;
        // [NEW] Map premium status
        comment.authorIsPremium = profile['is_premium'] as bool? ?? false;
      }
    }
    
    return comment;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'video_id': videoId,
    'author_auth_user_id': authorAuthUserId,
    'text': text,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'parent_id': parentId,
    'reply_count': replyCount,
    'likes_count': likesCount,
    'is_liked': isLiked,
  };
}
