import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // IMPORT SUPABASE
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';
// SERVICES
import 'package:xprex/services/video_service.dart';
import 'package:xprex/services/save_service.dart';
import 'package:xprex/services/repost_service.dart';
// MODELS
import 'package:xprex/models/video_model.dart';
// WIDGETS
import 'package:xprex/widgets/profile/profile_header.dart';
import 'package:xprex/widgets/profile/profile_video_grid.dart';
// SCREENS
import 'package:xprex/screens/analytics_screen.dart';
import 'package:xprex/screens/settings/settings_screen.dart';

// --- DATA PROVIDERS ---
final createdVideosProvider = FutureProvider.family<List<VideoModel>, String>((ref, userId) async {
  final service = VideoService();
  return await service.getUserVideos(userId);
});

final savedVideosProvider = FutureProvider.family<List<VideoModel>, String>((ref, userId) async {
  final service = SaveService();
  return await service.getSavedVideos(userId);
});

final repostedVideosProvider = FutureProvider.family<List<VideoModel>, String>((ref, userId) async {
  final service = RepostService();
  return await service.getRepostedVideos(userId);
});

// CONVERTED TO STATEFUL WIDGET FOR REALTIME SUBSCRIPTION
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  RealtimeChannel? _videosSubscription;

  @override
  void initState() {
    super.initState();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Listen for UPDATES on the 'videos' table for this user
    // This catches when Coconut finishes processing and updates the storage path
    _videosSubscription = Supabase.instance.client
        .channel('public:videos:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'videos',
          filter: 'author_auth_user_id=eq.$userId',
          callback: (payload) {
            // Logic: If a video updates, refresh the 'Created' list
            if (mounted) {
              ref.invalidate(createdVideosProvider(userId));
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_videosSubscription != null) {
      Supabase.instance.client.removeChannel(_videosSubscription!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  SliverAppBar(
                    expandedHeight: 420, 
                    pinned: true,
                    elevation: 0,
                    backgroundColor: theme.colorScheme.surface,
                    
                    // Stats Button
                    leading: IconButton(
                      icon: const Icon(Icons.bar_chart_rounded),
                      color: theme.colorScheme.onSurface,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AnalyticsScreen(),
                          ),
                        );
                      },
                    ),

                    // Settings Button
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        color: theme.colorScheme.onSurface,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],

                    flexibleSpace: FlexibleSpaceBar(
                      background: Padding(
                        padding: const EdgeInsets.only(top: 60.0), 
                        child: ProfileHeader(profile: profile, theme: theme),
                      ),
                    ),
                    
                    bottom: TabBar(
                      indicatorColor: theme.colorScheme.onSurface,
                      labelColor: theme.colorScheme.onSurface,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
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
                ];
              },
              body: TabBarView(
                children: [
                  _VideoTab(provider: createdVideosProvider(profile.authUserId)),
                  _VideoTab(provider: savedVideosProvider(profile.authUserId)),
                  _VideoTab(
                    provider: repostedVideosProvider(profile.authUserId),
                    repostContextUsername: profile.username, 
                  ),
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

class _VideoTab extends ConsumerWidget {
  final ProviderListenable<AsyncValue<List<VideoModel>>> provider;
  final String? repostContextUsername;

  const _VideoTab({
    required this.provider, 
    this.repostContextUsername
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncVideos = ref.watch(provider);
    return asyncVideos.when(
      data: (videos) => ProfileVideoGrid(
        videos: videos,
        repostContextUsername: repostContextUsername,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error loading videos: $e')),
    );
  }
}
