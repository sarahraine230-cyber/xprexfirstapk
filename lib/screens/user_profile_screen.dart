import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xprex/models/user_profile.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/services/profile_service.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/config/supabase_config.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId; 
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
      // NOTE: VideoService now automatically handles the privacy filtering!
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
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
          _followerCount += _isFollowing ? 1 : -1;
        });
      }
    }
  }

  // --- UPDATED SHARE LINK ---
  void _shareProfile() {
    // Points to your new Cloudflare Worker
    final url = 'https://profile.getxprex.com?u=${widget.userId}';
    Share.share('Check out ${_profile?.displayName ?? "this user"} on XpreX! $url');
  }

  // --- UPDATED BLOCK & REPORT LOGIC ---
  void _showOptionsSheet() {
    final viewerId = supabase.auth.currentUser?.id;
    if (viewerId == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.red),
                title: const Text('Report User', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmReport(viewerId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: const Text('Block User'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmBlock(viewerId);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmReport(String viewerId) {
    // Simple report for now - reasons can be expanded later
    _profileSvc.reportUser(
      reporterId: viewerId, 
      reportedId: widget.userId, 
      reason: 'Inappropriate Content'
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted. We will review this shortly.')));
  }

  void _confirmBlock(String viewerId) {
    showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Block User?"),
        content: const Text("They will not be able to find your profile, posts or story on XpreX. XpreX will not let them know you blocked them."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _profileSvc.blockUser(blockerId: viewerId, blockedId: widget.userId);
                if (mounted) {
                  context.go('/'); // Kick user back to home
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked')));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to block user')));
              }
            }, 
            child: const Text("Block", style: TextStyle(color: Colors.red))
          ),
        ],
      )
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
              expandedHeight: 400,
              pinned: true,
              backgroundColor: theme.scaffoldBackgroundColor,
              leading: BackButton(color: theme.colorScheme.onSurface),
              // [NEW] Updated Title with Badge
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _profile!.username, 
                      style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_profile!.isPremium) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: Colors.blue, size: 14),
                  ]
                ],
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
                  padding: const EdgeInsets.only(top: 90.0), 
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: theme.dividerColor,
                        backgroundImage: NetworkImage(_profile!.avatarUrl ?? 'https://placehold.co/100'),
                      ),
                      const SizedBox(height: 12),
                      
                      // [NEW] Updated Display Name with Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _profile!.displayName,
                            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (_profile!.isPremium) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, color: Colors.blue, size: 18),
                          ],
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _statItem(context, "Following", _profile!.followingCount.toString()),
                          Container(height: 16, width: 1, color: theme.dividerColor, margin: const EdgeInsets.symmetric(horizontal: 24)),
                          _statItem(context, "Followers", _followerCount.toString()),
                        ],
                      ),
                      const SizedBox(height: 20),
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
                    Tab(icon: Icon(Icons.grid_on)), 
                    Tab(icon: Icon(Icons.repeat)),  
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
        childAspectRatio: 0.75,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return GestureDetector(
          onTap: () {
            context.push('/video-player', extra: {
              'videos': videos,
              'index': index,
              'repostContextUsername': isRepostTab ? _profile?.username : null,
            });
          },
          child: Container(
            color: Colors.black, 
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (video.coverImageUrl != null)
                  Image.network(video.coverImageUrl!, fit: BoxFit.cover)
                else
                  const Center(child: Icon(Icons.play_arrow, color: Colors.white)),
                
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
