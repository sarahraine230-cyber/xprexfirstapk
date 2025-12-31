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
import 'package:xprex/services/profile_service.dart'; // NEW: Import ProfileService
import 'package:xprex/widgets/comment_sheet.dart';
import 'package:xprex/widgets/social_rail.dart';

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

class _VideoFeedItemState extends State<VideoFeedItem> with SingleTickerProviderStateMixin {
  final _storage = StorageService();
  final _videoService = VideoService();
  final _saveService = SaveService();
  final _repostService = RepostService();
  final _profileService = ProfileService(); // NEW: Profile Service Instance

  CachedVideoPlayerPlusController? _controller;
  
  late AnimationController _playPauseController;
  late Animation<double> _playPauseAnimation;

  // Initialized immediately to prevent "pop-in"
  late int _likeCount;
  late int _commentsCount;
  late int _shareCount;
  late int _saveCount;
  late int _repostCount;
  
  bool _isLiked = false;
  bool _isSaved = false;
  bool _isReposted = false;
  bool _isFollowing = false; // NEW: Follow State
  
  bool _loading = true;
  Timer? _watchTimer;
  int _secondsWatched = 0;
  bool _hasRecordedView = false;
  
  @override
  void initState() {
    super.initState();
    _playPauseController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 200),
    );
    _playPauseAnimation = CurvedAnimation(parent: _playPauseController, curve: Curves.easeOut);

    // --- INSTANT LOAD PROTOCOL ---
    _likeCount = widget.video.likesCount;
    _commentsCount = widget.video.commentsCount;
    _saveCount = widget.video.savesCount;
    _repostCount = widget.video.repostsCount;
    _shareCount = widget.video.sharesCount;

    _init();
  }

  @override
  void didUpdateWidget(covariant VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _flushWatchTime();
      _disposeController();
      _loading = true;
      // Reset states for new video
      _isFollowing = false; 
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
      
      // FRAUD CHECK: Do not record view if author is watching own video
      final uid = supabase.auth.currentUser?.id;
      final isOwnVideo = uid == widget.video.authorAuthUserId;

      if (widget.video.authorAuthUserId.isNotEmpty && !_hasRecordedView && !isOwnVideo) {
        _videoService.recordView(widget.video.id, widget.video.authorAuthUserId);
        _hasRecordedView = true;
      }
      
      if (uid != null) {
        // Fetch engagement states
        _videoService.isVideoLikedByUser(widget.video.id, uid).then((liked) {
          if (mounted) setState(() => _isLiked = liked);
        });
        _saveService.isVideoSaved(widget.video.id, uid).then((saved) {
          if (mounted) setState(() => _isSaved = saved);
        });
        _repostService.isVideoReposted(widget.video.id, uid).then((reposted) {
          if (mounted) setState(() => _isReposted = reposted);
        });
        
        // NEW: Check Follow Status (Only if not own video)
        if (!isOwnVideo) {
          _profileService.isFollowing(followerId: uid, followeeId: widget.video.authorAuthUserId)
              .then((following) {
            if (mounted) setState(() => _isFollowing = following);
          });
        }
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
      _playPauseController.reverse(); 
      _ensureWakelockEnabled();
      _startWatchTimer();
    } else {
      _controller!.pause();
      _stopWatchTimer();
    }
  }

  void _ensureWakelockEnabled() {
    if (kIsWeb) return;
    try { WakelockPlus.enable();
    } catch (_) {}
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
      if (uid != null && uid != widget.video.authorAuthUserId) {
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

  // --- INTERACTION HANDLERS ---

  Future<void> _toggleLike() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return _showAuthSnack('like');
    
    setState(() { _isLiked = !_isLiked; _likeCount += _isLiked ? 1 : -1; });
    try { await _videoService.toggleLike(widget.video.id, uid);
    } catch (_) { 
      if (mounted) setState(() { _isLiked = !_isLiked; _likeCount += _isLiked ? 1 : -1; });
    }
  }

  Future<void> _toggleSave() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return _showAuthSnack('save');
    setState(() { _isSaved = !_isSaved; _saveCount += _isSaved ? 1 : -1; });
    try { await _saveService.toggleSave(widget.video.id, uid); } catch (_) { if (mounted) setState(() { _isSaved = !_isSaved; _saveCount += _isSaved ? 1 : -1; });
    }
  }

  Future<void> _toggleRepost() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return _showAuthSnack('repost');
    setState(() { _isReposted = !_isReposted; _repostCount += _isReposted ? 1 : -1; });
    try { await _repostService.toggleRepost(widget.video.id, uid); } catch (_) { if (mounted) setState(() { _isReposted = !_isReposted; _repostCount += _isReposted ? 1 : -1; });
    }
  }

  // NEW: Toggle Follow Logic
  Future<void> _toggleFollow() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return _showAuthSnack('follow');
    if (uid == widget.video.authorAuthUserId) return; // Can't follow self

    // Optimistic Update
    setState(() => _isFollowing = !_isFollowing);

    try {
      if (_isFollowing) {
        await _profileService.followUser(followerId: uid, followeeId: widget.video.authorAuthUserId);
      } else {
        await _profileService.unfollowUser(followerId: uid, followeeId: widget.video.authorAuthUserId);
      }
    } catch (e) {
      // Revert if failed
      if (mounted) setState(() => _isFollowing = !_isFollowing);
      debugPrint("Follow error: $e");
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
    final url = deepLink.isNotEmpty ?
      deepLink : await _storage.resolveVideoUrl(widget.video.storagePath);
    await Share.share(url);
    
    setState(() => _shareCount++);
    
    final uid = supabase.auth.currentUser?.id;
    if (uid != null) _videoService.recordShare(widget.video.id, uid);
  }

  @override
  void dispose() {
    _flushWatchTime();
    _disposeController();
    _playPauseController.dispose();
    super.dispose();
  }

  void _disposeController() {
    try { _controller?.dispose();
    } catch (_) {}
    _controller = null;
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    final bottomInset = padding.bottom + 52.0; 
    // Check if it's my own video to hide follow button
    final isOwnVideo = supabase.auth.currentUser?.id == widget.video.authorAuthUserId;

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
          
          // 2. TAP DETECTOR
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                   if (_controller == null) return;
                   if (_controller!.value.isPlaying) {
                     _controller!.pause();
                     _playPauseController.forward();
                   } else {
                     _controller!.play();
                     _playPauseController.reverse();
                   }
                },
              ),
            ),
          ),

          // 3. PAUSE ANIMATION
          IgnorePointer(
            child: Center(
              child: FadeTransition(
                opacity: _playPauseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 64),
                ),
              ),
            ),
          ),

          // 4. VIGNETTE
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.7)],
                    stops: const [0.6, 0.8, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          
          // 5. BOTTOM METADATA
          Positioned(
            bottom: bottomInset,
            left: 12,
            right: 80, 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Author Profile
                    GestureDetector(
                      onTap: () {
                        if (widget.video.authorAuthUserId.isNotEmpty) {
                          context.push('/u/${widget.video.authorAuthUserId}');
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            backgroundImage: NetworkImage(widget.video.authorAvatarUrl ?? 'https://placehold.co/50'),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.video.authorDisplayName ?? '@${widget.video.authorUsername ?? "User"}', 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
                          ),
                        ],
                      ),
                    ),
                    
                    // NEW: Follow Button Logic
                    if (!isOwnVideo && !_isFollowing) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _toggleFollow,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white70),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.transparent,
                          ),
                          child: const Text(
                            "Follow",
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 8),
                if (widget.video.title.isNotEmpty)
                  Text(
                    widget.video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w400, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
                  ),
                if (widget.video.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      widget.video.tags.map((t) => '#$t').join(' '),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          
          // 6. SOCIAL RAIL
          Positioned(
            right: 8,
            bottom: bottomInset,
            child: SizedBox(
              width: 50,
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
          
          // 7. PROGRESS BAR
          if (_controller != null && _controller!.value.isInitialized)
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              height: 4, 
              child: AnimatedBuilder(
                animation: _controller!,
                builder: (context, child) {
                  final duration = _controller!.value.duration.inMilliseconds;
                  final position = _controller!.value.position.inMilliseconds;
                  double value = 0;
                  if (duration > 0) value = position / duration;
                  return LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 4,
                  );
                },
              ),
            ),

          if (_loading) const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      ),
    );
  }
}
