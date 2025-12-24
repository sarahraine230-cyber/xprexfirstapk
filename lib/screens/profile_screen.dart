import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';
// SERVICES
import 'package:xprex/services/video_service.dart';
import 'package:xprex/services/save_service.dart';
import 'package:xprex/services/repost_service.dart';
// MODELS
import 'package:xprex/models/video_model.dart';
// WIDGETS (The Atomic Modules we built)
import 'package:xprex/widgets/profile/profile_header.dart';
import 'package:xprex/widgets/profile/profile_video_grid.dart';

// --- DATA PROVIDERS (Restoring the 3 Data Streams) ---

// 1. Created Videos (Refreshable for Uploads)
final createdVideosProvider = FutureProvider.family<List<VideoModel>, String>((ref, userId) async {
  final service = VideoService();
  return await service.getUserVideos(userId);
});

// 2. Saved Videos
final savedVideosProvider = FutureProvider.family<List<VideoModel>, String>((ref, userId) async {
  final service = SaveService();
  return await service.getSavedVideos(userId);
});

// 3. Reposted Videos
final repostedVideosProvider = FutureProvider.family<List<VideoModel>, String>((ref, userId) async {
  final service = RepostService();
  return await service.getRepostedVideos(userId);
});


class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Get Current User Profile
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

          return DefaultTabController(
            length: 3, 
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // --- HEADER (Bio, Stats, Buttons) ---
                  SliverAppBar(
                    expandedHeight: 320, 
                    pinned: true,
                    backgroundColor: theme.colorScheme.surface,
                    flexibleSpace: FlexibleSpaceBar(
                      background: ProfileHeader(profile: profile, theme: theme),
                    ),
                    // --- TABS (Restored Original Labels) ---
                    bottom: TabBar(
                      indicatorColor: theme.colorScheme.primary,
                      labelColor: theme.colorScheme.onSurface,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                      tabs: const [
                        Tab(text: "Created"),
                        Tab(text: "Saved"),
                        Tab(text: "Reposts"),
                      ],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  // --- TAB 1: CREATED (With Processing Badge) ---
                  _VideoTab(provider: createdVideosProvider(profile.authUserId)),
                  
                  // --- TAB 2: SAVED ---
                  _VideoTab(provider: savedVideosProvider(profile.authUserId)),
                  
                  // --- TAB 3: REPOSTS ---
                  _VideoTab(provider: repostedVideosProvider(profile.authUserId)),
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

// Helper Widget to handle Loading/Error states for each tab
class _VideoTab extends ConsumerWidget {
  final AsyncValue<List<VideoModel>> provider;
  
  const _VideoTab({required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We watch the specific provider passed to this tab
    final asyncVideos = ref.watch(provider as ProviderListenable<AsyncValue<List<VideoModel>>>);

    return asyncVideos.when(
      data: (videos) => ProfileVideoGrid(videos: videos),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error loading videos: $e')),
    );
  }
}
