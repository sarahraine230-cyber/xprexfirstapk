import 'package:flutter/material.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/screens/feed_screen.dart'; // Imports FeedItem
import 'package:cached_video_player_plus/cached_video_player_plus.dart';

class VideoPlayerScreen extends StatefulWidget {
  final List<VideoModel> videos;
  final int initialIndex;

  const VideoPlayerScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late PageController _pageController;
  final Map<int, CachedVideoPlayerPlusController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _initializeControllerAtIndex(widget.initialIndex);
  }

  Future<void> _initializeControllerAtIndex(int index) async {
    if (index < 0 || index >= widget.videos.length) return;
    if (_controllers.containsKey(index)) return;

    final videoUrl = widget.videos[index].storagePath;
    final controller = CachedVideoPlayerPlusController.networkUrl(Uri.parse(videoUrl));

    _controllers[index] = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (index == widget.initialIndex) {
        controller.play();
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing player: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var c in _controllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.videos.length,
        onPageChanged: (index) {
          _controllers[index]?.play();
          _controllers[index - 1]?.pause();
          _controllers[index + 1]?.pause();
          _initializeControllerAtIndex(index + 1);
        },
        itemBuilder: (context, index) {
          // Re-uses the robust FeedItem from the FeedScreen
          return FeedItem(
            video: widget.videos[index],
            controller: _controllers[index],
            // FIXED: Changed from isFocused to isVisible to match FeedScreen
            isVisible: true, 
          );
        },
      ),
    );
  }
}
