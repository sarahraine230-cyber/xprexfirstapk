class ProfileModel {
  final String id; // This is the 'id' (uuid) from the profiles table
  final String authUserId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final int followersCount;
  final int followingCount;
  final bool isPremium; // [NEW] Verification Badge Field

  ProfileModel({
    required this.id,
    required this.authUserId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isPremium = false, // Default to false
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      authUserId: json['auth_user_id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      // [NEW] Map the premium status
      isPremium: json['is_premium'] as bool? ?? false,
    );
  }
}
