import 'package:flutter/material.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/widgets/feed_item.dart';

class VideoPlayerScreen extends StatefulWidget {
  final List<VideoModel> videos;
  final int initialIndex;
  
  // NEW: Context Override. If this is set, we force the "Reposted" UI.
  final String? repostContextUsername;

  const VideoPlayerScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
    this.repostContextUsername,
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
    final currentVideo = widget.videos[_activeIndex];
    
    // LOGIC: Use the data on the video OR the context override
    final repostUser = currentVideo.repostedByUsername ?? widget.repostContextUsername;
    final isRepost = repostUser != null;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
        // Pass the resolved username to the badge
        title: isRepost ? _buildRepostBadge(repostUser) : null,
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.videos.length,
        onPageChanged: (index) {
          setState(() => _activeIndex = index);
        },
        itemBuilder: (context, index) {
          return VideoFeedItem(
            video: widget.videos[index],
            isActive: index == _activeIndex,
            feedVisible: true,
            onLikeToggled: () {},
          );
        },
      ),
    );
  }

  Widget _buildRepostBadge(String username) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3), // Glassmorphism
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat, color: Colors.white, size: 14),
          const SizedBox(width: 8),
          const Text(
            "Reposted",
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 4),
          // Clean username display
          Text(
            "by @$username",
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
