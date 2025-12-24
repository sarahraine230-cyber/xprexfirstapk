import 'package:flutter/material.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/widgets/feed_item.dart';

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
    // 1. Get the current video to check its status
    final currentVideo = widget.videos[_activeIndex];
    
    // 2. Check if it is a repost
    final isRepost = currentVideo.repostedByUsername != null;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      
      // 3. Dynamic AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: Colors.white),
        
        // Only show the badge if it's a repost
        title: isRepost ? _buildRepostBadge(currentVideo) : null,
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
            onLikeToggled: () {
              // Optional: Update local state if needed
            },
          );
        },
      ),
    );
  }

  // 4. The "Instagram-Style" Repost Header Widget
  Widget _buildRepostBadge(VideoModel video) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3), // Semi-transparent "Glass" effect
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
          // Optionally show the username if available
          if (video.repostedByUsername != null) ...[
            const SizedBox(width: 4),
            Text(
              "by @${video.repostedByUsername}",
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ]
        ],
      ),
    );
  }
}
