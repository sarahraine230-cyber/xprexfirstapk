import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xprex/models/user_profile.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/services/profile_service.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/config/supabase_config.dart';

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
  List<VideoModel> _createdVideos = [];
  List<VideoModel> _repostedVideos = [];
  
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
      // NOTE: In a future update, we should filter these by privacy (public/followers)
      // For now, we fetch all videos returned by the service.
      final created = await _videoSvc.getUserVideos(widget.userId);
      final reposted = await _videoSvc.getRepostedVideos(widget.userId);
      
      final viewerId = supabase.auth.currentUser?.id;
      bool following = false;
      if (viewerId != null && viewerId != widget.userId) {
        following = await _profileSvc.isFollowing(
          followerId: viewerId, 
          followeeId: widget.userId
        );
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _createdVideos = created;
          _repostedVideos = reposted;
          _isFollowing = following;
          _followerCount = profile?.followersCount ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final viewerId = supabase.auth.currentUser?.id;
    if (viewerId == null) return;
    
    setState(() {
      _isFollowing = !_isFollowing;
      _followerCount += _isFollowing ? 1 : -1;
    });
    try {
      if (_isFollowing) {
        await _profileSvc.followUser(
          followerId: viewerId, 
          followeeId: widget.userId
        );
      } else {
        await _profileSvc.unfollowUser(
          followerId: viewerId, 
          followeeId: widget.userId
        );
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
          _followerCount += _isFollowing ? 1 : -1;
        });
      }
    }
  }

  void _shareProfile() {
    final url = 'https://getxprex.com/u/${widget.userId}';
    Share.share('Check out ${_profile?.displayName ?? "this user"} on XpreX! $url');
  }

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.red),
              title: const Text('Report User', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: const Text('Block User'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked')));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Messaging coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_profile == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(leading: const BackButton()),
        body: Center(
          child: Text("User not found", style: TextStyle(color: theme.colorScheme.onSurface)),
        ),
      );
    }

    final isMe = widget.userId == supabase.auth.currentUser?.id;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              expandedHeight: 400, // Adjusted height for info
              pinned: true,
              backgroundColor: theme.scaffoldBackgroundColor,
              leading: BackButton(color: theme.colorScheme.onSurface),
              title: Text(
                _profile!.username, 
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold)
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Icon(Icons.share_outlined, color: theme.colorScheme.onSurface),
                  onPressed: _shareProfile,
                ),
                if (!isMe)
                  IconButton(
                    icon: Icon(Icons.more_horiz, color: theme.colorScheme.onSurface),
                    onPressed: _showOptionsSheet,
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Padding(
                  padding: const EdgeInsets.only(top: 90.0), // push down below navbar
                  child: Column(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: theme.dividerColor,
                        backgroundImage: NetworkImage(_profile!.avatarUrl ?? 'https://placehold.co/100'),
                      ),
                      const SizedBox(height: 12),
                      // Name
                      Text(
                        _profile!.displayName,
                        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      // Stats Row (Likes removed)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _statItem(context, "Following", _profile!.followingCount.toString()),
                          Container(height: 16, width: 1, color: theme.dividerColor, margin: const EdgeInsets.symmetric(horizontal: 24)),
                          _statItem(context, "Followers", _followerCount.toString()),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Buttons
                      if (!isMe)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: _toggleFollow,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _isFollowing ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.primary,
                                    foregroundColor: _isFollowing ? theme.colorScheme.onSurface : theme.colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  child: Text(_isFollowing ? 'Following' : 'Follow'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _handleMessage,
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: theme.dividerColor),
                                    foregroundColor: theme.colorScheme.onSurface,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Message'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      // Bio
                      if (_profile!.bio != null && _profile!.bio!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            _profile!.bio!,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  indicatorColor: theme.colorScheme.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: theme.colorScheme.onSurface,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on)), // Created
                    Tab(icon: Icon(Icons.repeat)),  // Reposts
                  ],
                ),
                theme.scaffoldBackgroundColor,
              ),
              pinned: true,
            ),
          ],
          body: TabBarView(
            children: [
              _buildVideoGrid(_createdVideos),
              _buildVideoGrid(_repostedVideos, isRepostTab: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
      ],
    );
  }

  Widget _buildVideoGrid(List<VideoModel> videos, {bool isRepostTab = false}) {
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_outlined, size: 48, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text("No videos yet", style: TextStyle(color: Colors.grey.withOpacity(0.8))),
          ],
        )
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75, // Standard vertical video ratio
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return GestureDetector(
          onTap: () {
            // NAVIGATE TO SCROLLABLE PLAYER
            // We pass the full list so they can scroll
            context.push('/video-player', extra: {
              'videos': videos,
              'index': index,
              // Pass username ONLY if we are in repost tab to trigger the badge logic
              'repostContextUsername': isRepostTab ? _profile?.username : null,
            });
          },
          child: Container(
            color: Colors.black, // Placeholder background
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (video.coverImageUrl != null)
                  Image.network(video.coverImageUrl!, fit: BoxFit.cover)
                else
                  const Center(child: Icon(Icons.play_arrow, color: Colors.white)),
                
                // View Count Overlay
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Row(
                    children: [
                      const Icon(Icons.play_arrow_outlined, color: Colors.white, size: 14),
                      Text(
                        _formatCount(video.playbackCount),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 2)]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final Color _backgroundColor;
  _SliverAppBarDelegate(this._tabBar, this._backgroundColor);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: _backgroundColor, child: _tabBar);
  }
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
