import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/screens/profile_setup_screen.dart';
import 'package:xprex/screens/creator_hub_screen.dart';
import 'package:xprex/screens/settings/settings_screen.dart';
import 'package:xprex/screens/follow_list_screen.dart';

class ProfileHeader extends StatelessWidget {
  final dynamic profile; 
  final ThemeData theme;

  const ProfileHeader({
    super.key,
    required this.profile,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 20),
      child: Column(
        children: [
          // 1. Avatar
          CircleAvatar(
            radius: 50,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: profile.avatarUrl != null 
                ? NetworkImage(profile.avatarUrl!) 
                : null,
            child: profile.avatarUrl == null 
                ? Icon(Icons.person, size: 50, color: theme.colorScheme.onSurfaceVariant) 
                : null,
          ),
          const SizedBox(height: 16),
          
          // 2. Name & Handle
          Text('@${profile.username}', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          Text(profile.displayName, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          
          const SizedBox(height: 16),

          // 3. Stats (FIXED: Using correct API and Real Data)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatButton(
                label: 'Following', 
                // Restore real count from profile object
                count: profile.followingCount ?? 0, 
                // FIX: Use named parameters 'userId' and 'type'
                onTap: () => Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (_) => FollowListScreen(
                      userId: profile.authUserId, 
                      type: 'following',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              _StatButton(
                label: 'Followers', 
                // Restore real count
                count: profile.followersCount ?? 0, 
                // FIX: Use named parameters 'userId' and 'type'
                onTap: () => Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (_) => FollowListScreen(
                      userId: profile.authUserId, 
                      type: 'followers',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Likes usually don't have a navigation screen in this context, keeping as column
              _StatColumn(
                label: 'Likes', 
                count: profile.likesCount ?? 0
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 4. Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileSetupScreen())), 
                child: const Text('Edit Profile')
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatorHubScreen())), 
                icon: const Icon(Icons.bar_chart),
                tooltip: 'Creator Hub',
              ),
              IconButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())), 
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatButton extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback onTap;
  const _StatButton({required this.label, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _StatColumn(label: label, count: count),
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
