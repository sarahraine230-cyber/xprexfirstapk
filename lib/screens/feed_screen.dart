import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:xprex/router/app_router.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/services/storage_service.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/config/app_links.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/services/comment_service.dart';
import 'package:xprex/models/comment_model.dart';
import 'package:xprex/theme.dart';
import 'package:xprex/services/save_service.dart';
import 'package:xprex/services/repost_service.dart';

final feedVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  final videoService = VideoService();
  return await videoService.getForYouFeed(limit: 20);
});

class FeedScreen extends ConsumerStatefulWidget {
  final bool isVisible; // Controls if tab is active

  const FeedScreen({super.key, this.isVisible = true});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> with WidgetsBindingObserver, RouteAware {
  int _activeIndex = 0;
  bool _appActive = true;
  bool _routeVisible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  // --- FIX: React to Tab Changes ---
  @override
  void didUpdateWidget(covariant FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      if (!widget.isVisible) {
        _maybeDisableWakelock();
      }
      // Force rebuild to pause/play based on new isVisible state
      setState(() {}); 
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appActive != active) {
      _appActive = active;
      if (!active) {
        _maybeDisableWakelock();
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _maybeDisableWakelock();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final videosAsync = ref.watch(feedVideosProvider);
    final theme = Theme.of(context);

    // The Logic: Video only plays if Tab is Visible AND App is Active
    final feedVisible = widget.isVisible && _appActive && _routeVisible;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: const Text(
          'XpreX',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
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
            allowImplicitScrolling: true,
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final video = videos[index];
              return VideoFeedItem(
                key: ValueKey(video.id),
                video: video,
                isActive: index == _activeIndex,
                feedVisible: feedVisible, // Passed down correctly
                onLikeToggled: () {
                   ref.invalidate(feedVideosProvider);
                },
              );
            },
            onPageChanged: (i) {
              setState(() => _activeIndex = i);
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

// ... (Rest of VideoFeedItem remains the same, it uses `widget.feedVisible` correctly)
// Note: Ensure you keep the rest of your `VideoFeedItem` class as it was. 
// I only updated the `FeedScreen` class above.
