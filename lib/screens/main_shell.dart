import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xprex/screens/feed_screen.dart';
import 'package:xprex/screens/search_screen.dart'; // Import the new Search Screen
import 'package:xprex/screens/upload_screen.dart';
import 'package:xprex/screens/profile_screen.dart';

// Global key + helper to allow other screens to switch tabs (e.g., after upload)
final GlobalKey<_MainShellState> mainShellKey = GlobalKey<_MainShellState>();
void setMainTabIndex(int index) => mainShellKey.currentState?.setIndex(index);

// UPDATED: Changed to ConsumerStatefulWidget to access 'ref' for refreshing
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  
  // Keep stable keys so state is preserved across tab switches
  final _feedKey = const PageStorageKey('feed');
  final _searchKey = const PageStorageKey('search'); // New Key
  final _uploadKey = const PageStorageKey('upload');
  final _profileKey = const PageStorageKey('profile');

  // Logic to handle navigation taps
  void _onItemTapped(int index) {
    // 1. TAP-TO-REFRESH LOGIC
    // If tapping "Feed" (index 0) while already ON "Feed"...
    if (index == 0 && _currentIndex == 0) {
      debugPrint('🔄 Tap-to-Refresh triggered');
      // Invalidate the provider to force a reload from the "Brain" algorithm
      ref.invalidate(feedVideosProvider);
      return; 
    }

    // 2. Normal Navigation
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Index 0: Feed
          FeedScreen(key: _feedKey, isVisible: _currentIndex == 0),
          
          // Index 1: Search (New)
          SearchScreen(key: _searchKey),
          
          // Index 2: Upload
          UploadScreen(key: _uploadKey),
          
          // Index 3: Profile
          ProfileScreen(key: _profileKey),
        ],
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped, // Use our smart handler
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurfaceVariant,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home), 
            label: 'Feed'
          ),
          // New Search Button
          BottomNavigationBarItem(
            icon: Icon(Icons.search), 
            label: 'Discover'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline), 
            label: 'Upload'
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person), 
            label: 'Profile'
          ),
        ],
      ),
    );
  }

  void setIndex(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }
}
