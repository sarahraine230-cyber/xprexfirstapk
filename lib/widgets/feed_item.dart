import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/config/app_links.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/services/storage_service.dart';
import 'package:xprex/services/save_service.dart';
import 'package:xprex/services/repost_service.dart';
import 'package:xprex/theme.dart';
import 'package:xprex/widgets/comment_sheet.dart'; // We will create this next

class VideoFeedItem extends StatefulWidget {
  final VideoModel video;
  final bool isActive;
  final bool feedVisible;
  final VoidCallback? onLikeToggled;

  const VideoFeedItem({
    super.key, 
    required this.video, 
    required this.isActive, 
    required this.feedVisible, 
    this.onLikeToggled
  });

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> {
  final _storage = StorageService();
  final _videoService = VideoService();
  final _saveService = SaveService();
  final _repostService = RepostService();

  CachedVideoPlayerPlusController? _controller;
  
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentsCount = 0;
  int _shareCount = 0;
  
  bool _isSaved = false;
  int _saveCount = 0;
  bool _isReposted = false;
  int _repostCount = 0;
  
  bool _loading = true;
  Timer? _watchTimer;
  int _secondsWatched = 0;
  bool _hasRecordedView = false;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.video.likesCount;
    _commentsCount = widget.video.commentsCount;
    _saveCount = widget.video.savesCount;
    _repostCount = widget.video.repostsCount;
    _init();
  }

  @override
  void didUpdateWidget(covariant VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _flushWatchTime();
      _disposeController();
      _loading = true;
      _init();
    }
    _updatePlayState();
  }

  Future<void> _init() async {
    try {
      final playableUrl = await _storage.resolveVideoUrl(widget.video.storagePath, expiresIn: 60 * 60);
      _controller = CachedVideoPlayerPlusController.networkUrl(
        Uri.parse(playableUrl),
        invalidateCacheIfOlderThan: const Duration(days: 30),
      )..setLooping(true);
      await _controller!.initialize();
      
      if (widget.video.authorAuthUserId.isNotEmpty && !_hasRecordedView) {
        _videoService.recordView(widget.video.id, widget.video.authorAuthUserId);
        _hasRecordedView = true;
      }
      
      final uid = supabase.auth.currentUser?.id;
      if (uid != null) {
        _videoService.isVideoLikedByUser(widget.video.id, uid).then((liked) {
          if (mounted) setState(() => _isLiked = liked);
        });
        _saveService.isVideoSaved(widget.video.id, uid).then((saved) {
          if (mounted) setState(() => _isSaved = saved);
        });
        _repostService.isVideoReposted(widget.video.id, uid).then((reposted) {
          if (mounted) setState(() => _isReposted = reposted);
        });
        _videoService.getShareCount(widget.video.id).then((count) {
          if (mounted) setState(() => _shareCount = count);
        });
      } else {
        _videoService.getShareCount(widget.video.id).then((count) {
          if (mounted) setState(() => _shareCount = count);
        });
      }
      _updatePlayState();
    } catch (e) {
      debugPrint('❌ Failed to init player: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _updatePlayState() {
    if (_controller == null) return;
    final shouldPlay = widget.feedVisible && widget.isActive;
    
    if (shouldPlay) {
      _controller!.play();
      _maybeEnableWakelock();
      _startWatchTimer();
    } else {
      _controller!.pause();
      _maybeDisableWakelock();
      _stopWatchTimer();
    }
    // No setState here to avoid unnecessary rebuilds, the video texture handles itself
  }

  void _startWatchTimer() {
    if (_watchTimer != null && _watchTimer!.isActive) return;
    _watchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_controller != null && _controller!.value.isPlaying) {
        _secondsWatched++;
      }
    });
  }

  void _stopWatchTimer() {
    _watchTimer?.cancel();
    _watchTimer = null;
  }

  Future<void> _flushWatchTime() async {
    _stopWatchTimer();
    if (_secondsWatched < 3) {
      _secondsWatched = 0;
      return;
    }

    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid != null) {
         await supabase.from('video_views').insert({
           'video_id': widget.video.id,
           'viewer_id': uid,
           'author_id': widget.video.authorAuthUserId,
           'duration_seconds': _secondsWatched,
           'created_at': DateTime.now().toIso8601String(),
         });
      }
    } catch (e) {
      debugPrint('❌ Failed to flush watch time: $e');
    } finally {
      _secondsWatched = 0;
    }
  }

  Future<void> _toggleLike() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to like')));
        return;
      }
      final previousLiked = _isLiked;
      setState(() {
        _isLiked = !previousLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
      widget.onLikeToggled?.call();

      final liked = await _videoService.toggleLike(widget.video.id, uid);
      if (liked != _isLiked && mounted) {
        setState(() {
          _isLiked = liked;
          _likeCount += liked ? 1 : -1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
      }
    }
  }

  Future<void> _toggleSave() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to save')));
        return;
      }
      
      final prev = _isSaved;
      setState(() {
        _isSaved = !prev;
        _saveCount += _isSaved ? 1 : -1;
      });
      final saved = await _saveService.toggleSave(widget.video.id, uid);
      
      if (mounted && saved != _isSaved) {
        setState(() {
          _isSaved = saved;
          _saveCount += saved ? 1 : -1; 
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
           _isSaved = !_isSaved;
           _saveCount += _isSaved ? 1 : -1;
        });
      }
    }
  }

  Future<void> _toggleRepost() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to repost')));
        return;
      }
      
      final prev = _isReposted;
      setState(() {
        _isReposted = !prev;
        _repostCount += _isReposted ? 1 : -1;
      });
      final reposted = await _repostService.toggleRepost(widget.video.id, uid);
      
      if (mounted && reposted != _isReposted) {
        setState(() {
          _isReposted = reposted;
          _repostCount += reposted ? 1 : -1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isReposted = !_isReposted;
          _repostCount += _isReposted ? 1 : -1;
        });
      }
    }
  }

  @override
  void dispose() {
    _flushWatchTime();
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    try {
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
  }

  void _openComments() {
    final wasPlaying = _controller?.value.isPlaying == true;
    try {
      _controller?.pause();
      _maybeDisableWakelock();
    } catch (_) {}

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return CommentsSheet(
          videoId: widget.video.id,
          initialCount: _commentsCount,
          onNewComment: () {
            setState(() => _commentsCount += 1);
          },
        );
      },
    ).whenComplete(() {
      if (wasPlaying && widget.feedVisible && widget.isActive) {
        try {
          _controller?.play();
          _maybeEnableWakelock();
        } catch (_) {}
      }
    });
  }

  Future<void> _handleShare() async {
    try {
      final deepLink = AppLinks.videoLink(widget.video.id);
      final url = deepLink.isNotEmpty
          ? deepLink
          : await _storage.resolveVideoUrl(widget.video.storagePath, expiresIn: 60 * 60);
      await Share.share(url);
      final uid = supabase.auth.currentUser?.id;
      if (uid != null) {
        await _videoService.recordShare(widget.video.id, uid);
      }
      setState(() => _shareCount += 1);
    } catch (e) {
      debugPrint('❌ share failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neon = Theme.of(context).extension<NeonAccentTheme>();
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final h = size.height;
    final double railHeight = h <= 640
        ? h * 0.44
        : (h <= 780 ? h * 0.41 : (h <= 900 ? h * 0.38 : h * 0.36));
    final double bottomGuard = padding.bottom + 88.0;
    
    final double _previous = (58.0 * (h / 800.0)).clamp(56.0, 64.0);
    final double iconSize = ((_previous * 1.82).clamp(90.0, 120.0)) * 2.0;
    
    const double baseIcon = 32.0;
    const double baseSmallGap = 6.0;
    const double baseGroupGap = 14.0;
    
    final double scaleRatio = iconSize / baseIcon;
    final double smallGap = (baseSmallGap * scaleRatio).clamp(5.0, 8.0);
    final double groupGap = (baseGroupGap * scaleRatio).clamp(12.0, 18.0);
    final authorName = (widget.video.authorDisplayName != null && widget.video.authorDisplayName!.trim().isNotEmpty)
        ? widget.video.authorDisplayName!
        : (widget.video.authorUsername != null ? '@${widget.video.authorUsername}' : 'Unknown');
        
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: _controller != null && _controller!.value.isInitialized
                ? FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: CachedVideoPlayerPlus(_controller!),
                    ),
                  )
                : (widget.video.coverImageUrl != null
                    ? Image.network(widget.video.coverImageUrl!, fit: BoxFit.cover)
                    : Container(color: Colors.black)),
          ),
          // Tap to Play/Pause
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (_controller == null) return;
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                    _maybeDisableWakelock();
                    _stopWatchTimer();
                  } else {
                    if (widget.feedVisible && widget.isActive) {
                      _controller!.play();
                      _maybeEnableWakelock();
                      _startWatchTimer();
                    }
                  }
                  // No setState needed for video toggle
                },
              ),
            ),
          ),
          
          // --- BOTTOM LEFT SECTION ---
          Positioned(
            bottom: 80,
            left: 16,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.video.repostedByUsername != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2), 
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.repeat, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.video.repostedByUsername} reposted',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        try {
                          _controller?.pause();
                          _maybeDisableWakelock();
                        } catch (_) {}
                        if (widget.video.authorAuthUserId.isNotEmpty) {
                          await context.push('/u/${widget.video.authorAuthUserId}');
                          try { if (widget.feedVisible && widget.isActive) _controller?.play(); } catch (_) {}
                        }
                      },
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        backgroundImage: (widget.video.authorAvatarUrl != null && widget.video.authorAvatarUrl!.isNotEmpty)
                            ? NetworkImage(widget.video.authorAvatarUrl!)
                            : null,
                        child: (widget.video.authorAvatarUrl == null || widget.video.authorAvatarUrl!.isEmpty)
                            ? const Icon(Icons.person_outline, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          try {
                            _controller?.pause();
                            _maybeDisableWakelock();
                          } catch (_) {}
                          if (widget.video.authorAuthUserId.isNotEmpty) {
                            await context.push('/u/${widget.video.authorAuthUserId}');
                            try { if (widget.feedVisible && widget.isActive) _controller?.play(); } catch (_) {}
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(authorName, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            if (widget.video.authorDisplayName == null || widget.video.authorDisplayName!.trim().isEmpty)
                              Text(widget.video.authorUsername != null ? '@${widget.video.authorUsername}' : '', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(widget.video.title, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (widget.video.description != null)
                  Text(widget.video.description!, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          
          // --- RIGHT RAIL ---
          Positioned(
            right: 12,
            bottom: (bottomGuard - (railHeight * 0.20)).clamp(padding.bottom + 12.0, double.infinity),
            child: SizedBox(
              height: railHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NeonRailButton(
                      icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                      size: iconSize,
                      onTap: _toggleLike,
                      color: Colors.white,
                      glow: neon?.purple ?? theme.colorScheme.primary,
                      background: Colors.transparent,
                    ),
                    SizedBox(height: smallGap),
                    _countBadge(context, _likeCount, glowColor: neon?.purple ?? theme.colorScheme.primary, textScale: 2.0),
                    SizedBox(height: groupGap),
                    _NeonRailButton(
                      icon: Icons.comment,
                      size: iconSize,
                      onTap: _openComments,
                      color: Colors.white,
                      glow: neon?.cyan ?? theme.colorScheme.secondary,
                      background: Colors.transparent,
                    ),
                    SizedBox(height: smallGap),
                    _countBadge(context, _commentsCount, glowColor: neon?.cyan ?? theme.colorScheme.secondary, textScale: 2.0),
                    SizedBox(height: groupGap),
                    _NeonRailButton(
                      icon: Icons.share,
                      size: iconSize,
                      onTap: _handleShare,
                      color: Colors.white,
                      glow: neon?.blue ?? theme.colorScheme.tertiary,
                      background: Colors.transparent,
                    ),
                    SizedBox(height: smallGap),
                    _countBadge(context, _shareCount, glowColor: neon?.blue ?? theme.colorScheme.tertiary, textScale: 2.0),
                    SizedBox(height: groupGap),
                    _NeonRailButton(
                      icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: iconSize,
                      onTap: _toggleSave,
                      color: Colors.white,
                      glow: neon?.blue ?? theme.colorScheme.primary,
                      background: Colors.transparent,
                    ),
                    SizedBox(height: smallGap),
                    _countBadge(context, _saveCount, glowColor: neon?.blue ?? theme.colorScheme.primary, textScale: 2.0),
                    SizedBox(height: groupGap),
                    _NeonRailButton(
                      icon: Icons.repeat,
                      size: iconSize,
                      onTap: _toggleRepost,
                      color: Colors.white,
                      glow: neon?.purple ?? theme.colorScheme.secondary,
                      background: Colors.transparent,
                    ),
                    SizedBox(height: smallGap),
                    _countBadge(context, _repostCount, glowColor: neon?.purple ?? theme.colorScheme.secondary, textScale: 2.0),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}

// --- HELPER WIDGETS ---

void _maybeEnableWakelock() {
  if (kIsWeb) return;
  try { WakelockPlus.enable(); } catch (_) {}
}

void _maybeDisableWakelock() {
  if (kIsWeb) return;
  try { WakelockPlus.disable(); } catch (_) {}
}

Widget _countBadge(BuildContext context, int count, {Color? glowColor, double textScale = 1.0}) {
  return Text(
    '$count',
    textAlign: TextAlign.center,
    style: TextStyle(
      color: Colors.white,
      fontSize: 10.0 * textScale,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.0,
      height: 0.98,
      shadows: [
        if (glowColor != null)
          BoxShadow(color: glowColor.withValues(alpha: 0.6), blurRadius: 4, spreadRadius: 2),
      ],
    ),
  );
}

class _NeonRailButton extends StatefulWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final Color color;
  final Color glow;
  final Color background;

  const _NeonRailButton({
    required this.icon,
    required this.size,
    required this.onTap,
    required this.color,
    required this.glow,
    required this.background,
  });

  @override
  State<_NeonRailButton> createState() => _NeonRailButtonState();
}

class _NeonRailButtonState extends State<_NeonRailButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final double containerSize = widget.size + (18 * (widget.size / 36.0));
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 1.07 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: containerSize,
          height: containerSize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
          child: Center(
            child: Icon(widget.icon, size: widget.size, color: widget.color),
          ),
        ),
      ),
    );
  }
}
