import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/models/user_profile.dart';
import 'package:xprex/services/profile_service.dart';
import 'package:xprex/config/supabase_config.dart'; // To get current user ID

class FollowListScreen extends StatefulWidget {
  final String userId;
  final String type; // 'followers' or 'following'

  const FollowListScreen({super.key, required this.userId, required this.type});

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final _profileService = ProfileService();
  late Future<List<UserProfile>> _loader;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'followers') {
      _loader = _profileService.getFollowersList(widget.userId);
    } else {
      _loader = _profileService.getFollowingList(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.type == 'followers' ? 'Followers' : 'Following';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<List<UserProfile>>(
        future: _loader,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error loading list'));
          }
          final list = snap.data ?? [];

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: theme.colorScheme.surfaceContainerHighest),
                  const SizedBox(height: 16),
                  Text('No users found', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (ctx, i) => const Divider(height: 24, indent: 64),
            itemBuilder: (context, index) {
              final user = list[index];
              final isMe = user.authUserId == supabase.auth.currentUser?.id;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                  child: user.avatarUrl == null ? const Icon(Icons.person) : null,
                ),
                title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('@${user.username}'),
                trailing: isMe 
                    ? null 
                    : _FollowActionButton(targetUserId: user.authUserId),
                onTap: () {
                  context.push('/u/${user.authUserId}');
                },
              );
            },
          );
        },
      ),
    );
  }
}

// Smart button that checks follow status independently
class _FollowActionButton extends StatefulWidget {
  final String targetUserId;
  const _FollowActionButton({required this.targetUserId});

  @override
  State<_FollowActionButton> createState() => _FollowActionButtonState();
}

class _FollowActionButtonState extends State<_FollowActionButton> {
  final _svc = ProfileService();
  bool _isFollowing = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final me = supabase.auth.currentUser?.id;
    if (me != null) {
      final f = await _svc.isFollowing(followerAuthUserId: me, followeeAuthUserId: widget.targetUserId);
      if (mounted) setState(() { _isFollowing = f; _loading = false; });
    }
  }

  Future<void> _toggle() async {
    final me = supabase.auth.currentUser?.id;
    if (me == null) return;
    
    setState(() => _loading = true);
    try {
      if (_isFollowing) {
        await _svc.unfollowUser(followerAuthUserId: me, followeeAuthUserId: widget.targetUserId);
        if (mounted) setState(() => _isFollowing = false);
      } else {
        await _svc.followUser(followerAuthUserId: me, followeeAuthUserId: widget.targetUserId);
        if (mounted) setState(() => _isFollowing = true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));

    return FilledButton(
      onPressed: _toggle,
      style: FilledButton.styleFrom(
        backgroundColor: _isFollowing ? Colors.grey.shade300 : Theme.of(context).colorScheme.primary,
        foregroundColor: _isFollowing ? Colors.black : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        minimumSize: const Size(80, 36),
      ),
      child: Text(_isFollowing ? 'Following' : 'Follow'),
    );
  }
}
