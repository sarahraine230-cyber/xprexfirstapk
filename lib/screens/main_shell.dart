import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
// FIXED IMPORTS (Flat Structure)
import 'package:xprex/screens/feed_screen.dart';
import 'package:xprex/screens/profile_screen.dart';
import 'package:xprex/screens/upload_screen.dart';
import 'package:xprex/services/auth_service.dart';

// Global key to control navigation from anywhere
final GlobalKey<_MainShellState> mainShellKey = GlobalKey<_MainShellState>();

// Helper to switch tabs globally
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

  // Only Home and Profile are actual tabs now. 
  // We use SizedBox.shrink() for the middle tab because we handle the tap manually.
  static const List<Widget> _tabOptions = <Widget>[
    FeedScreen(),
    SizedBox.shrink(), // Placeholder for Index 1 (Upload)
    ProfileScreen(),
  ];

  void setIndex(int index) {
    if (index == 1) return; // Don't allow programmatically setting to the placeholder
    setState(() {
      _selectedIndex = index;
    });
  }

  // --- THE BOUNCER LOGIC ---
  Future<void> _handleUploadTap() async {
    // 1. Check Auth
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to upload')));
      return;
    }

    // 2. Pick Video (Soft limit)
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );

    if (video == null) return; // User cancelled

    // 3. Strict Checks (Duration & Size)
    final file = File(video.path);
    VideoPlayerController? controller;
    
    // Show a loading indicator while we check the file
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checking video...'), duration: Duration(milliseconds: 500))
      );
    }

    try {
      controller = VideoPlayerController.file(file);
      await controller.initialize();
      final duration = controller.value.duration.inSeconds;
      final sizeInMb = file.lengthSync() / (1024 * 1024);
      await controller.dispose(); // Done checking

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

      // 4. SUCCESS! Navigate to Metadata Screen with the file
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
    if (index == 1) {
      // If "+" is tapped, run the action, don't switch tabs
      _handleUploadTap();
    } else {
      // Otherwise switch tabs normally
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
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: isDark ? Colors.black : Colors.white,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined, size: 28),
            activeIcon: Icon(Icons.home, size: 28),
            label: 'Home',
          ),
          // THE UPLOAD ACTION BUTTON
          BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, color: isDark ? Colors.black : Colors.white, size: 28),
            ),
            label: 'Upload',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline, size: 28),
            activeIcon: Icon(Icons.person, size: 28),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
