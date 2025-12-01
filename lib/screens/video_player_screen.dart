import 'package:flutter/material.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/screens/feed_screen.dart'; // Needed for VideoFeedItem

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
  late int _activeIndex;

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      // A generic AppBar that floats on top
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.videos.length,
        onPageChanged: (index) {
          setState(() => _activeIndex = index);
        },
        itemBuilder: (context, index) {
          // Reuse the feed item logic
          return VideoFeedItem(
            video: widget.videos[index],
            isActive: index == _activeIndex,
            feedVisible: true, // Always play since we are on the player screen
            onLikeToggled: () {
              // Optional: You could update local state here if needed
            },
          );
        },
      ),
    );
  }
}
