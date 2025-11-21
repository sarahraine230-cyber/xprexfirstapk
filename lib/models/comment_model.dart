class CommentModel {
  final String id;
  final String videoId;
  final String authorAuthUserId;
  final String text;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  String? authorUsername;
  String? authorDisplayName;
  String? authorAvatarUrl;

  CommentModel({
    required this.id,
    required this.videoId,
    required this.authorAuthUserId,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.authorUsername,
    this.authorDisplayName,
    this.authorAvatarUrl,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final comment = CommentModel(
      id: json['id'] as String,
      videoId: json['video_id'] as String,
      authorAuthUserId: json['author_auth_user_id'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
    
    if (json.containsKey('profiles')) {
      final profile = json['profiles'] as Map<String, dynamic>?;
      if (profile != null) {
        comment.authorUsername = profile['username'] as String?;
        comment.authorDisplayName = profile['display_name'] as String?;
        comment.authorAvatarUrl = profile['avatar_url'] as String?;
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
  };
}
