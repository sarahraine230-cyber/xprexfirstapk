import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:xprex/screens/feed_screen.dart';
import 'package:xprex/screens/search_screen.dart'; // Ensure this exists
import 'package:xprex/screens/profile_screen.dart';
import 'package:xprex/screens/upload_screen.dart';
import 'package:xprex/services/auth_service.dart';
import 'package:xprex/providers/upload_provider.dart'; // Needed for overlay

final GlobalKey<_MainShellState> mainShellKey = GlobalKey<_MainShellState>();

void setMainTabIndex(int index) {
  mainShellKey.currentState?.setIndex(index);
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;
  final _authService = AuthService();
  final _picker = ImagePicker();

  void setIndex(int index) {
    if (index == 2) return; // Don't navigate to the placeholder upload tab
    setState(() {
      _selectedIndex = index;
    });
  }

  // --- THE BOUNCER LOGIC ---
  Future<void> _handleUploadTap() async {
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to upload')));
      return;
    }

    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );

    if (video == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checking video...'), duration: Duration(milliseconds: 500))
      );
    }

    final file = File(video.path);
    VideoPlayerController? controller;

    try {
      controller = VideoPlayerController.file(file);
      await controller.initialize();
      final duration = controller.value.duration.inSeconds;
      final sizeInMb = file.lengthSync() / (1024 * 1024);
      await controller.dispose();

      if (duration > 61) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: Colors.red,
              content: Text('Video is ${duration}s. Max 60s allowed.'),
              duration: const Duration(seconds: 4)));
        }
        return;
      }
      if (sizeInMb > 500) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('File too large (>500MB)')));
         }
        return;
      }

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UploadScreen(videoFile: file),
          ),
        );
      }

    } catch (e) {
      debugPrint("Error checking video: $e");
      await controller?.dispose();
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Error reading video file')));
      }
    }
  }

  void _onItemTapped(int index) {
    if (index == 2) {
      _handleUploadTap();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: mainShellKey,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: [
              // Tab 0: Feed (Is Active ONLY if index is 0)
              FeedScreen(isVisible: _selectedIndex == 0),
              
              // Tab 1: Discover
              const SearchScreen(),
              
              // Tab 2: Placeholder for Upload (never shown)
              const SizedBox.shrink(),
              
              // Tab 3: Profile
              const ProfileScreen(),
            ],
          ),
          
          // The Upload Progress Overlay
          const _UploadStatusOverlay(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: Colors.black, // Force Black for that Premium look
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Discover',
          ),
          // THE CUSTOM UPLOAD BUTTON
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add, color: Colors.black, size: 20),
            ),
            label: '',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _UploadStatusOverlay extends ConsumerWidget {
  const _UploadStatusOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(uploadProvider);
    
    if (!uploadState.isUploading && uploadState.errorMessage == null) {
      return const SizedBox.shrink();
    }

    if (uploadState.errorMessage != null) {
      return const SizedBox.shrink(); // Errors handled by SnackBar usually
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16, 
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)],
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(
                value: uploadState.progress, 
                color: Colors.cyanAccent, 
                strokeWidth: 3,
                backgroundColor: Colors.white24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "${uploadState.status} ${(uploadState.progress * 100).toStringAsFixed(0)}%",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
