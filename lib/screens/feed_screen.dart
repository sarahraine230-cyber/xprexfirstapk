import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart'; // NEW: Cached Player
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xprex/router/app_router.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/services/comment_service.dart';
import 'package:xprex/models/comment_model.dart';
import 'package:xprex/theme.dart';
import 'package:xprex/services/save_service.dart';
import 'package:xprex/services/repost_service.dart';

// --- FEED PROVIDER ---
final feedVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  final videoService = VideoService();
  // Fetches videos. If you move this fetch to main_shell.dart or splash, 
  // it would start even faster, but this is efficient enough for now.
  return await videoService.getFeedVideos();
});

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

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
              TextButton(
                onPressed: () => ref.refresh(feedVideosProvider), 
                child: const Text('Retry')
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
          // Pass videos to the Smart Player
          return FeedPlayer(videos: videos);
        },
      ),
    );
  }
}

// --- THE SMART PLAYER (PRE-CACHING LOGIC) ---
class FeedPlayer extends StatefulWidget {
  final List<VideoModel> videos;
  const FeedPlayer({super.key, required this.videos});

  @override
  State<FeedPlayer> createState() => _FeedPlayerState();
}

class _FeedPlayerState extends State<FeedPlayer> {
  late PageController _pageController;
  
  // Manage multiple controllers: { index: Controller }
  final Map<int, CachedVideoPlayerPlusController> _controllers = {};
  
  int _focusedIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Initialize the first few videos immediately
    _initializeControllerAtIndex(0);
    _initializeControllerAtIndex(1); // Pre-load next
  }

  Future<void> _initializeControllerAtIndex(int index) async {
    if (index < 0 || index >= widget.videos.length) return;
    if (_controllers.containsKey(index)) return; // Already inited

    final videoUrl = widget.videos[index].storagePath; // Assuming full URL or handling path logic
    
    // Create Controller
    final controller = CachedVideoPlayerPlusController.networkUrl(
      Uri.parse(videoUrl),
      httpHeaders: {}, // Add auth headers if R2 is private
      invalidateCacheIfOlderThan: const Duration(days: 7), // Cache for 7 days
    );

    _controllers[index] = controller;

    try {
      await controller.initialize();
      await controller.setLooping(true);
      
      // If this is the active video, play it
      if (index == _focusedIndex) {
        await controller.play();
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing video $index: $e');
    }
  }

  void _disposeControllerAtIndex(int index) {
    if (_controllers.containsKey(index)) {
      _controllers[index]?.dispose();
      _controllers.remove(index);
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _focusedIndex = index;
    });

    // 1. Play Current
    final current = _controllers[index];
    current?.play();

    // 2. Pause Previous
    final prev = _controllers[index - 1];
    prev?.pause();

    // 3. Pause Next (if user swiped back)
    final next = _controllers[index + 1];
    next?.pause();

    // 4. SMART PRE-LOAD STRATEGY
    // Load the next 2 videos to ensure instant swipe
    _initializeControllerAtIndex(index + 1);
    _initializeControllerAtIndex(index + 2);

    // 5. Cleanup OLD videos to save RAM (keep previous 1 for quick back-swipe)
    _disposeControllerAtIndex(index - 2);
    _disposeControllerAtIndex(index + 2); // Optional: Dispose future videos if jumping far
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: widget.videos.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        return FeedItem(
          video: widget.videos[index],
          controller: _controllers[index],
          isFocused: index == _focusedIndex,
        );
      },
    );
  }
}

// --- SINGLE FEED ITEM ---
class FeedItem extends ConsumerStatefulWidget {
  final VideoModel video;
  final CachedVideoPlayerPlusController? controller;
  final bool isFocused;

  const FeedItem({
    super.key,
    required this.video,
    required this.controller,
    required this.isFocused,
  });

  @override
  ConsumerState<FeedItem> createState() => _FeedItemState();
}

class _FeedItemState extends ConsumerState<FeedItem> with RouteAware {
  bool _isLiked = false;
  int _likesCount = 0;
  bool _showHeart = false; // For double-tap animation

  @override
  void initState() {
    super.initState();
    _isLiked = widget.video.isLikedByCurrentUser;
    _likesCount = widget.video.likesCount;
    WakelockPlus.enable();
  }

  @override
  void didUpdateWidget(FeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused && widget.controller != null && widget.controller!.value.isInitialized) {
      widget.controller!.play();
    } else if (!widget.isFocused && widget.controller != null) {
      widget.controller!.pause();
    }
  }

  void _toggleLike() {
    final service = VideoService();
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    service.toggleLike(widget.video.id);
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
      builder: (_) => CommentsSheet(videoId: widget.video.id, authorId: widget.video.authorAuthUserId),
    );
  }

  void _onShare() {
     Share.share('Check out this video on XpreX: ${widget.video.title}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. VIDEO LAYER
        GestureDetector(
          onTap: () {
            if (controller != null && controller.value.isInitialized) {
              controller.value.isPlaying ? controller.pause() : controller.play();
            }
          },
          onDoubleTap: _handleDoubleTap,
          child: Container(
            color: Colors.black,
            child: (controller != null && controller.value.isInitialized)
                ? AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: CachedVideoPlayerPlus(controller),
                  )
                : Stack(
                  children: [
                    // Placeholder while initializing
                    if (widget.video.coverImageUrl != null)
                      Positioned.fill(
                        child: Image.network(
                          widget.video.coverImageUrl!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    // Loading Indicator
                    const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  ],
                ),
          ),
        ),

        // 2. GRADIENT OVERLAY
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

        // 3. RIGHT ACTION BAR
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
                  backgroundImage: widget.video.authorAvatarUrl != null 
                    ? NetworkImage(widget.video.authorAvatarUrl!) 
                    : null,
                  child: widget.video.authorAvatarUrl == null ? const Icon(Icons.person) : null,
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
              _buildAction(context, icon: Icons.comment, label: '${widget.video.commentsCount}', onTap: _showComments),
              
              // Save
              _SaveButton(videoId: widget.video.id),
              
              // Share
              _buildAction(context, icon: Icons.share, label: 'Share', onTap: _onShare),
              
              // Repost (Using Service)
              _RepostButton(videoId: widget.video.id),
            ],
          ),
        ),

        // 4. BOTTOM INFO
        Positioned(
          left: 16,
          bottom: 24,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${widget.video.authorUsername}',
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
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
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)
                    )).toList(),
                  ),
                ),
            ],
          ),
        ),

        // 5. DOUBLE TAP HEART ANIMATION
        if (_showHeart)
          const Center(
            child: Icon(Icons.favorite, color: Colors.white, size: 100),
          ),
      ],
    );
  }

  Widget _buildAction(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, Color color = Colors.white}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// --- HELPER BUTTONS ---
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
           await RepostService().repostVideo(videoId);
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reposted!')));
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

// --- COMMENTS SHEET (Placeholder wrapper) ---
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
    // Basic Comment UI Implementation
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    leading: CircleAvatar(backgroundImage: NetworkImage(comments[i].authorAvatarUrl ?? '')),
                    title: Text(comments[i].authorUsername, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(comments[i].text),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _textController, decoration: const InputDecoration(hintText: 'Add a comment...'))),
                IconButton(icon: const Icon(Icons.send), onPressed: () async {
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
