import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart'; // Added for share functionality
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/services/save_service.dart';
import 'package:xprex/services/repost_service.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/screens/video_player_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final theme = Theme.of(context);
    
    // Services
    final videoService = VideoService();
    final saveService = SaveService();
    final repostService = RepostService();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface, // Clean background like Pinterest
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found'));
          }

          return DefaultTabController(
            length: 3,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // 1. Minimal AppBar (Pinterest Style)
                  SliverAppBar(
                    backgroundColor: theme.colorScheme.surface,
                    elevation: 0,
                    pinned: true,
                    centerTitle: true,
                    // Replaced Title with a small icon or empty space for cleanliness
                    title: Icon(Icons.bar_chart_rounded, color: theme.colorScheme.onSurface), 
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        color: theme.colorScheme.onSurface,
                        onPressed: () async {
                          // Logout Logic moved to Settings icon
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Sign Out'),
                              content: const Text('Are you sure you want to sign out?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sign Out')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref.read(authServiceProvider).signOut();
                            if (context.mounted) context.go('/login');
                          }
                        },
                      ),
                    ],
                  ),

                  // 2. The Pinterest-Style Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          // Avatar (Clean, no heavy borders)
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                            child: profile.avatarUrl == null ? Icon(Icons.person, size: 50, color: theme.colorScheme.onSurfaceVariant) : null,
                          ),
                          const SizedBox(height: 16),
                          
                          // Display Name (Big & Bold)
                          Text(
                            profile.displayName,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          // Username (Subtle)
                          Text(
                            '@${profile.username}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          
                          const SizedBox(height: 12),

                          // Bio (Centralized)
                          if (profile.bio != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text(
                                profile.bio!,
                                style: theme.textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                          const SizedBox(height: 12),

                          // PINTEREST STYLE STATS (Inline Row)
                          // "182 followers · 63 following · 714k views"
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${profile.followersCount} followers',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 8),
                              const Text('·'),
                              const SizedBox(width: 8),
                              Text(
                                '${profile.totalVideoViews} views',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // PINTEREST ACTION ROW
                          // [ Big Red "Edit/Hub" Button ]  [Share Icon]
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // The "Hero" Button
                              FilledButton(
                                onPressed: () {
                                  // This could open "Edit Profile" or "Monetization Hub"
                                  context.push('/monetization');
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary, // Use primary color (Red/Purple)
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30), // Pill shape
                                  ),
                                ),
                                child: const Text(
                                  'Creator Hub', // Pinterest calls it this, or "Edit Profile"
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              
                              const SizedBox(width: 12),
                              
                              // Share Button (Circular)
                              InkWell(
                                onTap: () {
                                  Share.share('Check out my profile on XpreX: @${profile.username}');
                                },
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: theme.colorScheme.outlineVariant),
                                  ),
                                  child: Icon(Icons.share, size: 20, color: theme.colorScheme.onSurface),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // 3. Tab Bar (Clean, Simple Underline)
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        labelColor: theme.colorScheme.onSurface,
                        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                        indicatorColor: theme.colorScheme.primary,
                        indicatorSize: TabBarIndicatorSize.label,
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        tabs: const [
                          Tab(text: "Created"),
                          Tab(text: "Saved"),
                          Tab(text: "Reposts"),
                        ],
                      ),
                    ),
                    pinned: true,
                  ),
                ];
              },
              // The Tab Views
              body: TabBarView(
                children: [
                  _VideoGrid(loader: videoService.getUserVideos(profile.authUserId)),
                  _VideoGrid(loader: saveService.getSavedVideos(profile.authUserId), emptyMsg: "No saved videos"),
                  _VideoGrid(loader: repostService.getRepostedVideos(profile.authUserId), emptyMsg: "No reposts yet"),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

// Reusable Grid Component (Preserves Tap-to-Play)
class _VideoGrid extends StatelessWidget {
  final Future<List<VideoModel>> loader;
  final String emptyMsg;

  const _VideoGrid({required this.loader, this.emptyMsg = 'No videos yet'});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return FutureBuilder<List<VideoModel>>(
      future: loader,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final videos = snap.data ?? [];

        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.grid_on, size: 48, color: theme.colorScheme.surfaceContainerHighest),
                const SizedBox(height: 8),
                Text(emptyMsg, style: theme.textTheme.bodyMedium),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(2), // Tighter grid
          itemCount: videos.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 9 / 16,
          ),
          itemBuilder: (context, index) {
            final v = videos[index];
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                // Navigate to Player
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => VideoPlayerScreen(
                      videos: videos,
                      initialIndex: index,
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4), // Slightly sharper corners
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (v.coverImageUrl != null)
                      Image.network(v.coverImageUrl!, fit: BoxFit.cover)
                    else
                      Container(color: theme.colorScheme.surfaceContainerHighest),
                    
                    // Subtle gradient for text visibility
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                           gradient: LinearGradient(
                             begin: Alignment.bottomCenter,
                             end: Alignment.topCenter,
                             colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                           )
                        ),
                      ),
                    ),
                    
                    // View count / Title (Mini overlay)
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                '${v.playbackCount}', // Or v.title if preferred
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface, 
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
