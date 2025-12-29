import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/services/notification_service.dart'; 
import 'package:xprex/models/video_model.dart';
import 'package:xprex/widgets/feed_item.dart';
import 'package:xprex/router/app_router.dart';
import 'package:xprex/screens/search_screen.dart';
import 'package:xprex/screens/pulse_screen.dart';
import 'package:xprex/providers/auth_provider.dart';

// --- STATE PROVIDERS ---
final feedRefreshKeyProvider = StateProvider<int>((ref) => 0);
final feedScrollSignalProvider = StateProvider<int>((ref) => 0);

// 0 = Following, 1 = For You
final selectedFeedTabProvider = StateProvider<int>((ref) => 1);

// --- FEED VIDEO PROVIDER ---
final feedVideosProvider = FutureProvider<List<VideoModel>>((ref) async {
  ref.watch(authStateProvider); // Re-fetch on auth change
  ref.watch(feedRefreshKeyProvider); // NEW: Re-fetch on manual refresh
  final selectedTab = ref.watch(selectedFeedTabProvider);
  final videoService = VideoService();

  if (selectedTab == 0) {
    // Tab 0: Following Feed
    return await videoService.getFollowingFeed(limit: 20);
  } else {
    // Tab 1: For You Feed
    return await videoService.getForYouFeed(limit: 20);
  }
});

// --- NOTIFICATION COUNT PROVIDER ---
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  ref.watch(authStateProvider); // Re-fetch on auth change
  final service = NotificationService();
  return await service.getUnreadCount();
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
    try { WakelockPlus.disable();
    } catch (_) {}
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    try { WakelockPlus.disable();
    } catch (_) {}
    setState(() => _screenVisible = false);
  }

  @override
  void didPopNext() {
    setState(() => _screenVisible = true);
    // Refresh notification count when returning to feed
    ref.invalidate(unreadNotificationCountProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() => _appActive = state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(unreadNotificationCountProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final videosAsync = ref.watch(feedVideosProvider);
    final refreshKey = ref.watch(feedRefreshKeyProvider);
    final unreadCountAsync = ref.watch(unreadNotificationCountProvider);
    final selectedTab = ref.watch(selectedFeedTabProvider);
    
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
              if (videos.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        selectedTab == 0 
                          ? 'Follow people to see their videos here' 
                          : 'No videos available',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      // BUTTON LOGIC
                      if (selectedTab == 0) ...[
                        OutlinedButton.icon(
                          onPressed: () {
                             // Force refresh by incrementing key
                             ref.read(feedRefreshKeyProvider.notifier).state++;
                          },
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('Refresh', style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => ref.read(selectedFeedTabProvider.notifier).state = 1,
                          child: const Text('Go to For You'),
                        )
                      ] else 
                        OutlinedButton.icon(
                          onPressed: () => ref.read(feedRefreshKeyProvider.notifier).state++,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                    ],
                  )
                );
              }
              
              return PageView.builder(
                controller: _pageController, 
                key: ValueKey('${refreshKey}_$selectedTab'), 
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
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
            error: (e, s) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: $e', style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.read(feedRefreshKeyProvider.notifier).state++, 
                    child: const Text("Retry")
                  )
                ],
              )
            ),
          ),

          // --- TOP BAR ---
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
                  
                  // --- TABS (Following | For You) ---
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

                  // --- NOTIFICATION BELL WITH BADGE ---
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 28),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const PulseScreen())
                          ).then((_) => ref.invalidate(unreadNotificationCountProvider));
                        },
                      ),
                      unreadCountAsync.when(
                        data: (count) {
                          if (count == 0) return const SizedBox.shrink();
                          return Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                count > 9 ? '9+' : '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      )
                    ],
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
    final selectedTab = ref.watch(selectedFeedTabProvider);
    final isSelected = selectedTab == index;
    
    return GestureDetector(
      onTap: () {
        ref.read(selectedFeedTabProvider.notifier).state = index;
        // Reset page controller to top when switching
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      },
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
