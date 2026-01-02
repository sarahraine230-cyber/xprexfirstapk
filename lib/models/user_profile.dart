class UserProfile {
  final String id;
  final String authUserId;
  final String email;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final int followersCount;
  final int followingCount; // Preserved your new field
  final int totalVideoViews;
  
  // --- PREMIUM LOGIC ---
  final bool _isPremiumDb; // Internal flag from DB
  final DateTime? subscriptionEnd; // [NEW] Expiration Date
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
    this.followingCount = 0,
    this.totalVideoViews = 0,
    bool isPremium = false, // Constructor takes the raw value
    this.subscriptionEnd,
    this.monetizationStatus = 'locked',
    required this.createdAt,
    required this.updatedAt,
  }) : _isPremiumDb = isPremium;

  // --- THE BOUNCER LOGIC ---
  // This is the property the rest of the app reads.
  bool get isPremium {
    // 1. If a subscription end date exists and has passed, revoke premium.
    if (subscriptionEnd != null && DateTime.now().isAfter(subscriptionEnd!)) {
      return false; 
    }
    // 2. Otherwise, trust the database flag (handles active subs, lifetime, or manual grants)
    return _isPremiumDb;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    authUserId: json['auth_user_id'] as String,
    email: json['email'] as String,
    username: json['username'] as String,
    displayName: json['display_name'] as String,
    avatarUrl: json['avatar_url'] as String?,
    bio: json['bio'] as String?,
    followersCount: json['followers_count'] as int? ?? 0,
    followingCount: json['following_count'] as int? ?? 0,
    totalVideoViews: json['total_video_views'] as int? ?? 0,
    
    // Map raw DB values
    isPremium: json['is_premium'] as bool? ?? false,
    subscriptionEnd: json['subscription_end'] != null 
        ? DateTime.tryParse(json['subscription_end'] as String) 
        : null,
        
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
    'following_count': followingCount,
    'total_video_views': totalVideoViews,
    'is_premium': _isPremiumDb, // Write back the raw flag
    'subscription_end': subscriptionEnd?.toIso8601String(), // Write back date
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
    int? followingCount,
    int? totalVideoViews,
    bool? isPremium,
    DateTime? subscriptionEnd,
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
    followingCount: followingCount ?? this.followingCount,
    totalVideoViews: totalVideoViews ?? this.totalVideoViews,
    isPremium: isPremium ?? _isPremiumDb,
    subscriptionEnd: subscriptionEnd ?? this.subscriptionEnd,
    monetizationStatus: monetizationStatus ?? this.monetizationStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
