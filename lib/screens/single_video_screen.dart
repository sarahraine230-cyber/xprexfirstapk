import 'package:flutter/material.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/widgets/feed_item.dart';

class SingleVideoScreen extends StatefulWidget {
  final String videoId;
  const SingleVideoScreen({super.key, required this.videoId});

  @override
  State<SingleVideoScreen> createState() => _SingleVideoScreenState();
}

class _SingleVideoScreenState extends State<SingleVideoScreen> {
  late Future<VideoModel?> _videoLoader;

  @override
  void initState() {
    super.initState();
    _videoLoader = VideoService().getVideoById(widget.videoId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: Colors.white),
      ),
      body: FutureBuilder<VideoModel?>(
        future: _videoLoader,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  const Text("Video not found", style: TextStyle(color: Colors.white)),
                ],
              ),
            );
          }

          // We reuse the Feed Item but set feedVisible to true so it plays
          return VideoFeedItem(
            video: snapshot.data!,
            isActive: true,
            feedVisible: true,
          );
        },
      ),
    );
  }
}
