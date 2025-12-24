import 'package:flutter/material.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/widgets/feed_item.dart';

class VideoPlayerScreen extends StatefulWidget {
  final List<VideoModel> videos;
  final int initialIndex;
  
  // This is the "Context Key" passed from the Profile
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
    
    // LOGIC: Check both the video data AND the context override
    final repostUser = currentVideo.repostedByUsername ?? widget.repostContextUsername;
    final isRepost = repostUser != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. THE VIDEO PLAYER (Base Layer)
          PageView.builder(
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

          // 2. TOP NAVIGATION AREA (Gradient for visibility)
          Positioned(
            top: 0, left: 0, right: 0,
            height: 120, // ample space for status bar + header
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),

          // 3. BACK BUTTON (Top Left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // 4. THE REPOST BADGE (Top Center - FORCED VISIBILITY)
          if (isRepost)
            Positioned(
              top: MediaQuery.of(context).padding.top + 18,
              left: 0,
              right: 0,
              child: Center(
                child: _buildRepostBadge(repostUser),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRepostBadge(String username) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2), // Subtle glass effect
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.repeat, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          const Text(
            "Reposted",
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 4),
          // Clean username display
          Text(
            "@$username",
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
