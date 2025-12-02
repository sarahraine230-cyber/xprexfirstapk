import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/screens/upload_screen.dart'; // Direct link to creation
import 'package:xprex/screens/monetization_screen.dart'; // Direct link to money

class CreatorHubScreen extends ConsumerStatefulWidget {
  const CreatorHubScreen({super.key});

  @override
  ConsumerState<CreatorHubScreen> createState() => _CreatorHubScreenState();
}

class _CreatorHubScreenState extends ConsumerState<CreatorHubScreen> {
  final _videoService = VideoService();
  bool _isLoading = true;
  
  // Stats
  int _followersCount = 0; // Passed from profile usually, but we fetch fresh
  int _views30d = 0;
  int _totalAudience30d = 0; // Unique approximations
  int _engagedAudience30d = 0;
  List<VideoModel> _recentVideos = [];

  @override
  void initState() {
    super.initState();
    _loadHubData();
  }

  Future<void> _loadHubData() async {
    final userId = ref.read(authServiceProvider).currentUserId;
    final profileService = ref.read(profileServiceProvider);
    
    if (userId == null) return;

    try {
      // 1. Fetch Profile for Follower Count
      final profile = await profileService.getProfileByAuthId(userId);
      
      // 2. Fetch User Videos to calc 30-day stats
      final allVideos = await _videoService.getUserVideos(userId);
      
      // 3. Logic: Filter for last 30 days
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(days: 30));
      
      final recentList = allVideos.where((v) => v.createdAt.isAfter(cutoff)).toList();
      
      // 4. Calculate Stats
      int v30 = 0;
      int engaged = 0;
      
      for (var v in recentList) {
        v30 += v.playbackCount;
        engaged += (v.likesCount + v.commentsCount + v.savesCount + v.repostsCount);
      }

      if (mounted) {
        setState(() {
          _followersCount = profile?.followersCount ?? 0;
          _views30d = v30;
          // For MVP, Total Audience is roughly Total Views + Unique Interactions
          // In a real app, this requires complex SQL distinct counts.
          _totalAudience30d = v30 + (engaged ~/ 2); 
          _engagedAudience30d = engaged;
          _recentVideos = recentList.take(6).toList(); // Top 6 recent
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
      backgroundColor: const Color(0xFFF8F8F8), // Light grey background like Pinterest
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
            // --- TOP ACTIONS ROW ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _HubTopButton(
                  icon: Icons.add, 
                  label: 'Creation', 
                  onTap: () {
                    // Navigate to Upload Tab (Index 2 in MainShell)
                    // We can't easily switch tabs from here without a global key or pop
                    // So we just push the screen directly for now
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UploadScreen()));
                  }
                ),
                _HubTopButton(
                  icon: Icons.notifications_active_outlined, 
                  label: 'Pulse', // "Engagements" -> "Pulse"
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pulse (Notifications) coming soon!'))
                    );
                  }
                ),
                _HubTopButton(
                  icon: Icons.monetization_on_outlined, 
                  label: 'Monetization', 
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MonetizationScreen()));
                  }
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- PERFORMANCE CARD ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: theme.colorScheme.primary,
                        child: const Icon(Icons.bar_chart, size: 14, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text('Performance', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  _StatRow(label: 'Followers (All Time)', value: '$_followersCount'),
                  const SizedBox(height: 16),
                  _StatRow(label: 'Views (30 days)', value: _formatNum(_views30d), trend: true),
                  const SizedBox(height: 16),
                  _StatRow(label: 'Total Audience', value: _formatNum(_totalAudience30d)),
                  const SizedBox(height: 16),
                  _StatRow(label: 'Engaged Audience', value: _formatNum(_engagedAudience30d)),

                  const SizedBox(height: 24),
                  Center(
                    child: FilledButton.tonal(
                      onPressed: () {
                        // TODO: Full Analytics Screen
                      }, 
                      child: const Text('See all analytics'),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- RECENT VIDEOS ---
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent Videos (30 Days)', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),

            if (_recentVideos.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Center(child: Text('No videos in the last 30 days', style: TextStyle(color: Colors.grey))),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(8),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: v.coverImageUrl != null 
                          ? Image.network(v.coverImageUrl!, width: 50, height: 50, fit: BoxFit.cover)
                          : Container(width: 50, height: 50, color: Colors.grey),
                      ),
                      title: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${v.createdAt.day}/${v.createdAt.month} • ${_formatNum(v.playbackCount)} views'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.favorite, size: 16, color: theme.colorScheme.primary),
                          Text('${v.likesCount}', style: const TextStyle(fontSize: 12)),
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

  const _HubTopButton({required this.icon, required this.label, required this.onTap});

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
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Icon(icon, size: 28, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final bool trend;

  const _StatRow({required this.label, required this.value, this.trend = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ],
        ),
        Row(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (trend) ...[
              const SizedBox(width: 4),
              // Fake trend for MVP demo (or calculate if you want)
              // const Icon(Icons.arrow_upward, size: 14, color: Colors.green),
            ]
          ],
        ),
      ],
    );
  }
}
