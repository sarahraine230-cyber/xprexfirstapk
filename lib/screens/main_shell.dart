import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xprex/screens/feed_screen.dart';
import 'package:xprex/screens/search_screen.dart';
import 'package:xprex/screens/upload_screen.dart';
import 'package:xprex/screens/profile_screen.dart';
import 'package:xprex/providers/upload_provider.dart'; // IMPORT PROVIDER

final GlobalKey<_MainShellState> mainShellKey = GlobalKey<_MainShellState>();
void setMainTabIndex(int index) => mainShellKey.currentState?.setIndex(index);

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;
  
  Key _feedKey = const PageStorageKey('feed');
  final _searchKey = const PageStorageKey('search');
  final _uploadKey = const PageStorageKey('upload');
  final _profileKey = const PageStorageKey('profile');

  void _onItemTapped(int index) {
    if (index == 0 && _currentIndex == 0) {
      setState(() {
        _feedKey = UniqueKey();
      });
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Stack(
        children: [
          // 1. The Main Content
          IndexedStack(
            index: _currentIndex,
            children: [
              FeedScreen(key: _feedKey, isVisible: _currentIndex == 0),
              SearchScreen(key: _searchKey),
              UploadScreen(key: _uploadKey),
              ProfileScreen(key: _profileKey),
            ],
          ),
          
          // 2. The Global Upload Progress Overlay
          const _UploadStatusOverlay(),
        ],
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurfaceVariant,
        backgroundColor: Colors.black,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Discover'),
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

class _UploadStatusOverlay extends ConsumerWidget {
  const _UploadStatusOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(uploadProvider);

    // If not uploading and no error, hide
    if (!uploadState.isUploading && uploadState.errorMessage == null) {
      return const SizedBox.shrink();
    }

    // If Error, show SnackBar-like error (you might want a proper snackbar, but this works globally)
    if (uploadState.errorMessage != null) {
      // In a real app, use a Toast or showDialog. 
      // For now, we rely on the console log or transient UI. 
      // Returning empty because the provider resets 'isUploading' on error, 
      // but keeps 'errorMessage' if we wanted to show it.
      // Let's hide it to prevent blocking UI, user will retry.
      return const SizedBox.shrink();
    }

    // Show Progress Bar
    return Positioned(
      bottom: 0, 
      left: 0, 
      right: 0,
      child: Container(
        color: Colors.grey[900],
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: 40, 
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: uploadState.progress, 
                    color: Colors.cyanAccent, 
                    strokeWidth: 3,
                    backgroundColor: Colors.white24,
                  ),
                  const Icon(Icons.upload, color: Colors.white, size: 20),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uploadState.status,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${(uploadState.progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
