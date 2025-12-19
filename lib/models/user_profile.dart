class UserProfile {
  final String id;
  final String authUserId;
  final String email;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final int followersCount;
  final int followingCount; // NEW: Added this field
  final int totalVideoViews;
  final bool isPremium;
  final String monetizationStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.authUserId,
    required this.email,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.followersCount = 0,
    this.followingCount = 0, // NEW: Default to 0
    this.totalVideoViews = 0,
    this.isPremium = false,
    this.monetizationStatus = 'locked',
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    authUserId: json['auth_user_id'] as String,
    email: json['email'] as String,
    username: json['username'] as String,
    displayName: json['display_name'] as String,
    avatarUrl: json['avatar_url'] as String?,
    bio: json['bio'] as String?,
    followersCount: json['followers_count'] as int? ?? 0,
    followingCount: json['following_count'] as int? ?? 0, // NEW: Read from DB
    totalVideoViews: json['total_video_views'] as int? ?? 0,
    isPremium: json['is_premium'] as bool? ?? false,
    monetizationStatus: json['monetization_status'] as String? ?? 'locked',
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'auth_user_id': authUserId,
    'email': email,
    'username': username,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'bio': bio,
    'followers_count': followersCount,
    'following_count': followingCount, // NEW: Write to JSON
    'total_video_views': totalVideoViews,
    'is_premium': isPremium,
    'monetization_status': monetizationStatus,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  UserProfile copyWith({
    String? id,
    String? authUserId,
    String? email,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    int? followersCount,
    int? followingCount, // NEW: Support copying
    int? totalVideoViews,
    bool? isPremium,
    String? monetizationStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserProfile(
    id: id ?? this.id,
    authUserId: authUserId ?? this.authUserId,
    email: email ?? this.email,
    username: username ?? this.username,
    displayName: displayName ?? this.displayName,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    bio: bio ?? this.bio,
    followersCount: followersCount ?? this.followersCount,
    followingCount: followingCount ?? this.followingCount, // NEW
    totalVideoViews: totalVideoViews ?? this.totalVideoViews,
    isPremium: isPremium ?? this.isPremium,
    monetizationStatus: monetizationStatus ?? this.monetizationStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
