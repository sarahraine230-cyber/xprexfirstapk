import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/services/save_service.dart';
import 'package:xprex/services/repost_service.dart';
import 'package:xprex/models/video_model.dart';

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
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found'));
          }

          // We use DefaultTabController to coordinate the TabBar and TabBarView
          return DefaultTabController(
            length: 3, // Created, Saved, Reposts
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // 1. App Bar (Pinned)
                  SliverAppBar(
                    title: const Text('Profile'),
                    pinned: true,
                    actions: [
                      IconButton(
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
                        icon: const Icon(Icons.logout),
                      ),
                    ],
                  ),

                  // 2. Profile Info (Scrolls away)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                            child: profile.avatarUrl == null ? Icon(Icons.person, size: 50, color: theme.colorScheme.onSurfaceVariant) : null,
                          ),
                          const SizedBox(height: 16),
                          Text(profile.displayName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                          Text('@${profile.username}', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                          if (profile.bio != null) ...[
                            const SizedBox(height: 12),
                            Text(profile.bio!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                          ],
                          const SizedBox(height: 24),
                          // Stats Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStat('Followers', profile.followersCount.toString(), theme),
                              _buildStat('Views', profile.totalVideoViews.toString(), theme),
                              FutureBuilder<List<VideoModel>>(
                                future: videoService.getUserVideos(profile.authUserId),
                                builder: (context, snap) {
                                  final count = (snap.data ?? const <VideoModel>[]).length;
                                  return _buildStat('Videos', snap.connectionState == ConnectionState.waiting ? '…' : '$count', theme);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (profile.isPremium)
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: AppSpacing.paddingMd,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, color: theme.colorScheme.onTertiaryContainer),
                                  const SizedBox(width: 8),
                                  Text('Premium Member', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onTertiaryContainer)),
                                ],
                              ),
                            ),
                          FilledButton.icon(
                            onPressed: () => context.push('/monetization'),
                            icon: const Icon(Icons.monetization_on),
                            label: const Text('Monetization'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Persistent Tab Bar (Sticks to top)
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        labelColor: theme.colorScheme.onSurface,
                        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                        indicatorColor: theme.colorScheme.onSurface,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
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
                  // Tab 1: My Videos (Created)
                  _VideoGrid(loader: videoService.getUserVideos(profile.authUserId)),
                  // Tab 2: Saved Videos
                  _VideoGrid(loader: saveService.getSavedVideos(profile.authUserId), emptyMsg: "No saved videos"),
                  // Tab 3: Reposted Videos
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

// Reusable Grid Component to keep code clean
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
                Icon(Icons.video_library_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Text(emptyMsg, style: theme.textTheme.bodyMedium),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(4),
          itemCount: videos.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
            childAspectRatio: 9 / 16,
          ),
          itemBuilder: (context, index) {
            final v = videos[index];
            return GestureDetector(
              onTap: () {
                // Navigate to video player or feed starting at this index
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (v.coverImageUrl != null)
                      Image.network(v.coverImageUrl!, fit: BoxFit.cover)
                    else
                      Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.play_circle_outline, color: Colors.white70)),
                    
                    // Optional: View count overlay
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        decoration: const BoxDecoration(
                           gradient: LinearGradient(
                             begin: Alignment.bottomCenter,
                             end: Alignment.topCenter,
                             colors: [Colors.black54, Colors.transparent],
                           )
                        ),
                        width: double.infinity,
                        child: Text(
                          v.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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

// Required helper class to make TabBar work inside NestedScrollView header
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
      color: theme.colorScheme.surface, // Background color for the tabs
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
