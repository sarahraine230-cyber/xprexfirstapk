import 'dart:io'; // <--- NEW IMPORT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart'; // <--- NEW IMPORT
import 'package:video_player/video_player.dart'; // <--- NEW IMPORT
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/screens/upload_screen.dart';
import 'package:xprex/screens/monetization_screen.dart';
import 'package:xprex/screens/analytics_screen.dart';
import 'package:xprex/screens/pulse_screen.dart';

class CreatorHubScreen extends ConsumerStatefulWidget {
  const CreatorHubScreen({super.key});

  @override
  ConsumerState<CreatorHubScreen> createState() => _CreatorHubScreenState();
}

class _CreatorHubScreenState extends ConsumerState<CreatorHubScreen> {
  final _videoService = VideoService();
  bool _isLoading = true;
  
  // Real Stats from DB
  int _followersCount = 0;
  int _views30d = 0;
  int _totalAudience30d = 0;
  int _engagedAudience30d = 0;
  List<VideoModel> _recentVideos = [];

  @override
  void initState() {
    super.initState();
    _loadHubData();
  }

  Future<void> _loadHubData() async {
    final userId = ref.read(authServiceProvider).currentUserId;
    if (userId == null) return;
    try {
      // 1. Fetch Real Stats (30 Days)
      final stats = await _videoService.getCreatorStats();
      // 2. Fetch Recent Videos List (Client side filter for display)
      final allVideos = await _videoService.getUserVideos(userId);
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: 30));
      final recentList = allVideos.where((v) => v.createdAt.isAfter(cutoff)).toList();
      if (mounted) {
        setState(() {
          _followersCount = stats['followers'] as int? ?? 0;
          _views30d = stats['views_30d'] as int? ?? 0;
          _totalAudience30d = stats['total_audience'] as int? ?? 0;
          _engagedAudience30d = stats['engaged_audience'] as int? ?? 0;
          
          _recentVideos = recentList.take(6).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading hub: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Creator Hub')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, 
      appBar: AppBar(
        title: const Text('Creator Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- TOP ACTIONS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _HubTopButton(
                  icon: Icons.add, 
                  label: 'Creation', 
                  theme: theme,
                  onTap: () async {
                    // --- UPDATED: THE BOUNCER LOGIC ---
                    
                    // 1. Pick Video
                    final picker = ImagePicker();
                    final XFile? video = await picker.pickVideo(
                      source: ImageSource.gallery,
                      maxDuration: const Duration(seconds: 60),
                    );

                    if (video == null) return; // User cancelled

                    // 2. Validate Duration & Size
                    final file = File(video.path);
                    final controller = VideoPlayerController.file(file);
                    
                    // Show quick loading snackbar
                    if (context.mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Checking video...'), duration: Duration(milliseconds: 500))
                       );
                    }

                    await controller.initialize();
                    final duration = controller.value.duration.inSeconds;
                    final sizeInMb = file.lengthSync() / (1024 * 1024);
                    await controller.dispose();

                    if (duration > 61) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          backgroundColor: Colors.red,
                          content: Text('Video must be under 60 seconds'),
                        ));
                      }
                      return;
                    }
                    
                    if (sizeInMb > 500) {
                       if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File too large')));
                       }
                       return;
                    }

                    // 3. Go to Upload Screen (Now valid!)
                    if (context.mounted) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => UploadScreen(videoFile: file),
                      ));
                    }
                  }
                ),
                _HubTopButton(
                  icon: Icons.notifications_active_outlined, 
                  label: 'Pulse', 
                  theme: theme,
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PulseScreen()));
                  }
                ),
                _HubTopButton(
                  icon: Icons.monetization_on_outlined, 
                  label: 'Monetization', 
                  theme: theme,
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MonetizationScreen()));
                  }
                ),
              ],
            ),

            const SizedBox(height: 32),

            // --- PERFORMANCE CARD ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: theme.colorScheme.primary,
                        child: Icon(Icons.bar_chart, size: 14, color: theme.colorScheme.onPrimary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Performance', 
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  _StatRow(label: 'Followers (All Time)', value: '$_followersCount', theme: theme),
                  const SizedBox(height: 16),
                  _StatRow(label: 'Views (30 days)', value: _formatNum(_views30d), trend: true, theme: theme),
                  const SizedBox(height: 16),
                  _StatRow(label: 'Total Audience', value: _formatNum(_totalAudience30d), theme: theme),
                  const SizedBox(height: 16),
                  _StatRow(label: 'Engaged Audience', value: _formatNum(_engagedAudience30d), theme: theme),

                  const SizedBox(height: 24),
                  Center(
                    child: FilledButton.tonal(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AnalyticsScreen())
                        );
                      }, 
                      child: const Text('See all analytics'),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- RECENT VIDEOS ---
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent Videos (30 Days)', 
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
              ),
            ),
            const SizedBox(height: 16),

            if (_recentVideos.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.videocam_off_outlined, color: theme.colorScheme.onSurfaceVariant, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      'No videos in the last 30 days', 
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _recentVideos.length,
                separatorBuilder: (_,__) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final v = _recentVideos[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface, 
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(8),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: v.coverImageUrl != null 
                          ? Image.network(v.coverImageUrl!, width: 50, height: 50, fit: BoxFit.cover)
                          : Container(width: 50, height: 50, color: theme.colorScheme.surfaceContainerHighest),
                      ),
                      title: Text(
                        v.title, 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis, 
                        style: const TextStyle(fontWeight: FontWeight.bold)
                      ),
                      subtitle: Text(
                        '${v.createdAt.day}/${v.createdAt.month} • ${_formatNum(v.playbackCount)} views',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite, size: 16, color: theme.colorScheme.primary),
                          Text('${v.likesCount}', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _formatNum(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}k';
    return '$num';
  }
}

class _HubTopButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ThemeData theme;

  const _HubTopButton({
    required this.icon, 
    required this.label, 
    required this.onTap, 
    required this.theme
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              // Adaptive Color
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 28, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            label, 
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            )
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool trend;
  final ThemeData theme;

  const _StatRow({
    required this.label, 
    required this.value, 
    this.trend = false, 
    required this.theme
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label, 
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant
              )
            ),
          ],
        ),
        Row(
          children: [
            Text(
              value, 
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface
              )
            ),
            if (trend) ...[
              const SizedBox(width: 4),
              const Icon(Icons.arrow_upward, size: 14, color: Colors.green),
            ]
          ],
        ),
      ],
    );
  }
}
