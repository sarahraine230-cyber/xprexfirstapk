import 'package:flutter/material.dart';
import 'package:xprex/screens/feed_screen.dart';
import 'package:xprex/screens/upload_screen.dart';
import 'package:xprex/screens/profile_screen.dart';

// Global key + helper to allow other screens to switch tabs (e.g., after upload)
final GlobalKey<_MainShellState> mainShellKey = GlobalKey<_MainShellState>();
void setMainTabIndex(int index) => mainShellKey.currentState?.setIndex(index);

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // Keep stable keys so state is preserved across tab switches
  final _feedKey = const PageStorageKey('feed');
  final _uploadKey = const PageStorageKey('upload');
  final _profileKey = const PageStorageKey('profile');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Pass visibility flag so FeedScreen can pause when hidden
          FeedScreen(key: _feedKey, isVisible: _currentIndex == 0),
          UploadScreen(key: _uploadKey),
          ProfileScreen(key: _profileKey),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurfaceVariant,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Upload'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  void setIndex(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }
}
