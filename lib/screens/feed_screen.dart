import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/services/storage_service.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/models/video_model.dart';

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

class _FeedScreenState extends ConsumerState<FeedScreen> with WidgetsBindingObserver {
  int _activeIndex = 0;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Ensure we don't hold wakelock when leaving feed
    WakelockPlus.disable();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      if (!widget.isVisible) {
        // When hidden, make sure wakelock is disabled
        WakelockPlus.disable();
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
        WakelockPlus.disable();
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final videosAsync = ref.watch(feedVideosProvider);
    final theme = Theme.of(context);

    final feedVisible = widget.isVisible && _appActive;
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.video.likesCount;
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
      WakelockPlus.enable();
    } else {
      _controller!.pause();
      WakelockPlus.disable();
    }
    setState(() {});
  }

  Future<void> _toggleLike() async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return;
      final liked = await _videoService.toggleLike(widget.video.id, uid);
      setState(() {
        _isLiked = liked;
        _likeCount += liked ? 1 : -1;
      });
      widget.onLikeToggled?.call();
    } catch (e) {
      debugPrint('❌ like toggle failed: $e');
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
                    WakelockPlus.disable();
                  } else {
                    if (widget.feedVisible && widget.isActive) {
                      _controller!.play();
                      WakelockPlus.enable();
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
                Text('@${widget.video.authorUsername ?? "unknown"}', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(widget.video.title, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (widget.video.description != null)
                  Text(widget.video.description!, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          // Right rail
          Positioned(
            bottom: 80,
            right: 16,
            child: Column(
              children: [
                IconButton(
                  onPressed: _toggleLike,
                  icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, color: Colors.white),
                  iconSize: 32,
                ),
                Text('$_likeCount', style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 16),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comments coming soon')));
                  },
                  icon: const Icon(Icons.comment, color: Colors.white),
                  iconSize: 32,
                ),
                Text('${widget.video.commentsCount}', style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 16),
                IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share coming soon')));
                  },
                  icon: const Icon(Icons.share, color: Colors.white),
                  iconSize: 32,
                ),
              ],
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
}
