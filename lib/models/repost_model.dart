class RepostModel {
  final String id;
  final String videoId;
  final String userAuthId; // Renamed
  final DateTime createdAt;

  RepostModel({
    required this.id,
    required this.videoId,
    required this.userAuthId,
    required this.createdAt,
  });

  factory RepostModel.fromJson(Map<String, dynamic> json) {
    return RepostModel(
      id: json['id'] as String,
      videoId: json['video_id'] as String,
      userAuthId: json['user_auth_id'] as String, // Maps correct column
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'video_id': videoId,
    'user_auth_id': userAuthId,
    'created_at': createdAt.toIso8601String(),
  };
}
