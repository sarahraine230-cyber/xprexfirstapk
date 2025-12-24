import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/services/save_service.dart';
import 'package:xprex/services/repost_service.dart';
import 'package:xprex/models/video_model.dart';
// IMPORT ATOMIC WIDGETS
import 'package:xprex/widgets/profile/profile_header.dart';
import 'package:xprex/widgets/profile/profile_video_grid.dart';

// REFRESHABLE PROVIDER (Same as before, keep this)
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
    
    // Services (Restored for future use)
    final videoService = VideoService();
    final saveService = SaveService();
    final repostService = RepostService();

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

          // Watch videos (This will auto-refresh when we invalidate it later)
          final videosAsync = ref.watch(userVideosProvider(profile.id));

          return DefaultTabController(
            length: 3, 
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    expandedHeight: 320, // Adjusted height for all elements
                    pinned: true,
                    backgroundColor: theme.colorScheme.surface,
                    flexibleSpace: FlexibleSpaceBar(
                      background: ProfileHeader(profile: profile, theme: theme),
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
                  // --- TAB 1: MY VIDEOS (Modularized) ---
                  videosAsync.when(
                    data: (videos) => ProfileVideoGrid(videos: videos),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Center(child: Text('Error: $e')),
                  ),
                  
                  // Tab 2: Likes (Placeholder for now)
                  const Center(child: Text("Likes coming soon")),
                  
                  // Tab 3: Saved (Placeholder for now)
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
