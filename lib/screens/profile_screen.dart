import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final theme = Theme.of(context);

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
                    _buildStat('Videos', '0', theme),
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
                Container(
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
