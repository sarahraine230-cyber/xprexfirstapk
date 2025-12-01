import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/models/user_profile.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/services/profile_service.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/screens/video_player_screen.dart'; // Import Player

class UserProfileScreen extends StatefulWidget {
  final String userId; // Supabase auth user id
  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _profileSvc = ProfileService();
  final _videoSvc = VideoService();
  UserProfile? _profile;
  List<_ProfileVideoItem>? _items;
  bool _loading = true;
  bool _isFollowing = false;
  int _followerCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await _profileSvc.getProfileByAuthId(widget.userId);
      final videos = await _videoSvc.getUserVideos(widget.userId);
      final reposted = await _videoSvc.getRepostedVideos(widget.userId);
      final viewerId = supabase.auth.currentUser?.id;
      bool following = false;
      if (viewerId != null) {
        following = await _profileSvc.isFollowing(followerAuthUserId: viewerId, followeeAuthUserId: widget.userId);
      }
      final followers = await _profileSvc.getFollowerCount(widget.userId);
      if (mounted) {
        setState(() {
          _profile = profile;
          _items = [
            ...videos.map((v) => _ProfileVideoItem(video: v, isRepost: false)),
            ...reposted.map((v) => _ProfileVideoItem(video: v, isRepost: true)),
          ];
          _isFollowing = following;
          _followerCount = followers;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load user profile: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final viewerId = supabase.auth.currentUser?.id;
    if (viewerId == null || viewerId == widget.userId) return;
    try {
      if (_isFollowing) {
        await _profileSvc.unfollowUser(followerAuthUserId: viewerId, followeeAuthUserId: widget.userId);
        setState(() {
          _isFollowing = false;
          _followerCount = (_followerCount - 1).clamp(0, 1 << 31);
        });
      } else {
        await _profileSvc.followUser(followerAuthUserId: viewerId, followeeAuthUserId: widget.userId);
        setState(() {
          _isFollowing = true;
          _followerCount += 1;
        });
      }
    } catch (e) {
      debugPrint('❌ toggle follow error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_profile == null)
              ? const Center(child: Text('User not found'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          backgroundImage: _profile!.avatarUrl != null && _profile!.avatarUrl!.isNotEmpty
                              ? NetworkImage(_profile!.avatarUrl!)
                              : null,
                          child: (_profile!.avatarUrl == null || _profile!.avatarUrl!.isEmpty)
                              ? Icon(Icons.person, size: 56, color: theme.colorScheme.onSurfaceVariant)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(_profile!.displayName, style: theme.textTheme.headlineSmall),
                        Text('@${_profile!.username}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        if (_profile!.bio != null) ...[
                          const SizedBox(height: 8),
                          Text(_profile!.bio!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _stat(theme, 'Followers', '$_followerCount'),
                            _stat(theme, 'Views', '${_profile!.totalVideoViews}'),
                            _stat(theme, 'Videos', '${_items?.length ?? 0}'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (supabase.auth.currentUser?.id != widget.userId)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _toggleFollow,
                              icon: Icon(_isFollowing ? Icons.person_remove : Icons.person_add),
                              label: Text(_isFollowing ? 'Unfollow' : 'Follow'),
                              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                            ),
                          ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Videos', style: theme.textTheme.titleLarge),
                        ),
                        const SizedBox(height: 12),
                         if ((_items ?? const []).isEmpty)
                          Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text('No videos yet', style: theme.textTheme.bodyMedium),
                            ),
                          )
                        else
                           GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                             itemCount: _items!.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 9 / 16,
                            ),
                            itemBuilder: (context, index) {
                               final item = _items![index];
                               final v = item.video;
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  // --- NAVIGATE TO PLAYER ---
                                  // We must extract the pure List<VideoModel> from our wrapper items
                                  final allVideos = _items!.map((e) => e.video).toList();
                                  
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => VideoPlayerScreen(
                                        videos: allVideos,
                                        initialIndex: index,
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (v.coverImageUrl != null)
                                        Image.network(v.coverImageUrl!, fit: BoxFit.cover)
                                      else
                                        Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.slow_motion_video, color: Colors.white70)),
                                       
                                       // Repost Badge
                                       if (item.isRepost)
                                         Positioned(
                                           top: 6,
                                           left: 6,
                                           child: Container(
                                             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                             decoration: BoxDecoration(
                                               color: Colors.black.withValues(alpha: 0.5),
                                               borderRadius: BorderRadius.circular(6),
                                             ),
                                             child: const Row(
                                               mainAxisSize: MainAxisSize.min,
                                               children: [
                                                 Icon(Icons.repeat, color: Colors.white, size: 12),
                                                 SizedBox(width: 4),
                                                 Text('Repost', style: TextStyle(color: Colors.white, fontSize: 10)),
                                               ],
                                             ),
                                           ),
                                         ),
                                         
                                      Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                          color: Colors.black.withValues(alpha: 0.4),
                                          width: double.infinity,
                                          child: Text(
                                            v.title,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
              ),
    );
  }

  Widget _stat(ThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _ProfileVideoItem {
  final VideoModel video;
  final bool isRepost;
  _ProfileVideoItem({required this.video, required this.isRepost});
}
