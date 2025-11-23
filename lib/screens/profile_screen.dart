import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/models/video_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final theme = Theme.of(context);
    final videoService = VideoService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
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
            icon: Icon(Icons.logout),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found'));
          }

          return SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                  child: profile.avatarUrl == null ? Icon(Icons.person, size: 60, color: theme.colorScheme.onSurfaceVariant) : null,
                ),
                const SizedBox(height: 16),
                Text(profile.displayName, style: theme.textTheme.headlineMedium),
                Text('@${profile.username}', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                if (profile.bio != null) ...[
                  const SizedBox(height: 16),
                  Text(profile.bio!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
                ],
                const SizedBox(height: 24),
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
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => context.push('/monetization'),
                  icon: Icon(Icons.monetization_on),
                  label: Text('Monetization'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
                const SizedBox(height: 32),
                Text('My Videos', style: theme.textTheme.titleLarge),
                const SizedBox(height: 16),
                FutureBuilder<List<VideoModel>>(
                  future: videoService.getUserVideos(profile.authUserId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ));
                    }
                    final videos = snap.data ?? [];

                    // Update the header stats row by rebuilding with a small row below
                    if (videos.isNotEmpty)
                      ; // no-op, just show grid

                    if (videos.isEmpty) {
                      return Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.video_library_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(height: 8),
                              Text('No videos yet', style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      );
                    }

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: videos.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 9 / 16,
                      ),
                      itemBuilder: (context, index) {
                        final v = videos[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (v.coverImageUrl != null)
                                Image.network(v.coverImageUrl!, fit: BoxFit.cover)
                              else
                                Container(color: theme.colorScheme.surfaceContainerHighest, child: const Icon(Icons.slow_motion_video, color: Colors.white70)),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                  color: Colors.black.withValues(alpha: 0.4),
                                  child: Text(
                                    v.title,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
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
        Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
