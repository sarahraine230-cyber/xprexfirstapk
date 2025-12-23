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
import 'package:xprex/widgets/comment_sheet.dart';
import 'package:xprex/widgets/social_rail.dart'; // <--- IMPORT THE NEW RAIL

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
  
  // State for Social Actions
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
    if (widget.feedVisible && widget.isActive) {
      _controller!.play();
      _maybeEnableWakelock();
      _startWatchTimer();
    } else {
      _controller!.pause();
      _maybeDisableWakelock();
      _stopWatchTimer();
    }
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

  // --- ACTIONS ---
  Future<void> _toggleLike() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return _showAuthSnack('like');
    
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    widget.onLikeToggled?.call();
    try {
      await _videoService.toggleLike(widget.video.id, uid);
    } catch (_) {
      setState(() { _isLiked = !_isLiked; _likeCount += _isLiked ? 1 : -1; });
    }
  }

  Future<void> _toggleSave() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return _showAuthSnack('save');
    
    setState(() { _isSaved = !_isSaved; _saveCount += _isSaved ? 1 : -1; });
    try {
      await _saveService.toggleSave(widget.video.id, uid);
    } catch (_) {
      setState(() { _isSaved = !_isSaved; _saveCount += _isSaved ? 1 : -1; });
    }
  }

  Future<void> _toggleRepost() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return _showAuthSnack('repost');

    setState(() { _isReposted = !_isReposted; _repostCount += _isReposted ? 1 : -1; });
    try {
      await _repostService.toggleRepost(widget.video.id, uid);
    } catch (_) {
      setState(() { _isReposted = !_isReposted; _repostCount += _isReposted ? 1 : -1; });
    }
  }
  
  void _showAuthSnack(String action) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please sign in to $action')));
  }

  void _openComments() {
    _controller?.pause();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        videoId: widget.video.id,
        initialCount: _commentsCount,
        onNewComment: () => setState(() => _commentsCount++),
      ),
    ).whenComplete(() {
      if (widget.feedVisible && widget.isActive) _controller?.play();
    });
  }

  Future<void> _handleShare() async {
    final deepLink = AppLinks.videoLink(widget.video.id);
    final url = deepLink.isNotEmpty ? deepLink : await _storage.resolveVideoUrl(widget.video.storagePath);
    await Share.share(url);
    setState(() => _shareCount++);
    final uid = supabase.auth.currentUser?.id;
    if (uid != null) _videoService.recordShare(widget.video.id, uid);
  }

  @override
  void dispose() {
    _flushWatchTime();
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    try { _controller?.dispose(); } catch (_) {}
    _controller = null;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(context);
    final railHeight = size.height * 0.4;
    final bottomGuard = padding.bottom + 88.0;

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // 1. VIDEO PLAYER
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
          
          // 2. TAP TO PAUSE
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                   if (_controller == null) return;
                   _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
                },
              ),
            ),
          ),
          
          // 3. BOTTOM INFO
          Positioned(
            bottom: 80,
            left: 16,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CircleAvatar(radius: 18, backgroundImage: NetworkImage(widget.video.authorAvatarUrl ?? 'https://placehold.co/50')),
                  const SizedBox(width: 8),
                  Text('@${widget.video.authorUsername ?? "User"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 8),
                Text(widget.video.title, style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
          
          // 4. SOCIAL RAIL (MODULAR WIDGET)
          Positioned(
            right: 8,
            bottom: bottomGuard,
            child: SizedBox(
              width: 60,
              child: SocialRail(
                isLiked: _isLiked,
                likeCount: _likeCount,
                onLike: _toggleLike,
                commentsCount: _commentsCount,
                onComment: _openComments,
                shareCount: _shareCount,
                onShare: _handleShare,
                isSaved: _isSaved,
                saveCount: _saveCount,
                onSave: _toggleSave,
                isReposted: _isReposted,
                repostCount: _repostCount,
                onRepost: _toggleRepost,
              ),
            ),
          ),
          
          if (_loading) const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}

void _maybeEnableWakelock() {
  if (kIsWeb) return;
  try { WakelockPlus.enable(); } catch (_) {}
}

void _maybeDisableWakelock() {
  if (kIsWeb) return;
  try { WakelockPlus.disable(); } catch (_) {}
}
