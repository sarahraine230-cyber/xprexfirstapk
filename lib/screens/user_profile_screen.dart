import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xprex/models/user_profile.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/services/profile_service.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/config/app_links.dart';

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
      setState(() {
        _isFollowing = !_isFollowing;
        _followerCount += _isFollowing ? 1 : -1;
      });
    }
  }

  void _shareProfile() {
    // Generate profile deep link (placeholder logic)
    final url = 'https://xprex.app/u/${widget.userId}';
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    if (_profile == null) return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text("User not found", style: TextStyle(color: Colors.white))));

    final theme = Theme.of(context);
    final isMe = widget.userId == supabase.auth.currentUser?.id;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: const BackButton(color: Colors.white),
          title: Text(_profile!.username, style: const TextStyle(color: Colors.white, fontSize: 16)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              onPressed: _shareProfile,
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz, color: Colors.white),
              onPressed: _showOptionsSheet,
            ),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Avatar
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.grey[900],
                    backgroundImage: NetworkImage(_profile!.avatarUrl ?? 'https://placehold.co/100'),
                  ),
                  const SizedBox(height: 16),
                  // Name
                  Text(
                    _profile!.displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _statItem("Following", _profile!.followingCount.toString()),
                      Container(height: 12, width: 1, color: Colors.grey[800], margin: const EdgeInsets.symmetric(horizontal: 16)),
                      _statItem("Followers", _followerCount.toString()),
                      Container(height: 12, width: 1, color: Colors.grey[800], margin: const EdgeInsets.symmetric(horizontal: 16)),
                      _statItem("Likes", "0"), // Total likes not in profile model yet, placeholder
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Buttons
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _toggleFollow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFollowing ? Colors.grey[800] : theme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(_isFollowing ? 'Following' : 'Follow'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {}, // Message logic placeholder
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey[800]!),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Message'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  // Bio
                  if (_profile!.bio != null && _profile!.bio!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _profile!.bio!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  indicatorColor: theme.primaryColor,
                  indicatorWeight: 2,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  tabs: [
                    const Tab(icon: Icon(Icons.grid_on)), // Created
                    const Tab(icon: Icon(Icons.repeat)),  // Reposts
                  ],
                ),
              ),
              pinned: true,
            ),
          ],
          body: TabBarView(
            children: [
              _buildVideoGrid(_createdVideos),
              _buildVideoGrid(_repostedVideos),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ],
    );
  }

  Widget _buildVideoGrid(List<VideoModel> videos) {
    if (videos.isEmpty) {
      return const Center(child: Text("No videos yet", style: TextStyle(color: Colors.white54)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 9 / 16, // TikTok ratio
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return GestureDetector(
          onTap: () {
            // Navigate to player with this video list
             context.push('/video/${video.id}'); // Placeholder route
          },
          child: Container(
            color: Colors.grey[900],
            child: video.coverImageUrl != null
                ? Image.network(video.coverImageUrl!, fit: BoxFit.cover)
                : const Icon(Icons.play_arrow, color: Colors.white),
          ),
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.black, child: _tabBar);
  }
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
