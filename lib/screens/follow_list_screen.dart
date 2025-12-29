import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/models/user_profile.dart';
import 'package:xprex/services/profile_service.dart';
import 'package:xprex/config/supabase_config.dart';

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
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final users = snapshot.data ?? [];
          if (users.isEmpty) {
            return Center(child: Text("No $title yet"));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(user.avatarUrl ?? 'https://placehold.co/50'),
                ),
                title: Text(user.username),
                subtitle: Text(user.displayName),
                trailing: _FollowButton(targetUserId: user.authUserId),
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

class _FollowButton extends StatefulWidget {
  final String targetUserId;
  const _FollowButton({required this.targetUserId});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  final _svc = ProfileService();
  bool _isFollowing = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final me = supabase.auth.currentUser?.id;
    if (me != null) {
      // CORRECTED: Matches ProfileService (followerId, followeeId)
      final f = await _svc.isFollowing(followerId: me, followeeId: widget.targetUserId);
      if (mounted) setState(() { _isFollowing = f; _loading = false; });
    }
  }

  Future<void> _toggle() async {
    final me = supabase.auth.currentUser?.id;
    if (me == null) return;
    
    setState(() => _loading = true);
    try {
      if (_isFollowing) {
        // CORRECTED: Matches ProfileService
        await _svc.unfollowUser(followerId: me, followeeId: widget.targetUserId);
        if (mounted) setState(() => _isFollowing = false);
      } else {
        // CORRECTED: Matches ProfileService
        await _svc.followUser(followerId: me, followeeId: widget.targetUserId);
        if (mounted) setState(() => _isFollowing = true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
    
    // Hide button if it's me
    if (widget.targetUserId == supabase.auth.currentUser?.id) return const SizedBox.shrink();

    return FilledButton(
      onPressed: _toggle,
      style: FilledButton.styleFrom(
        backgroundColor: _isFollowing ? Colors.grey.shade300 : Theme.of(context).colorScheme.primary,
        foregroundColor: _isFollowing ? Colors.black : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      ),
      child: Text(_isFollowing ? 'Following' : 'Follow'),
    );
  }
}
