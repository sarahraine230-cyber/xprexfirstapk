import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xprex/services/video_service.dart';
import 'package:xprex/models/video_model.dart';
import 'package:xprex/theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _videoService = VideoService();
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  List<VideoModel> _topVideos = [];
  
  // --- STATE: Selected Date Range ---
  int _selectedDays = 30; // Default to 30 days

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    // Pass the selected days to the service
    final result = await _videoService.getAnalyticsDashboard(days: _selectedDays);
    
    List<VideoModel> videos = [];
    if (result['top_videos'] != null) {
      videos = (result['top_videos'] as List)
          .map((json) => VideoModel.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    if (mounted) {
      setState(() {
        _data = result['metrics'];
        _topVideos = videos;
        _isLoading = false;
      });
    }
  }

  // --- FILTER MODAL ---
  void _showFilterModal(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date range', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              _buildFilterOption(theme, 'Last 7 days', 7),
              _buildFilterOption(theme, 'Last 30 days', 30),
              _buildFilterOption(theme, 'Last 90 days', 90),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(ThemeData theme, String label, int days) {
    final isSelected = _selectedDays == days;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 16)),
      trailing: isSelected 
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary) 
          : const Icon(Icons.circle_outlined, color: Colors.grey),
      onTap: () {
        setState(() => _selectedDays = days); // Update state
        Navigator.pop(context); // Close modal
        _loadAnalytics(); // Refresh data
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Date Range Logic
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: _selectedDays));
    final dateFormat = DateFormat('M/d/yy');
    final dateRange = '${dateFormat.format(startDate)} - ${dateFormat.format(now)}';

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analytics')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Safe Data Accessor
    Map<String, dynamic> getMetric(String key) {
      return _data?[key] ?? {'value': 0, 'prev': 0};
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune), 
            onPressed: () => _showFilterModal(theme),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // --- HEADER ---
            Text('Last $_selectedDays days', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(dateRange, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            
            const SizedBox(height: 32),

            // --- OVERALL PERFORMANCE ---
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Overall performance', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),

            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  _AnalyticsRow(
                    label: 'Video Views', 
                    data: getMetric('views'), 
                    theme: theme, 
                    isFirst: true
                  ),
                  _AnalyticsRow(
                    label: 'Engagements', 
                    data: getMetric('engagements'), 
                    theme: theme
                  ),
                  _AnalyticsRow(
                    label: 'Saves', 
                    data: getMetric('saves'), 
                    theme: theme
                  ),
                  _AnalyticsRow(
                    label: 'Reposts', 
                    data: getMetric('reposts'), 
                    theme: theme
                  ),
                  _AnalyticsRow(
                    label: 'New Followers', 
                    data: getMetric('followers'), 
                    theme: theme
                  ),
                  _AnalyticsRow(
                    label: 'Engaged Audience', 
                    data: getMetric('engaged_audience'), 
                    theme: theme, 
                    isLast: true
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'Percent changes are compared to $_selectedDays days before the date range above.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // --- TOP VIDEOS ---
            Align(
              alignment: Alignment.center,
              child: Column(
                children: [
                  Text('Top Videos', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Sorted by views', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_topVideos.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text('No videos data yet', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _topVideos.length,
                separatorBuilder: (_,__) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final v = _topVideos[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: v.coverImageUrl != null 
                        ? Image.network(v.coverImageUrl!, width: 50, height: 50, fit: BoxFit.cover)
                        : Container(width: 50, height: 50, color: theme.colorScheme.surfaceContainerHighest),
                    ),
                    title: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${v.createdAt.day}/${v.createdAt.month} • ${_formatNum(v.playbackCount)} views'),
                    trailing: const Icon(Icons.chevron_right),
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

// --- SMART ROW WITH TREND INDICATOR ---
class _AnalyticsRow extends StatelessWidget {
  final String label;
  final Map<String, dynamic> data;
  final ThemeData theme;
  final bool isFirst;
  final bool isLast;

  const _AnalyticsRow({
    required this.label, 
    required this.data, 
    required this.theme,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final int value = data['value'] ?? 0;
    final int prev = data['prev'] ?? 0;
    
    // 1. Calculate Math
    double percentChange = 0;
    if (prev > 0) {
      percentChange = ((value - prev) / prev) * 100;
    } else if (value > 0) {
      percentChange = 100; // Growth from zero
    }

    // 2. Determine Logic (Color, Text, Icon)
    Color changeColor = theme.colorScheme.onSurfaceVariant; // Default Grey
    String changeText = '0%';
    IconData? changeIcon;
    
    if (percentChange > 0) {
      // GROWTH: Green
      changeColor = Colors.green.shade600; 
      changeText = '${percentChange.abs().toStringAsFixed(0)}%';
      changeIcon = Icons.arrow_upward;
    } else if (percentChange < 0) {
      // DECLINE: Red
      changeColor = theme.colorScheme.error;
      changeText = '${percentChange.abs().toStringAsFixed(0)}%';
      changeIcon = Icons.arrow_downward;
    } else {
      // NEUTRAL: Grey/Hyphen
      changeText = '-';
    }

    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.1))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          // Label
          Expanded(
            flex: 4,
            child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          
          // Trend Indicator (Center)
          Expanded(
            flex: 2,
            child: percentChange != 0 
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      changeText, 
                      style: TextStyle(color: changeColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 2),
                    Icon(changeIcon, size: 12, color: changeColor),
                  ],
                )
              : Center(child: Text('-', style: TextStyle(color: theme.colorScheme.onSurfaceVariant))),
          ),

          // Value (Right)
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(width: 12),
                Text(
                  _formatNum(value), 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNum(int num) {
    if (num >= 1000000) return '${(num / 1000000).toStringAsFixed(1)}M';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)}k';
    return '$num';
  }
}
