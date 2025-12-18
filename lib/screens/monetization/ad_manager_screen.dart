import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';

// --- PROVIDERS ---

// 1. Fetch Ad Wallet Balance & History
final adWalletProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final authService = ref.watch(authServiceProvider);
  final userId = authService.currentUserId;
  if (userId == null) return Stream.value({'balance': 0, 'history': []});

  // Listen to profile changes for balance
  final profileStream = Supabase.instance.client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('auth_user_id', userId)
      .map((event) => event.isNotEmpty ? event.first['ad_credits'] : 0);

  return profileStream.map((balance) => {'balance': balance});
});

// 2. Fetch User's Videos (For the Picker)
final myVideosProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final userId = authService.currentUserId;
  if (userId == null) return [];

  final response = await Supabase.instance.client
      .from('videos')
      .select('id, title, thumbnail_url, created_at')
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(10); // Show last 10 videos

  return List<Map<String, dynamic>>.from(response);
});

// 3. Fetch Active Campaigns
final activeCampaignsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final userId = authService.currentUserId;
  if (userId == null) return [];

  final response = await Supabase.instance.client
      .from('ad_campaigns')
      .select('*, videos(title)')
      .eq('user_id', userId)
      .neq('status', 'Completed') // Show Pending & Active
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response);
});


class AdManagerScreen extends ConsumerStatefulWidget {
  const AdManagerScreen({super.key});

  @override
  ConsumerState<AdManagerScreen> createState() => _AdManagerScreenState();
}

class _AdManagerScreenState extends ConsumerState<AdManagerScreen> {
  bool _isPurchasing = false;

  void _showVideoPicker(BuildContext context, int balance) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => _VideoPickerSheet(
        balance: balance,
        onPurchase: (videoId, plan, cost, reach) => _executePurchase(videoId, plan, cost, reach),
      ),
    );
  }

  Future<void> _executePurchase(String videoId, String planName, int cost, int reach) async {
    Navigator.pop(context); // Close sheet
    setState(() => _isPurchasing = true);

    try {
      final res = await Supabase.instance.client.rpc('purchase_ad_campaign', params: {
        'p_video_id': videoId,
        'p_package_name': planName,
        'p_cost': cost,
        'p_target_reach': reach,
      });

      if (res['status'] == 'success') {
        ref.invalidate(adWalletProvider); // Refresh balance
        ref.invalidate(activeCampaignsProvider); // Refresh list
        if (mounted) {
           _showSuccessDialog(planName);
        }
      } else {
        throw res['message'];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Purchase failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  void _showSuccessDialog(String plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.rocket_launch, size: 48, color: Colors.orangeAccent),
        title: const Text('Boost Activated!'),
        content: Text('Your "$plan" package is being processed. You should see increased reach within 24 hours.'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Awesome'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final walletAsync = ref.watch(adWalletProvider);
    final campaignsAsync = ref.watch(activeCampaignsProvider);

    // Default to 0 if loading
    final int balance = walletAsync.value?['balance'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ad Manager'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. HERO BALANCE CARD ---
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available Credits', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(
                    '₦${NumberFormat('#,###').format(balance)}',
                    style: theme.textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isPurchasing ? null : () => _showVideoPicker(context, balance),
                      icon: _isPurchasing 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.bolt, color: Colors.black),
                      label: Text(_isPurchasing ? 'Processing...' : 'PROMOTE A VIDEO'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- 2. ACTIVE CAMPAIGNS ---
            Text('Active Campaigns', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            campaignsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox(),
              data: (campaigns) {
                if (campaigns.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Text("No active boosts. Start one above!", style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ),
                  );
                }
                return Column(
                  children: campaigns.map((c) => _buildCampaignTile(theme, c)).toList(),
                );
              },
            ),

            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

             // --- 3. THE "MENU" (Preview) ---
            Text('Available Packages', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Purchase reach using your credits.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            _buildPackagePreview(theme, 'Spark', '₦500', '~500 Reach', Colors.blue),
            _buildPackagePreview(theme, 'Amplify', '₦2,000', '~2,500 Reach', Colors.purple),
            _buildPackagePreview(theme, 'Velocity', '₦7,500', '~10k+ Reach', Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignTile(ThemeData theme, Map<String, dynamic> campaign) {
    final videoTitle = campaign['videos'] != null ? campaign['videos']['title'] : 'Unknown Video';
    final plan = campaign['package_name'];
    final status = campaign['status'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.rocket, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(videoTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                Text('$plan Package', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'Active' ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                fontSize: 10, 
                fontWeight: FontWeight.bold,
                color: status == 'Active' ? Colors.green : Colors.orange
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackagePreview(ThemeData theme, String title, String price, String reach, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(width: 4, height: 40, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Text(reach, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(price, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// --- THE BOTTOM SHEET PICKER ---
class _VideoPickerSheet extends ConsumerStatefulWidget {
  final int balance;
  final Function(String, String, int, int) onPurchase;

  const _VideoPickerSheet({required this.balance, required this.onPurchase});

  @override
  ConsumerState<_VideoPickerSheet> createState() => _VideoPickerSheetState();
}

class _VideoPickerSheetState extends ConsumerState<_VideoPickerSheet> {
  String? _selectedVideoId;

  final List<Map<String, dynamic>> _packages = [
    {'name': 'Spark', 'cost': 500, 'reach': 500, 'color': Colors.blue},
    {'name': 'Amplify', 'cost': 2000, 'reach': 2500, 'color': Colors.purple},
    {'name': 'Velocity', 'cost': 7500, 'reach': 10000, 'color': Colors.orange},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final videosAsync = ref.watch(myVideosProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select Video to Boost', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 20),
          
          // 1. VIDEO LIST
          Expanded(
            child: videosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (videos) {
                if (videos.isEmpty) return const Center(child: Text("No videos found. Upload one first!"));
                
                return ListView.builder(
                  itemCount: videos.length,
                  itemBuilder: (ctx, i) {
                    final v = videos[i];
                    final isSelected = _selectedVideoId == v['id'];
                    return ListTile(
                      onTap: () => setState(() => _selectedVideoId = v['id']),
                      leading: Container(
                        width: 50, height: 50,
                        color: Colors.grey[900],
                        child: v['thumbnail_url'] != null 
                          ? Image.network(v['thumbnail_url'], fit: BoxFit.cover) 
                          : const Icon(Icons.videocam),
                      ),
                      title: Text(v['title'], maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: isSelected 
                        ? Icon(Icons.check_circle, color: theme.colorScheme.primary) 
                        : Icon(Icons.circle_outlined, color: theme.colorScheme.outline),
                      selected: isSelected,
                    );
                  },
                );
              },
            ),
          ),
          
          const Divider(),
          const SizedBox(height: 10),

          // 2. PACKAGE LIST (Only show if video selected)
          if (_selectedVideoId != null) ...[
            Text('Select Plan', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _packages.length,
                separatorBuilder: (_,__) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) {
                  final p = _packages[i];
                  final cost = p['cost'] as int;
                  final canAfford = widget.balance >= cost;
                  
                  return InkWell(
                    onTap: canAfford ? () => widget.onPurchase(_selectedVideoId!, p['name'], cost, p['reach']) : null,
                    child: Opacity(
                      opacity: canAfford ? 1.0 : 0.5,
                      child: Container(
                        width: 140,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (p['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: p['color'], width: 2),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(p['name'], style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            Text('~${p['reach']} Reach', style: theme.textTheme.bodySmall),
                            const SizedBox(height: 8),
                            Text('₦$cost', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Select a video to see plans"))),
        ],
      ),
    );
  }
}
