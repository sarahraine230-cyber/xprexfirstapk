import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart'; // NEW ENGINE
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/services/save_service.dart';
import 'package:xprex/services/repost_service.dart';
import 'package:xprex/services/comment_service.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/models/comment_model.dart';

final feedVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  final videoService = VideoService();
  return await videoService.getFeedVideos();
});

class FeedScreen extends ConsumerWidget {
  final bool isVisible; // Kept for MainShell compatibility

  const FeedScreen({
    super.key,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedVideosProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text('Error loading feed', style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.refresh(feedVideosProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (videos) {
          if (videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam_off, color: Colors.white54, size: 64),
                  const SizedBox(height: 16),
                  const Text('No videos yet', style: TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => ref.refresh(feedVideosProvider),
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            );
          }
          return FeedPageView(videos: videos, isVisible: isVisible);
        },
      ),
    );
  }
}

class FeedPageView extends StatefulWidget {
  final List<VideoModel> videos;
  final bool isVisible;

  const FeedPageView({
    super.key,
    required this.videos,
    required this.isVisible,
  });

  @override
  State<FeedPageView> createState() => _FeedPageViewState();
}

class _FeedPageViewState extends State<FeedPageView> {
  final PageController _pageController = PageController();
  int _focusedIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: widget.videos.length,
      onPageChanged: (index) {
        setState(() {
          _focusedIndex = index;
        });
      },
      itemBuilder: (context, index) {
        // PageView automatically builds index, index-1, and index+1.
        // This means the next video (index+1) initializes and caches 
        // silently while you watch the current one.
        return FeedItem(
          video: widget.videos[index],
          isFocused: widget.isVisible && (index == _focusedIndex),
        );
      },
    );
  }
}

class FeedItem extends ConsumerStatefulWidget {
  final VideoModel video;
  final bool isFocused;

  const FeedItem({
    super.key,
    required this.video,
    required this.isFocused,
  });

  @override
  ConsumerState<FeedItem> createState() => _FeedItemState();
}

class _FeedItemState extends ConsumerState<FeedItem> with RouteAware {
  // NEW ENGINE CONTROLLER
  CachedVideoPlayerPlusController? _controller;
  
  bool _isInitialized = false;
  bool _isLiked = false;
  int _likesCount = 0;
  bool _showHeart = false; // Double tap animation

  @override
  void initState() {
    super.initState();
    _isLiked = widget.video.isLikedByCurrentUser ?? false;
    _likesCount = widget.video.likesCount;
    _initializeVideo();
  }

  @override
  void didUpdateWidget(FeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused != oldWidget.isFocused) {
      if (widget.isFocused) {
        _play();
      } else {
        _pause();
      }
    }
  }

  Future<void> _initializeVideo() async {
    // Uses the Cached Player to download & cache the video file
    _controller = CachedVideoPlayerPlusController.networkUrl(
      Uri.parse(widget.video.storagePath),
      invalidateCacheIfOlderThan: const Duration(days: 30),
    );

    try {
      await _controller!.initialize();
      await _controller!.setLooping(true);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
      if (widget.isFocused) {
        _play();
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  void _play() {
    if (_isInitialized && _controller != null) {
      _controller!.play();
      WakelockPlus.enable();
    }
  }

  void _pause() {
    if (_isInitialized && _controller != null) {
      _controller!.pause();
      WakelockPlus.disable();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    // Fire and forget
    VideoService().toggleLike(widget.video.id);
  }

  void _handleDoubleTap() {
    if (!_isLiked) _toggleLike();
    setState(() => _showHeart = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(
        videoId: widget.video.id, 
        authorId: widget.video.authorAuthUserId
      ),
    );
  }

  void _onShare() {
     Share.share('Check out this video on XpreX: ${widget.video.title}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. VIDEO LAYER
        GestureDetector(
          onTap: () {
            if (_isInitialized && _controller != null) {
              _controller!.value.isPlaying ? _pause() : _play();
            }
          },
          onDoubleTap: _handleDoubleTap,
          child: Container(
            color: Colors.black,
            child: _isInitialized
                ? AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    // NEW WIDGET
                    child: CachedVideoPlayerPlus(_controller!), 
                  )
                : Stack(
                    children: [
                      // Thumbnail placeholder
                      if (widget.video.coverImageUrl != null)
                        Positioned.fill(
                          child: Image.network(
                            widget.video.coverImageUrl!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      // Loading spinner
                      const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white, 
                          strokeWidth: 2
                        )
                      ),
                    ],
                  ),
          ),
        ),

        // 2. GRADIENT OVERLAY (Restored)
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                ],
                begin: Alignment.center,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),

        // 3. RIGHT ACTION BAR (Restored)
        Positioned(
          right: 8,
          bottom: 100,
          child: Column(
            children: [
              // Avatar
              GestureDetector(
                onTap: () {
                   context.push('/profile/${widget.video.authorAuthUserId}');
                },
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white24,
                  backgroundImage: widget.video.authorAvatarUrl != null 
                    ? NetworkImage(widget.video.authorAvatarUrl!) 
                    : null,
                  child: widget.video.authorAvatarUrl == null 
                    ? const Icon(Icons.person, color: Colors.white) 
                    : null,
                ),
              ),
              const SizedBox(height: 24),
              
              // Like
              _buildAction(
                context, 
                icon: _isLiked ? Icons.favorite : Icons.favorite_border, 
                color: _isLiked ? Colors.red : Colors.white,
                label: '$_likesCount',
                onTap: _toggleLike
              ),
              
              // Comment
              _buildAction(
                context, 
                icon: Icons.comment, 
                label: '${widget.video.commentsCount}', 
                onTap: _showComments
              ),
              
              // Save
              _SaveButton(videoId: widget.video.id),
              
              // Share
              _buildAction(
                context, 
                icon: Icons.share, 
                label: 'Share', 
                onTap: _onShare
              ),
              
              // Repost
              _RepostButton(videoId: widget.video.id),
            ],
          ),
        ),

        // 4. BOTTOM INFO (Restored)
        Positioned(
          left: 16,
          bottom: 24,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${widget.video.authorUsername}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.video.title,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.video.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 4,
                    children: widget.video.tags.map((t) => Text(
                      '#$t', 
                      style: const TextStyle(
                        color: Colors.white70, 
                        fontWeight: FontWeight.bold
                      )
                    )).toList(),
                  ),
                ),
            ],
          ),
        ),

        // 5. DOUBLE TAP HEART ANIMATION (Restored)
        if (_showHeart)
          const Center(
            child: Icon(Icons.favorite, color: Colors.white, size: 100),
          ),
      ],
    );
  }

  Widget _buildAction(BuildContext context, {
    required IconData icon, 
    required String label, 
    required VoidCallback onTap, 
    Color color = Colors.white
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 4),
            Text(
              label, 
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 12, 
                fontWeight: FontWeight.w600
              )
            ),
          ],
        ),
      ),
    );
  }
}

// --- HELPER BUTTONS (Restored) ---

class _SaveButton extends StatefulWidget {
  final String videoId;
  const _SaveButton({required this.videoId});
  @override
  State<_SaveButton> createState() => _SaveButtonState();
}
class _SaveButtonState extends State<_SaveButton> {
  bool _isSaved = false;
  @override 
  void initState() { super.initState(); _check(); }
  void _check() async {
    final s = await SaveService().isSaved(widget.videoId);
    if(mounted) setState(() => _isSaved = s);
  }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () async {
          setState(() => _isSaved = !_isSaved);
          await SaveService().toggleSave(widget.videoId);
        },
        child: Column(
          children: [
            Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, size: 32, color: Colors.white),
            const SizedBox(height: 4),
            const Text('Save', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _RepostButton extends StatelessWidget {
  final String videoId;
  const _RepostButton({required this.videoId});
  @override
  Widget build(BuildContext context) {
     return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () async {
           await RepostService().repostVideo(widget.videoId);
           if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Reposted!'))
             );
           }
        },
        child: const Column(
          children: [
            Icon(Icons.repeat, size: 32, color: Colors.white),
            SizedBox(height: 4),
            Text('Repost', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// --- COMMENTS SHEET (Restored) ---
class CommentsSheet extends StatefulWidget {
  final String videoId;
  final String authorId;
  const CommentsSheet({super.key, required this.videoId, required this.authorId});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}
class _CommentsSheetState extends State<CommentsSheet> {
  final _commentService = CommentService();
  final _textController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Uses the app's bottom sheet styling
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(),
          Expanded(
            child: FutureBuilder<List<CommentModel>>(
              future: _commentService.getComments(widget.videoId),
              builder: (ctx, snapshot) {
                if(!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final comments = snapshot.data!;
                if(comments.isEmpty) return const Center(child: Text('No comments yet.'));
                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (ctx, i) => ListTile(
                    leading: CircleAvatar(
                      backgroundImage: comments[i].authorAvatarUrl != null 
                          ? NetworkImage(comments[i].authorAvatarUrl!) 
                          : null,
                      child: comments[i].authorAvatarUrl == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(comments[i].authorUsername, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(comments[i].text),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController, 
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    )
                  )
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send), 
                  color: theme.colorScheme.primary,
                  onPressed: () async {
                   if(_textController.text.isNotEmpty) {
                     await _commentService.postComment(widget.videoId, _textController.text);
                     _textController.clear();
                     setState((){});
                   }
                }),
              ],
            ),
          )
        ],
      ),
    );
  }
}
