import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart'; // NEW ENGINE
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

import 'package:xprex/services/save_service.dart';
import 'package:xprex/services/repost_service.dart';

final feedVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  final videoService = VideoService();
  return await videoService.getForYouFeed(limit: 20);
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    if (_routeVisible) {
      setState(() => _routeVisible = false);
      _maybeDisableWakelock();
    }
  }

  @override
  void didPopNext() {
    if (!_routeVisible) {
      setState(() => _routeVisible = true);
    }
  }

  @override
  void dispose() {
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
        _maybeDisableWakelock();
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
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
            allowImplicitScrolling: true, // THE TIKTOK TRICK: Pre-loads next video
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return VideoFeedItem(
                key: ValueKey(video.id),
                video: video,
                isActive: index == _activeIndex,
                feedVisible: feedVisible,
                onLikeToggled: () {
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
  
  // NOTE: Constructor kept EXACTLY the same to support VideoPlayerScreen
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

  // UPGRADE: Using Cached Controller
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
  // --- STOPWATCH VARIABLES ---
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
      
      // UPGRADE: Enable Caching
      _controller = CachedVideoPlayerPlusController.networkUrl(
        Uri.parse(playableUrl),
        invalidateCacheIfOlderThan: const Duration(days: 30), // The TikTok Trick
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
    setState(() {});
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
      debugPrint('💰 Flushed $_secondsWatched seconds for video ${widget.video.id}');
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in to like videos')),
          );
        }
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
      debugPrint('❌ like toggle failed: $e');
      if (mounted) {
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
      debugPrint('❌ toggle save failed: $e');
      if (mounted) {
        setState(() {
           _isSaved = !_isSaved;
           _saveCount += _isSaved ? 1 : -1;
        });
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
      debugPrint('❌ toggle repost failed: $e');
      if (mounted) {
        setState(() {
          _isReposted = !_isReposted;
          _repostCount += _isReposted ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to repost. Please try again.')),
        );
      }
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
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
                      // UPGRADE: Using Cached Widget
                      child: CachedVideoPlayerPlus(_controller!),
                    ),
                  )
                : (widget.video.coverImageUrl != null
                    ? Image.network(widget.video.coverImageUrl!, fit: BoxFit.cover)
                    : Container(color: Colors.black)),
          ),
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
                  setState(() {});
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
                          _controller?.setVolume(0);
                          _maybeDisableWakelock();
                        } catch (_) {}
                        if (widget.video.authorAuthUserId.isNotEmpty) {
                          await context.push('/u/${widget.video.authorAuthUserId}');
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
                      outlined: false,
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
                      outlined: false,
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
                      outlined: false,
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
                      outlined: false,
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
                      outlined: false,
                    ),
                    SizedBox(height: smallGap),
                    _countBadge(context, _repostCount, glowColor: neon?.purple ?? theme.colorScheme.secondary, textScale: 2.0),
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
}

void _maybeEnableWakelock() {
  if (kIsWeb) return;
  try {
    WakelockPlus.enable();
  } catch (e) {
    debugPrint('wakelock enable ignored: $e');
  }
}

void _maybeDisableWakelock() {
  if (kIsWeb) return;
  try {
    WakelockPlus.disable();
  } catch (e) {
    debugPrint('wakelock disable ignored: $e');
  }
}

Widget _countBadge(BuildContext context, int count, {Color? glowColor, double textScale = 1.0}) {
  return Text(
    '$count',
    textAlign: TextAlign.center,
    style: TextStyle(
      color: Colors.white,
      fontSize: 80.0,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.0,
      height: 0.98,
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

class _CommentsSheet extends StatefulWidget {
  final String videoId;
  final int initialCount; 
  final VoidCallback? onNewComment;
  const _CommentsSheet({
    required this.videoId, 
    required this.initialCount, 
    this.onNewComment
  });
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _svc = CommentService();
  final _inputCtrl = TextEditingController();
  late Future<List<CommentModel>> _loader;
  bool _posting = false;
  late int _commentsCount;
  CommentModel? _replyingTo;
  final List<String> _quickEmojis = ['🔥', '😂', '😍', '👏', '😢', '😮', '💯', '🙏'];
  @override
  void initState() {
    super.initState();
    _commentsCount = widget.initialCount;
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
      String? parentId;
      if (_replyingTo != null) {
        parentId = _replyingTo!.parentId ?? _replyingTo!.id;
      }

      await _svc.createComment(
        videoId: widget.videoId, 
        authorAuthUserId: uid, 
        text: text,
        parentId: parentId,
      );
      _inputCtrl.clear();
      setState(() {
        _replyingTo = null; 
        _loader = _svc.getCommentsByVideo(widget.videoId);
        _commentsCount++;
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

  void _insertEmoji(String emoji) {
    _inputCtrl.text += emoji;
    _inputCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _inputCtrl.text.length));
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
        initialChildSize: 0.55, 
        minChildSize: 0.40,
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
                      Text('Comments', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      if (_commentsCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(_commentsCount.toString(), style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('No comments yet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Start the conversation.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          return _CommentRow(
                            comment: items[i], 
                            onReplyTap: (c) {
                               setState(() {
                                 _replyingTo = c;
                               });
                            },
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 20),
                      );
                    },
                  ),
                ),
                
                if (_replyingTo != null)
                  Container(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          'Replying to @${_replyingTo!.authorUsername ?? "user"}', 
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() => _replyingTo = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      ],
                    ),
                  ),

                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
                  ),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickEmojis.length,
                    separatorBuilder: (_,__) => const SizedBox(width: 16),
                    itemBuilder: (ctx, i) {
                      return GestureDetector(
                        onTap: () => _insertEmoji(_quickEmojis[i]),
                        child: Center(child: Text(_quickEmojis[i], style: const TextStyle(fontSize: 22))),
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
                      CircleAvatar(
                        radius: 18, 
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(Icons.person, size: 20, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _inputCtrl,
                          decoration: InputDecoration(
                            hintText: _replyingTo == null ? 'Add a comment...' : 'Add a reply...',
                            hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      IconButton(
                         onPressed: _posting ? null : _post,
                         icon: Icon(Icons.arrow_upward, color: _posting ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary),
                      )
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

class _CommentRow extends StatefulWidget {
  final CommentModel comment;
  final Function(CommentModel) onReplyTap;
  const _CommentRow({required this.comment, required this.onReplyTap});

  @override
  State<_CommentRow> createState() => _CommentRowState();
}

class _CommentRowState extends State<_CommentRow> {
  bool _repliesVisible = false;
  bool _loadingReplies = false;
  final _svc = CommentService();
  late bool _isLiked;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.isLiked;
    _likesCount = widget.comment.likesCount;
  }

  void _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    try {
      await _svc.toggleCommentLike(widget.comment.id);
    } catch (e) {
      if (mounted) {
         setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
      }
    }
  }

  Future<void> _fetchReplies() async {
    if (widget.comment.replies.isNotEmpty) {
      setState(() => _repliesVisible = !_repliesVisible);
      return;
    }

    setState(() {
      _loadingReplies = true;
      _repliesVisible = true;
    });
    try {
      final replies = await _svc.getReplies(widget.comment.id);
      if (mounted) {
        setState(() {
          widget.comment.replies = replies;
          _loadingReplies = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading replies: $e');
      if (mounted) setState(() => _loadingReplies = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.comment;
    final name = (c.authorDisplayName?.trim().isNotEmpty == true)
        ? c.authorDisplayName!
        : (c.authorUsername != null ? '@${c.authorUsername}' : 'User');
    
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20, 
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              backgroundImage: (c.authorAvatarUrl?.isNotEmpty == true) 
                  ? NetworkImage(c.authorAvatarUrl!) 
                  : null,
              child: (c.authorAvatarUrl?.isEmpty ?? true) 
                  ? Icon(Icons.person, color: theme.colorScheme.onSurfaceVariant, size: 24) 
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      const SizedBox(width: 6),
                      Text('2h', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(c.text, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.3)),
                  const SizedBox(height: 6),
                  
                  GestureDetector(
                    onTap: () => widget.onReplyTap(c),
                    child: Text('Reply', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                  ),

                  if (c.replyCount > 0) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _fetchReplies,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 30, height: 1, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                          const SizedBox(width: 12),
                          Text(
                            _repliesVisible && c.replies.isNotEmpty ? 'Hide replies' : 'View ${c.replyCount} replies',
                            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                          ),
                          if (_loadingReplies)
                            const Padding(
                               padding: EdgeInsets.only(left: 8.0),
                               child: SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                        ],
                      ),
                    ),
                  ]
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 8.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 18, 
                      color: _isLiked ? Colors.red : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_likesCount > 0)
                    Text('$_likesCount', style: theme.textTheme.labelSmall?.copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          ],
        ),

        if (_repliesVisible && c.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 52.0, top: 16),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: c.replies.length,
              separatorBuilder: (_,__) => const SizedBox(height: 16),
              itemBuilder: (ctx, i) {
                final r = c.replies[i];
                return _ReplyRow(reply: r, onReplyTap: widget.onReplyTap);
              },
            ),
          )
      ],
    );
  }
}

class _ReplyRow extends StatefulWidget {
  final CommentModel reply;
  final Function(CommentModel) onReplyTap;
  const _ReplyRow({required this.reply, required this.onReplyTap});
  @override
  State<_ReplyRow> createState() => _ReplyRowState();
}

class _ReplyRowState extends State<_ReplyRow> {
  final _svc = CommentService();
  late bool _isLiked;
  late int _likesCount;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.reply.isLiked;
    _likesCount = widget.reply.likesCount;
  }

  void _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    try {
      await _svc.toggleCommentLike(widget.reply.id);
    } catch (e) {
       if (mounted) setState(() { _isLiked = !_isLiked; _likesCount += _isLiked ? 1 : -1; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.reply;
    final name = (r.authorDisplayName?.trim().isNotEmpty == true)
        ? r.authorDisplayName!
        : (r.authorUsername != null ? '@${r.authorUsername}' : 'User');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          backgroundImage: (r.authorAvatarUrl?.isNotEmpty == true) ? NetworkImage(r.authorAvatarUrl!) : null,
          child: (r.authorAvatarUrl?.isEmpty ?? true) ? Icon(Icons.person, color: theme.colorScheme.onSurfaceVariant, size: 18) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(name, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 6),
                  Text('2h', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 2),
              Text(r.text, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14.5, height: 1.3)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => widget.onReplyTap(r),
                child: Text('Reply', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8.0, left: 8.0),
          child: Column(
            children: [
              GestureDetector(
                onTap: _toggleLike,
                child: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color: _isLiked ? Colors.red : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_likesCount > 0)
                Text('$_likesCount', style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        )
      ],
    );
  }
}
