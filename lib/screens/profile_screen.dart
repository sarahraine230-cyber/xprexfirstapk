import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/services/save_service.dart';
import 'package:xprex/services/repost_service.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/screens/video_player_screen.dart';
import 'package:xprex/screens/profile_setup_screen.dart'; // Import for Edit link

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
      backgroundColor: theme.colorScheme.surface,
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
                  // 1. Pinterest-Style AppBar (Minimal)
                  SliverAppBar(
                    backgroundColor: theme.colorScheme.surface,
                    elevation: 0,
                    pinned: true,
                    leading: Icon(Icons.bar_chart_rounded, color: theme.colorScheme.onSurface),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        color: theme.colorScheme.onSurface,
                        onPressed: () async {
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

                  // 2. The Profile Content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                            child: profile.avatarUrl == null ? Icon(Icons.person, size: 50, color: theme.colorScheme.onSurfaceVariant) : null,
                          ),
                          const SizedBox(height: 16),
                          
                          // Name & Handle
                          Text(
                            profile.displayName,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '@${profile.username}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          
                          const SizedBox(height: 16),

                          // STATS ROW: Followers | Following (No Views)
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
                              
                              // We need to fetch "Following" count dynamically since it's not in the UserProfile model yet
                              FutureBuilder<int>(
                                future: Supabase.instance.client
                                    .from('follows')
                                    .count(CountOption.exact)
                                    .eq('follower_auth_user_id', profile.authUserId),
                                builder: (context, snap) {
                                  final count = snap.data ?? 0;
                                  return Text(
                                    '$count following',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  );
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // BIO (Now below stats)
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

                          const SizedBox(height: 24),

                          // ACTION ROW: Creator Hub | Share | Edit
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Hero Button
                              FilledButton(
                                onPressed: () {
                                  context.push('/monetization');
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFE60023), // Pinterest Red
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: const Text(
                                  'Creator Hub', 
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              
                              // Share Button (Circle)
                              InkWell(
                                onTap: () {
                                  Share.share('Check out my profile on XpreX: @${profile.username}');
                                },
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: theme.colorScheme.outlineVariant),
                                  ),
                                  child: Icon(Icons.share, size: 20, color: theme.colorScheme.onSurface),
                                ),
                              ),
                              
                              const SizedBox(width: 8),

                              // EDIT Button (Pen Icon - Links to Setup Screen)
                              InkWell(
                                onTap: () {
                                  // Navigate to ProfileSetupScreen in "Edit Mode" by passing the profile
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ProfileSetupScreen(originalProfile: profile),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: theme.colorScheme.outlineVariant),
                                  ),
                                  child: Icon(Icons.edit, size: 20, color: theme.colorScheme.onSurface),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // 3. Tab Bar
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        labelColor: theme.colorScheme.onSurface,
                        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                        indicatorColor: theme.colorScheme.onSurface,
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

  Widget _buildStat(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

// Reusable Grid with Tap-to-Play
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
          padding: const EdgeInsets.all(2),
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
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (v.coverImageUrl != null)
                      Image.network(v.coverImageUrl!, fit: BoxFit.cover)
                    else
                      Container(color: theme.colorScheme.surfaceContainerHighest),
                    
                    if (v.repostedByUsername != null)
                      Positioned(
                        top: 4, left: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                          child: const Icon(Icons.repeat, color: Colors.white, size: 10),
                        ),
                      ),

                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(4.0),
                        decoration: const BoxDecoration(
                           gradient: LinearGradient(
                             begin: Alignment.bottomCenter,
                             end: Alignment.topCenter,
                             colors: [Colors.black54, Colors.transparent],
                           )
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                '${v.playbackCount}',
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
