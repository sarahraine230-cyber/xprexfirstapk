import 'package:flutter/material.dart';
import 'package:xprex/screens/profile_setup_screen.dart';
import 'package:xprex/screens/creator_hub_screen.dart';
import 'package:xprex/screens/follow_list_screen.dart';

class ProfileHeader extends StatelessWidget {
  final dynamic profile; 
  final ThemeData theme;
  // NEW: Callback for the share action
  final VoidCallback onShare;

  const ProfileHeader({
    super.key,
    required this.profile,
    required this.theme,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
            // [NEW] Row for Name + Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  profile.displayName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (profile.isPremium) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, color: Colors.blue, size: 22),
                ],
              ],
            ),
            Text(
              '@${profile.username}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            
            const SizedBox(height: 16),

            // 3. STATS ROW (CLICKABLE)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Followers
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => FollowListScreen(
                          userId: profile.authUserId, 
                          type: 'followers'
                        ),
                      ),
                    );
                  },
                  child: Text(
                    '${profile.followersCount} followers',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                
                const SizedBox(width: 8),
                const Text('·'),
                const SizedBox(width: 8),
                
                // Following
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => FollowListScreen(
                          userId: profile.authUserId, 
                          type: 'following'
                        ),
                      ),
                    );
                  },
                  child: Text(
                    '${profile.followingCount} following',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 4. BIO
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

            // 5. ACTION ROW: Creator Hub | Share | Edit
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // HERO BUTTON: Creator Hub
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const CreatorHubScreen()),
                    );
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
                
                // Share Button (Now uses the callback)
                InkWell(
                  onTap: onShare,
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

                // Edit Button
                InkWell(
                  onTap: () {
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
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
