import 'package:flutter/material.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/screens/feed_screen.dart'; // Imports VideoFeedItem

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
      // Allow the video to go behind the status bar
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // White back arrow for visibility on dark video
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
          // We reuse the exact same item from the Feed!
          return VideoFeedItem(
            video: widget.videos[index],
            isActive: index == _activeIndex,
            feedVisible: true, // Always play since this screen is top
            onLikeToggled: () {
              // Optional: Update search list state if needed
            }, 
          );
        },
      ),
    );
  }
}
