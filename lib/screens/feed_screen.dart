import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart'; // Import Wakelock
import 'package:xprex/services/video_service.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/widgets/feed_item.dart';
import 'package:xprex/router/app_router.dart';
import 'package:xprex/screens/search_screen.dart';
import 'package:xprex/screens/pulse_screen.dart';
import 'package:xprex/providers/auth_provider.dart';

final feedRefreshKeyProvider = StateProvider<int>((ref) => 0);
final feedScrollSignalProvider = StateProvider<int>((ref) => 0);

// --- THE REACTION CHAMBER ---
final feedVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  ref.watch(authStateProvider);
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
  final PageController _pageController = PageController();
  
  int _activeIndex = 0;
  bool _appActive = true;
  bool _screenVisible = true; 
  int _selectedTab = 1; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    try { WakelockPlus.disable(); } catch (_) {}
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    try { WakelockPlus.disable(); } catch (_) {}
    setState(() => _screenVisible = false);
  }

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
    final refreshKey = ref.watch(feedRefreshKeyProvider);
    final shouldPlay = widget.isVisible && _appActive && _screenVisible;

    ref.listen(feedScrollSignalProvider, (previous, next) {
      if (next > (previous ?? 0) && _pageController.hasClients) {
        if (_activeIndex > 0) {
          _pageController.animateToPage(
            0, 
            duration: const Duration(milliseconds: 500), 
            curve: Curves.easeInOut
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          videosAsync.when(
            data: (videos) {
              if (videos.isEmpty) return const Center(child: Text('No videos yet', style: TextStyle(color: Colors.white)));
              
              return PageView.builder(
                controller: _pageController, 
                key: ValueKey(refreshKey),
                scrollDirection: Axis.vertical,
                allowImplicitScrolling: true, 
                itemCount: videos.length,
                onPageChanged: (i) => setState(() => _activeIndex = i),
                itemBuilder: (context, index) {
                  return VideoFeedItem(
                    key: ValueKey(videos[index].id),
                    video: videos[index],
                    isActive: index == _activeIndex,
                    feedVisible: shouldPlay, 
                    // REMOVED: onLikeToggled - No longer triggering full reload
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
            error: (e, s) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.white))),
          ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 20,
                left: 16,
                right: 16
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white, size: 28),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SearchScreen())
                      );
                    },
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTab("Following", 0),
                      const SizedBox(width: 16),
                      Container(width: 1, height: 12, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(width: 16),
                      _buildTab("For You", 1),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PulseScreen())
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
              fontSize: isSelected ? 17 : 16,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
            ),
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              width: 20,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
              ),
            )
        ],
      ),
    );
  }
}
