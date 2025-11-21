import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/models/video_model.dart';

final feedVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  final videoService = VideoService();
  return await videoService.getFeedVideos(limit: 20);
});

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(feedVideosProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('XpreX'),
        centerTitle: true,
      ),
      body: videosAsync.when(
        data: (videos) {
          if (videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library_outlined, size: 80, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No videos yet', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Be the first to upload!', style: theme.textTheme.bodyMedium),
                ],
              ),
            );
          }

          return PageView.builder(
            scrollDirection: Axis.vertical,
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return Container(
                color: Colors.black,
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_outline, size: 100, color: Colors.white.withValues(alpha: 0.7)),
                          const SizedBox(height: 16),
                          Text(video.title, style: theme.textTheme.titleLarge?.copyWith(color: Colors.white), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 80,
                      left: 16,
                      right: 80,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('@${video.authorUsername ?? "unknown"}', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (video.description != null)
                            Text(video.description!, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 80,
                      right: 16,
                      child: Column(
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: Icon(Icons.favorite_border, color: Colors.white),
                            iconSize: 32,
                          ),
                          Text('${video.likesCount}', style: TextStyle(color: Colors.white)),
                          const SizedBox(height: 16),
                          IconButton(
                            onPressed: () {},
                            icon: Icon(Icons.comment, color: Colors.white),
                            iconSize: 32,
                          ),
                          Text('${video.commentsCount}', style: TextStyle(color: Colors.white)),
                          const SizedBox(height: 16),
                          IconButton(
                            onPressed: () {},
                            icon: Icon(Icons.share, color: Colors.white),
                            iconSize: 32,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Error loading feed', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(error.toString(), style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
