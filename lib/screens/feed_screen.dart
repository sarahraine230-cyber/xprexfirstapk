import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/widgets/feed_item.dart';
// IMPORT THE ROUTER TO GET THE OBSERVER
import 'package:xprex/router/app_router.dart'; 

final feedVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  final videoService = VideoService();
  return await videoService.getForYouFeed(limit: 20);
});

class FeedScreen extends ConsumerStatefulWidget {
  final bool isVisible;
  const FeedScreen({super.key, this.isVisible = true});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> with WidgetsBindingObserver, RouteAware {
  int _activeIndex = 0;
  bool _appActive = true;
  bool _screenVisible = true; // True by default

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  // --- CONNECT TO TRAFFIC CONTROLLER ---
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to the global observer
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this); // Unsubscribe
    super.dispose();
  }

  // Called when a new screen (Upload) covers this one
  @override
  void didPushNext() {
    setState(() => _screenVisible = false);
  }

  // Called when the top screen (Upload) is popped off
  @override
  void didPopNext() {
    setState(() => _screenVisible = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _appActive = state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(feedVideosProvider);
    
    // PLAY ONLY IF: Tab Selected AND App Active AND No Screen Covering Us
    final shouldPlay = widget.isVisible && _appActive && _screenVisible;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('XpreX', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: videosAsync.when(
        data: (videos) {
          if (videos.isEmpty) return const Center(child: Text('No videos yet', style: TextStyle(color: Colors.white)));
          return PageView.builder(
            scrollDirection: Axis.vertical,
            // CRITICAL: Disable implicit scrolling to save resources for Upload Screen
            allowImplicitScrolling: false, 
            itemCount: videos.length,
            onPageChanged: (i) => setState(() => _activeIndex = i),
            itemBuilder: (context, index) {
              return VideoFeedItem(
                key: ValueKey(videos[index].id),
                video: videos[index],
                isActive: index == _activeIndex,
                feedVisible: shouldPlay, // Pass strict logic down
                onLikeToggled: () => ref.invalidate(feedVideosProvider),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
      ),
    );
  }
}
