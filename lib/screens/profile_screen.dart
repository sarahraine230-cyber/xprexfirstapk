import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/screens/video_player_screen.dart';
import 'package:xprex/screens/profile_setup_screen.dart';
import 'package:xprex/screens/creator_hub_screen.dart';
import 'package:xprex/screens/settings/settings_screen.dart';

// --- NEW: PROVIDER FOR VIDEOS (So we can refresh it) ---
final userVideosProvider = FutureProvider.family<List<VideoModel>, String>((ref, userId) async {
  final service = VideoService();
  return await service.getUserVideos(userId);
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return Center(
              child: ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Login to view profile'),
              ),
            );
          }

          // Watch the videos for this user
          final videosAsync = ref.watch(userVideosProvider(profile.id));

          return DefaultTabController(
            length: 3, 
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 280,
                    pinned: true,
                    backgroundColor: theme.colorScheme.surface,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Padding(
                        padding: const EdgeInsets.only(top: 60, bottom: 20),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: profile.avatarUrl != null 
                                  ? NetworkImage(profile.avatarUrl!) 
                                  : null,
                              child: profile.avatarUrl == null 
                                  ? const Icon(Icons.person, size: 50) 
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Text('@${profile.username}', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
                            const SizedBox(height: 8),
                            Text(profile.displayName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _StatColumn(label: 'Following', count: 0), // Placeholder
                                const SizedBox(width: 24),
                                _StatColumn(label: 'Followers', count: 0), // Placeholder
                                const SizedBox(width: 24),
                                _StatColumn(label: 'Likes', count: 0), // Placeholder
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton(
                                  onPressed: () {
                                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
                                  }, 
                                  child: const Text('Edit Profile')
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatorHubScreen())), 
                                  icon: const Icon(Icons.bar_chart)
                                ),
                                IconButton(
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())), 
                                  icon: const Icon(Icons.settings)
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    bottom: TabBar(
                      indicatorColor: theme.colorScheme.primary,
                      labelColor: theme.colorScheme.onSurface,
                      tabs: const [
                        Tab(icon: Icon(Icons.grid_on)),
                        Tab(icon: Icon(Icons.favorite_border)),
                        Tab(icon: Icon(Icons.bookmark_border)),
                      ],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  // --- TAB 1: MY VIDEOS ---
                  videosAsync.when(
                    data: (videos) {
                      if (videos.isEmpty) {
                        return const Center(child: Text("No videos yet"));
                      }
                      return GridView.builder(
                        padding: const EdgeInsets.all(2),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                          childAspectRatio: 0.7,
                        ),
                        itemCount: videos.length,
                        itemBuilder: (context, index) {
                          final v = videos[index];
                          final isProcessing = v.isProcessing;

                          return GestureDetector(
                            onTap: isProcessing 
                              ? null // Disable tap if processing
                              : () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => VideoPlayerScreen(videos: videos, initialIndex: index),
                                ));
                              },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Thumbnail
                                if (v.coverImageUrl != null)
                                  Image.network(v.coverImageUrl!, fit: BoxFit.cover)
                                else
                                  Container(color: Colors.grey[900]),
                                
                                // --- PROCESSING OVERLAY ---
                                if (isProcessing)
                                  Container(
                                    color: Colors.black.withOpacity(0.7),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                        SizedBox(height: 8),
                                        Text('Processing', style: TextStyle(color: Colors.white, fontSize: 10)),
                                      ],
                                    ),
                                  ),

                                // View Count (Only if ready)
                                if (!isProcessing)
                                  Positioned(
                                    bottom: 4, left: 4,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.play_arrow, size: 12, color: Colors.white),
                                        Text('${v.playbackCount}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Error: $e')),
                  ),
                  
                  // Tab 2 & 3 Placeholders
                  const Center(child: Text("Likes coming soon")),
                  const Center(child: Text("Saved coming soon")),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final int count;
  const _StatColumn({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
