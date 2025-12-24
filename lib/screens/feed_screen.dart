import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/widgets/feed_item.dart';

// 1. Define a global RouteObserver (You should ideally register this in MaterialApp)
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

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
  bool _screenVisible = true; // Tracks if covered by another screen (like Upload)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to the RouteObserver to know when we are covered
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
       // Ideally we subscribe here, but without main.dart access, we'll rely on isVisible
       // If you added routeObserver to main.dart, uncomment below:
       // routeObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    // Called when a new screen (Upload) is pushed on top
    setState(() => _screenVisible = false);
  }

  @override
  void didPopNext() {
    // Called when the top screen (Upload) is popped, revealing us again
    setState(() => _screenVisible = true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _appActive = state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(feedVideosProvider);
    
    // LOGIC: Play ONLY if Tab is selected + App is active + Not covered by Upload screen
    // Note: Since we haven't wired up routeObserver in main.dart yet, 
    // we assume _screenVisible is true, but rely on 'isVisible' from MainShell.
    // MainShell doesn't change index when pushing Upload, so we rely on lifecycle mostly.
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
            allowImplicitScrolling: false, // Set to FALSE to save resources
            itemCount: videos.length,
            onPageChanged: (i) => setState(() => _activeIndex = i),
            itemBuilder: (context, index) {
              return VideoFeedItem(
                key: ValueKey(videos[index].id),
                video: videos[index],
                isActive: index == _activeIndex,
                feedVisible: shouldPlay, // Pass the strict logic down
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
