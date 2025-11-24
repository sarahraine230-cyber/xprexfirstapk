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
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final h = size.height;

    // 1) Fixed column height: 35% of screen height across all sizes
    final double railHeight = h * 0.35;

    // 3) Keep the column comfortably above the bottom nav bar
    // Maintain ~72 logical pixels above the bottom inset
    final double bottomGuard = padding.bottom + 72.0;

    // 2) Button spacing: tightened to guarantee fit within 35% height
    // Use 12 between icon groups and 4 between icon and its count.
    // This preserves readable density while avoiding overflow on smaller screens.
    const double smallGap = 4.0; // icon ↔ count
    const double groupGap = 12.0; // between icon groups (like↔comment↔share↔save↔repost)
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
          // Right rail (fixed height and spacing)
          Positioned(
            right: 12,
            bottom: bottomGuard,
            child: SizedBox(
              height: railHeight,
              // Scale down slightly if content would exceed 35% height to avoid overflow
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _railButton(
                      context,
                      IconButton(
                        onPressed: _toggleLike,
                        icon: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onInverseSurface,
                        ),
                        // Comfortable icon size retained; FittedBox will only shrink when necessary
                        iconSize: 30,
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size.square(40),
                        ),
                      ),
                    ),
                    SizedBox(height: smallGap),
                    _countBadge(context, _likeCount),
                    SizedBox(height: groupGap),
                    _railButton(
                      context,
                      IconButton(
                        onPressed: _openComments,
                        icon: Icon(Icons.comment, color: Theme.of(context).colorScheme.onInverseSurface),
                        iconSize: 30,
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size.square(40),
                        ),
                      ),
                    ),
                    SizedBox(height: smallGap),
                    _countBadge(context, _commentsCount),
                    SizedBox(height: groupGap),
                    _railButton(
                      context,
                      IconButton(
                        onPressed: _handleShare,
                        icon: Icon(Icons.share, color: Theme.of(context).colorScheme.onInverseSurface),
                        iconSize: 30,
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size.square(40),
                        ),
                      ),
                    ),
                    SizedBox(height: smallGap),
                    _countBadge(context, _shareCount),
                    SizedBox(height: groupGap),
                    _railButton(
                      context,
                      IconButton(
                        onPressed: _toggleSave,
                        icon: Icon(
                          _isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: _isSaved ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onInverseSurface,
                        ),
                        iconSize: 30,
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size.square(40),
                        ),
                      ),
                    ),
                    SizedBox(height: groupGap),
                    _railButton(
                      context,
                      IconButton(
                        onPressed: _toggleRepost,
                        icon: Icon(
                          Icons.repeat,
                          color: _isReposted ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.onInverseSurface,
                        ),
                        iconSize: 30,
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size.square(40),
                        ),
                      ),
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

// Right-rail helpers: ensure icon legibility on light video frames
Widget _railButton(BuildContext context, Widget child) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.35),
      shape: BoxShape.circle,
    ),
    child: child,
  );
}

Widget _countBadge(BuildContext context, int count) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$count',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onInverseSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
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
