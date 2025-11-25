import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show RouteAware, ModalRoute, PageRoute;
import 'package:xprex/router/app_router.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/services/storage_service.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/config/app_links.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/services/comment_service.dart';
import 'package:xprex/models/comment_model.dart';
import 'package:xprex/theme.dart';

final feedVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  final videoService = VideoService();
  return await videoService.getFeedVideos(limit: 20);
});

class FeedScreen extends ConsumerStatefulWidget {
  final bool isVisible;

  const FeedScreen({super.key, this.isVisible = true});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> with WidgetsBindingObserver, RouteAware {
  int _activeIndex = 0;
  bool _appActive = true;
  bool _routeVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  // Subscribe to route observer once when dependencies change, not in build
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  // RouteAware
  @override
  void didPushNext() {
    // Another route has been pushed on top of this one
    if (_routeVisible) {
      setState(() => _routeVisible = false);
      _maybeDisableWakelock();
      debugPrint('📺 FeedScreen.didPushNext → route hidden, pausing feed visuals');
    }
  }

  @override
  void didPopNext() {
    // Back to this route
    if (!_routeVisible) {
      setState(() => _routeVisible = true);
      debugPrint('📺 FeedScreen.didPopNext → route visible again');
    }
  }

  @override
  void dispose() {
    // Ensure we don't hold wakelock when leaving feed
    _maybeDisableWakelock();
    WidgetsBinding.instance.removeObserver(this);
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.unsubscribe(this);
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      if (!widget.isVisible) {
        // When hidden, make sure wakelock is disabled
        _maybeDisableWakelock();
      }
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appActive != active) {
      _appActive = active;
      if (!active) {
        // App backgrounded → release wakelock
        _maybeDisableWakelock();
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Route subscription handled in didChangeDependencies
    final ref = this.ref;
    final videosAsync = ref.watch(feedVideosProvider);
    final theme = Theme.of(context);

    final feedVisible = widget.isVisible && _appActive && _routeVisible;
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text(
          'XpreX',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: videosAsync.when(
        data: (videos) {
          if (videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library_outlined, size: 80, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No videos yet', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Be the first to upload!', style: theme.textTheme.bodyMedium),
                ],
              ),
            );
          }

          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return VideoFeedItem(
                key: ValueKey(video.id),
                video: video,
                isActive: index == _activeIndex,
                feedVisible: feedVisible,
                onLikeToggled: () {
                  // refresh list to reflect counts
                  ref.invalidate(feedVideosProvider);
                },
              );
            },
            onPageChanged: (i) {
              setState(() => _activeIndex = i);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Error loading feed', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(error.toString(), style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoFeedItem extends StatefulWidget {
  final VideoModel video;
  final bool isActive;
  final bool feedVisible;
  final VoidCallback? onLikeToggled;

  const VideoFeedItem({super.key, required this.video, required this.isActive, required this.feedVisible, this.onLikeToggled});

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> {
  final _storage = StorageService();
  final _videoService = VideoService();
  VideoPlayerController? _controller;
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentsCount = 0;
  int _shareCount = 0;
  bool _loading = true;
  bool _isSaved = false;
  bool _isReposted = false;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.video.likesCount;
    _commentsCount = widget.video.commentsCount;
    _init();
  }

  @override
  void didUpdateWidget(covariant VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _disposeController();
      _loading = true;
      _init();
    }
    _updatePlayState();
  }

  Future<void> _init() async {
    try {
      final playableUrl = await _storage.resolveVideoUrl(widget.video.storagePath, expiresIn: 60 * 60);
      _controller = VideoPlayerController.networkUrl(Uri.parse(playableUrl))
        ..setLooping(true);
      await _controller!.initialize();
      // Initialize like status and share count in parallel
      final uid = supabase.auth.currentUser?.id;
      if (uid != null) {
        _videoService.isVideoLikedByUser(widget.video.id, uid).then((liked) {
          if (mounted) setState(() => _isLiked = liked);
        });
        _videoService.isVideoSavedByUser(widget.video.id, uid).then((saved) {
          if (mounted) setState(() => _isSaved = saved);
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
    } else {
      _controller!.pause();
      _maybeDisableWakelock();
    }
    setState(() {});
  }

  Future<void> _toggleLike() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to like videos')),
          );
        }
        return;
      }
      // Optimistic UI update for snappier feel
      final previousLiked = _isLiked;
      setState(() {
        _isLiked = !previousLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
      widget.onLikeToggled?.call();

      final liked = await _videoService.toggleLike(widget.video.id, uid);
      if (liked != _isLiked && mounted) {
        // Backend disagreed; reconcile
        setState(() {
          _isLiked = liked;
          _likeCount += liked ? 1 : -1;
        });
      }
    } catch (e) {
      debugPrint('❌ like toggle failed: $e');
      if (mounted) {
        // Revert optimistic update on failure
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
        final msg = e.toString().contains('42703')
            ? 'Like failed: backend counters missing. Please run latest SQL.'
            : 'Failed to like. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _toggleSave() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to save videos')),
          );
        }
        return;
      }
      final prev = _isSaved;
      setState(() => _isSaved = !prev);
      final saved = await _videoService.toggleSave(widget.video.id, uid);
      if (mounted && saved != _isSaved) {
        setState(() => _isSaved = saved);
      }
    } catch (e) {
      debugPrint('❌ toggle save failed: $e');
      if (mounted) {
        setState(() => _isSaved = !_isSaved);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    }
  }

  Future<void> _toggleRepost() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to repost')),
          );
        }
        return;
      }
      final prev = _isReposted;
      setState(() => _isReposted = !prev);
      final reposted = await _videoService.toggleRepost(widget.video.id, uid);
      if (mounted && reposted != _isReposted) {
        setState(() => _isReposted = reposted);
      }
    } catch (e) {
      debugPrint('❌ toggle repost failed: $e');
      if (mounted) {
        setState(() => _isReposted = !_isReposted);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to repost. Please try again.')),
        );
      }
    }
  }

  @override
  void dispose() {
    // Ensure we release wakelock when item is disposed
    WakelockPlus.disable();
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    try {
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neon = Theme.of(context).extension<NeonAccentTheme>();
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final h = size.height;

    // Responsive rail height with a slight bump to accommodate larger icons
    // Keep placement the same; only the container height grows slightly
    final double railHeight = h <= 640
        ? h * 0.44
        : (h <= 780
            ? h * 0.41
            : (h <= 900
                ? h * 0.38
                : h * 0.36));

    // Keep the column comfortably above the bottom nav bar (base position)
    final double bottomGuard = padding.bottom + 88.0;

    // Icon sizing: previously increased ~80–85%. Now scale to 200% of current size (2x),
    // while keeping responsiveness and without altering placement.
    final double _previous = (58.0 * (h / 800.0)).clamp(56.0, 64.0);
    final double iconSize = ((_previous * 1.82).clamp(90.0, 120.0)) * 2.0;

    // Maintain spacing ratios by scaling gaps relative to the original 32px icon baseline
    const double baseIcon = 32.0;
    const double baseSmallGap = 6.0; // icon ↔ count
    const double baseGroupGap = 14.0; // between icon groups
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
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : (widget.video.coverImageUrl != null
                    ? Image.network(widget.video.coverImageUrl!, fit: BoxFit.cover)
                    : Container(color: Colors.black)),
          ),
          // Tap to play/pause overlay
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (_controller == null) return;
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
            _maybeDisableWakelock();
                  } else {
                    if (widget.feedVisible && widget.isActive) {
                      _controller!.play();
              _maybeEnableWakelock();
                    }
                  }
                  setState(() {});
                },
              ),
            ),
          ),
          // Bottom left: author + title
          Positioned(
            bottom: 80,
            left: 16,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        // Pause playback before navigating away so audio doesn't continue
                        try {
                          _controller?.pause();
                          _controller?.setVolume(0);
                          _maybeDisableWakelock();
                        } catch (_) {}
                        if (widget.video.authorAuthUserId.isNotEmpty) {
                          await context.push('/u/${widget.video.authorAuthUserId}');
                          // Attempt to restore volume when back
                          try { _controller?.setVolume(1.0); } catch (_) {}
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
                          // Pause playback before navigating away so audio doesn't continue
                          try {
                            _controller?.pause();
                            _controller?.setVolume(0);
                            _maybeDisableWakelock();
                          } catch (_) {}
                          if (widget.video.authorAuthUserId.isNotEmpty) {
                            await context.push('/u/${widget.video.authorAuthUserId}');
                            try { _controller?.setVolume(1.0); } catch (_) {}
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
          // Right rail (responsive height and spacing)
          Positioned(
            right: 12,
            // Lower the rail by ~20% of its own height from the current base position
            bottom: (bottomGuard - (railHeight * 0.20)).clamp(padding.bottom + 12.0, double.infinity),
            child: SizedBox(
              height: railHeight,
              // Scale down slightly if content would exceed target height to avoid overflow
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
                      // Force pure white icon color always (ignore theme/dark mode)
                      color: Colors.white,
                      glow: neon?.purple ?? theme.colorScheme.primary,
                      background: Colors.transparent,
                      outlined: false,
                    ),
                    SizedBox(height: smallGap),
                    _countBadge(context, _likeCount, glowColor: neon?.purple ?? theme.colorScheme.primary, textScale: 2.0),
                    SizedBox(height: groupGap),
                    _NeonRailButton(
                      icon: Icons.comment,
                      size: iconSize,
                      onTap: _openComments,
                      // Force pure white icon color always (ignore theme/dark mode)
                      color: Colors.white,
                      glow: neon?.cyan ?? theme.colorScheme.secondary,
                      background: Colors.transparent,
                      outlined: false,
                    ),
                    SizedBox(height: smallGap),
                    _countBadge(context, _commentsCount, glowColor: neon?.cyan ?? theme.colorScheme.secondary, textScale: 2.0),
                    SizedBox(height: groupGap),
                    _NeonRailButton(
                      icon: Icons.share,
                      size: iconSize,
                      onTap: _handleShare,
                      // Force pure white icon color always (ignore theme/dark mode)
                      color: Colors.white,
                      glow: neon?.blue ?? theme.colorScheme.tertiary,
                      background: Colors.transparent,
                      outlined: false,
                    ),
                    SizedBox(height: smallGap),
                    _countBadge(context, _shareCount, glowColor: neon?.blue ?? theme.colorScheme.tertiary, textScale: 2.0),
                    SizedBox(height: groupGap),
                    _NeonRailButton(
                      icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: iconSize,
                      onTap: _toggleSave,
                      // Force pure white icon color always (ignore theme/dark mode)
                      color: Colors.white,
                      glow: neon?.blue ?? theme.colorScheme.primary,
                      background: Colors.transparent,
                      outlined: false,
                    ),
                    SizedBox(height: groupGap),
                    _NeonRailButton(
                      icon: Icons.repeat,
                      size: iconSize,
                      onTap: _toggleRepost,
                      // Force pure white icon color always (ignore theme/dark mode)
                      color: Colors.white,
                      glow: neon?.purple ?? theme.colorScheme.secondary,
                      background: Colors.transparent,
                      outlined: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }

  void _openComments() {
    // Pause while comments are open
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
        return _CommentsSheet(
          videoId: widget.video.id,
          onNewComment: () {
            setState(() => _commentsCount += 1);
          },
        );
      },
    ).whenComplete(() {
      // Resume if appropriate when sheet closes
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
      // Prefer sharing a public app route if configured; fallback to signed storage URL
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
}

// Wakelock helpers to avoid noisy errors on web
void _maybeEnableWakelock() {
  if (kIsWeb) return; // Skip on web
  try {
    WakelockPlus.enable();
  } catch (e) {
    debugPrint('wakelock enable ignored: $e');
  }
}

void _maybeDisableWakelock() {
  if (kIsWeb) return; // Skip on web
  try {
    WakelockPlus.disable();
  } catch (e) {
    debugPrint('wakelock disable ignored: $e');
  }
}

// Right-rail count text: bare, always white, huge (fixed size), no backgrounds/shadows
Widget _countBadge(BuildContext context, int count, {Color? glowColor, double textScale = 1.0}) {
  // Bare text only: no background container, no shadow, no opacity layers
  return Text(
    '$count',
    textAlign: TextAlign.center,
    style: TextStyle(
      color: Colors.white, // Force pure white always
      fontSize: 80.0, // Huge, fixed per requirements
      fontWeight: FontWeight.w600,
      letterSpacing: 0.0,
      height: 0.98, // keep line box tight without affecting layout
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
  final bool outlined;

  const _NeonRailButton({
    required this.icon,
    required this.size,
    required this.onTap,
    required this.color,
    required this.glow,
    required this.background,
    this.outlined = false,
  });

  @override
  State<_NeonRailButton> createState() => _NeonRailButtonState();
}

class _NeonRailButtonState extends State<_NeonRailButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    // Grow hit area proportionally with icon size to keep UX strong
    final double containerSize = widget.size + (18 * (widget.size / 36.0));
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
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
          color: Colors.transparent, // No background, no border, no shadow
        ),
          child: Center(
            child: Icon(widget.icon, size: widget.size, color: widget.color),
          ),
        ),
      ),
    );
  }
}

// Snapchat-style comments sheet with rounded top and themed colors
class _CommentsSheet extends StatefulWidget {
  final String videoId;
  final VoidCallback? onNewComment;
  const _CommentsSheet({required this.videoId, this.onNewComment});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _svc = CommentService();
  final _inputCtrl = TextEditingController();
  late Future<List<CommentModel>> _loader;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _loader = _svc.getCommentsByVideo(widget.videoId);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _posting) return;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to comment')),
        );
      }
      return;
    }
    setState(() => _posting = true);
    try {
      await _svc.createComment(videoId: widget.videoId, authorAuthUserId: uid, text: text);
      _inputCtrl.clear();
      // Refresh the list
      setState(() {
        _loader = _svc.getCommentsByVideo(widget.videoId);
        _posting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment posted')),
        );
      }
      widget.onNewComment?.call();
    } catch (e) {
      setState(() => _posting = false);
      debugPrint('❌ post comment failed: $e');
      if (mounted) {
        final msg = e.toString().contains('42703')
            ? 'Comment failed: backend counters missing. Please run latest SQL.'
            : 'Failed to post comment';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets),
      child: DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Comments', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<CommentModel>>(
                  future: _loader,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snap.data ?? const <CommentModel>[];
                    if (items.isEmpty) {
                      return Center(
                        child: Text('Be the first to comment', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final c = items[i];
                        final name = (c.authorDisplayName != null && c.authorDisplayName!.trim().isNotEmpty)
                            ? c.authorDisplayName!
                            : (c.authorUsername != null ? '@${c.authorUsername}' : '');
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              backgroundImage: (c.authorAvatarUrl != null && c.authorAvatarUrl!.isNotEmpty) ? NetworkImage(c.authorAvatarUrl!) : null,
                              child: (c.authorAvatarUrl == null || c.authorAvatarUrl!.isEmpty) ? Icon(Icons.person, color: theme.colorScheme.onSurfaceVariant, size: 18) : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: theme.textTheme.titleSmall),
                                  const SizedBox(height: 4),
                                  Text(c.text, style: theme.textTheme.bodyMedium),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12, top: 8),
                  child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        decoration: InputDecoration(
                          hintText: 'Add a comment',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _posting ? null : _post,
                      icon: const Icon(Icons.send),
                      label: const Text('Send'),
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                    ),
                  ],
                  ),
                ),
              ),
            ],
          ),
          );
      },
      ),
    );
  }
}
