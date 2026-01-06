import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';
import 'package:intl/intl.dart'; 

// ==============================================================================
// 🔴 LIVE MODE CONFIGURATION
// ==============================================================================
// TODO: Replace these with your OFFICIAL keys from the Paystack Dashboard.
const String kPaystackPublicKey = 'pk_live_def13cfe9e8f0c39607a4e758c2338aeb37a8e0f'; 
const String kPaystackPlanCode  = 'PLN_w8gfaqx90iwy3yt'; 
// ==============================================================================

// --- 1. PROFILE STREAM (Wallet Balance & Status) ---
final monetizationProfileProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final authService = ref.watch(authServiceProvider);
  final userId = authService.currentUserId;
  
  if (userId == null) return Stream.value({});

  return Supabase.instance.client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('auth_user_id', userId)
      .map((event) => event.isNotEmpty ? event.first : {});
});

// --- 2. CUMULATIVE EARNINGS FETCHER ---
final earningsBreakdownProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, period) async {
  final authService = ref.watch(authServiceProvider);
  final userId = authService.currentUserId;
  if (userId == null) return [];

  DateTime startDate;
  DateTime endDate;
  try {
    startDate = DateFormat('MMM yyyy').parse(period);
    endDate = DateTime(startDate.year, startDate.month + 1, 0, 23, 59, 59);
  } catch (e) {
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, 1);
    endDate = DateTime(now.year, now.month + 1, 0);
  }

  final earningsResponse = await Supabase.instance.client
      .from('daily_creator_earnings')
      .select('video_breakdown, date, amount_earned, seconds_watched') 
      .eq('user_id', userId)
      .gte('date', startDate.toIso8601String())
      .lte('date', endDate.toIso8601String());

  if (earningsResponse.isEmpty) return [];

  final Map<String, double> videoTotals = {};
  final Map<String, String> videoDates = {};  

  for (final record in earningsResponse) {
    final double dayEarnings = (record['amount_earned'] ?? 0).toDouble();
    final int daySeconds = (record['seconds_watched'] ?? 0).toInt();
    final List<dynamic> breakdown = record['video_breakdown'] ?? [];
    final recordDate = record['date'];
    
    double impliedRate = 0.0;
    if (daySeconds > 0) {
      impliedRate = dayEarnings / daySeconds;
    }

    for (final item in breakdown) {
      final vidId = item['video_id'];
      final int sec = (item['sec'] ?? 0).toInt(); 
      final double videoMoney = sec * impliedRate;
      if (vidId != null) {
        videoTotals[vidId] = (videoTotals[vidId] ?? 0.0) + videoMoney;
        videoDates[vidId] = recordDate; 
      }
    }
  }

  if (videoTotals.isEmpty) return [];

  final videoIds = videoTotals.keys.toList();
  final videosResponse = await Supabase.instance.client
      .from('videos')
      .select('id, title, created_at')
      .filter('id', 'in', videoIds);
      
  return videoIds.map((vidId) {
    final vidDetails = videosResponse.firstWhere(
      (v) => v['id'] == vidId,
      orElse: () => {'title': 'Unknown Video', 'created_at': DateTime.now().toIso8601String()},
    );

    return {
      'title': vidDetails['title'],
      'date': videoDates[vidId],
      'amount': videoTotals[vidId] ?? 0.0,
    };
  }).toList();
});

// --- 3. PAYOUT HISTORY FETCHER ---
final payoutHistoryProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final userId = authService.currentUserId;
  if (userId == null) return [];

  final response = await Supabase.instance.client
      .from('payouts')
      .select('*')
      .eq('user_id', userId)
      .order('period', ascending: false) 
      .limit(3); 

  return List<Map<String, dynamic>>.from(response);
});

class MonetizationScreen extends ConsumerStatefulWidget {
  const MonetizationScreen({super.key});

  @override
  ConsumerState<MonetizationScreen> createState() => _MonetizationScreenState();
}

class _MonetizationScreenState extends ConsumerState<MonetizationScreen> {
  // [PROTOCOL UPDATE] Using the Live Keys defined at the top
  late String _selectedPeriod;
  
  @override
  void initState() {
    super.initState();
    // Automatically set to Current Month (e.g., "Jan 2026")
    _selectedPeriod = DateFormat('MMM yyyy').format(DateTime.now());
  }
  
  List<String> get _periods {
    final now = DateTime.now();
    return [
      DateFormat('MMM yyyy').format(now),
      DateFormat('MMM yyyy').format(DateTime(now.year, now.month - 1)),
      DateFormat('MMM yyyy').format(DateTime(now.year, now.month - 2)),
    ];
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $urlString')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(monetizationProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: profileAsync.when(
          data: (data) => Text(
            (data['is_premium'] == true) ? 'Revenue Studio' : 'Premium',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Revenue Studio'),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (profileData) {
          if (profileData.isEmpty) return const Center(child: Text("Profile not found"));

          // [UPDATED] Check Subscription Expiry here too (Optional visual check)
          // The UserProfile model is the true "Bouncer", but we can check raw data here.
          final isPremium = profileData['is_premium'] == true;
          
          if (isPremium) {
            return _buildProfessionalDashboard(theme, profileData);
          } else {
            return _buildSalesPage(theme);
          }
        },
      ),
    );
  }

  // ===========================================================================
  // 1. PROFESSIONAL DASHBOARD
  // ===========================================================================
  Widget _buildProfessionalDashboard(ThemeData theme, Map<String, dynamic> profileData) {
    // We check specific verification status for more granular UI
    final monetizationStatus = profileData['monetization_status'] ?? 'locked'; 
    final isVerified = profileData['is_verified'] == true;
    
    final breakdownAsync = ref.watch(earningsBreakdownProvider(_selectedPeriod));
    final payoutAsync = ref.watch(payoutHistoryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 1. STATUS CARD ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Partner Status', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.circle, 
                          size: 10, 
                          color: isVerified ? Colors.green : Colors.amber
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isVerified 
                              ? 'Active & Enrolled' 
                              : (monetizationStatus == 'pending' ? 'Under Review' : 'Verification Pending'),
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                if (!isVerified)
                  TextButton(
                    onPressed: () => context.push('/verify'),
                    child: Text(monetizationStatus == 'pending' ? 'Check Status' : 'Complete Setup'),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),

          // --- 2. TOOLS SECTION ---
          _buildSettingsTile(
            theme, 
            title: 'Payout settings', 
            subtitle: isVerified ? 'Bank account connected' : 'Connect bank account',
            icon: Icons.account_balance,
            onTap: () => context.push('/setup/bank'),
          ),
          
          _buildQuickLinksAccordion(theme),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // --- 3. OVERVIEW & FILTERS ---
          Text('Overview', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'This page displays cumulative earnings for the selected month.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Month Filter Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(50),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedPeriod,
                items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPeriod = val);
                },
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                icon: const Icon(Icons.keyboard_arrow_down),
                isDense: true,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Earnings Summary
          Text('Earnings summary', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            '$_selectedPeriod (Month to Date)', 
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)
          ),
          const SizedBox(height: 16),
          
          breakdownAsync.when(
            loading: () => const SizedBox(),
            error: (_,__) => const SizedBox(),
            data: (items) {
               // Calculate Cumulative Total for the month
               final monthTotal = items.fold(0.0, (sum, item) => sum + (item['amount'] as double));
               return Column(
                 children: [
                   Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Video earnings', style: theme.textTheme.bodyLarge),
                        Text('₦${monthTotal.toStringAsFixed(2)}', style: theme.textTheme.bodyLarge),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total earnings', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text('₦${monthTotal.toStringAsFixed(2)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                 ],
               );
            }
          ),

          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'We’ll typically send payouts by the 5th business day of the following month. Earnings are non-binding.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),

          // --- 4. EARNINGS BY VIDEO ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Earnings by video', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  context.push('/monetization/video-earnings', extra: _selectedPeriod);
                },
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$_selectedPeriod (UTC)', 
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)
          ),
          const SizedBox(height: 16),

          breakdownAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            error: (err, _) => Text('Could not load details: $err'),
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    "No earnings recorded yet for this period.",
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                );
              }
              items.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
              return Column(
                children: items.take(5).map((item) {
                  final date = DateTime.tryParse(item['date'].toString());
                  final dateStr = date != null ? DateFormat('MMM d').format(date) : '';
                  final amount = double.tryParse(item['amount'].toString()) ?? 0.0;
                  
                  return _buildVideoEarningRow(
                    theme, 
                    item['title'] ?? 'Untitled Video', 
                    '₦${amount.toStringAsFixed(2)}', 
                    'Last earned: $dateStr'
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

           // --- 5. PAYOUT HISTORY ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payout History', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  context.push('/monetization/payout-history');
                }, 
                child: const Text('View all')
              ),
            ],
          ),
          const SizedBox(height: 8),

          payoutAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()),
            error: (err, _) => Text('Error loading payouts'),
            data: (payouts) {
              if (payouts.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 32, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text(
                        "You haven't received any payouts yet.",
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: payouts.map((payout) {
                  final date = DateTime.tryParse(payout['period'].toString());
                  final dateLabel = date != null ? DateFormat('MMM yyyy').format(date) : payout['period'].toString();
                  final amount = double.tryParse(payout['amount'].toString()) ?? 0.0;
                  final status = payout['status'].toString();

                  return _buildPayoutRow(theme, dateLabel, "₦${amount.toStringAsFixed(2)}", status);
                }).toList(),
              );
            },
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildSettingsTile(ThemeData theme, {required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: theme.colorScheme.onSurface),
      ),
      title: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      trailing: Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildQuickLinksAccordion(ThemeData theme) {
    return Container(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(left: 16, bottom: 8), 
          shape: const Border(), 
          collapsedShape: const Border(), 
          
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.link, color: theme.colorScheme.onSurface),
          ),
          title: Text(
            'Quick links', 
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)
          ),
          subtitle: Text(
            'The Partner Playbook, Support, FAQs', 
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)
          ),
          
          children: [
            _buildLinkItem(theme, 'The Partner Playbook', 'https://creators.getxprex.com/playbook'),
            _buildLinkItem(theme, 'Quality Guidelines', 'https://creators.getxprex.com/guidelines'),
            _buildLinkItem(theme, 'Earnings FAQ', 'https://creators.getxprex.com/faq'),
            _buildLinkItem(theme, 'Leave Partner Program', 'https://creators.getxprex.com/contact', isDestructive: true),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkItem(ThemeData theme, String text, String url, {bool isDestructive = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(
        text, 
        style: theme.textTheme.bodyLarge?.copyWith(
          color: isDestructive ? theme.colorScheme.error : theme.colorScheme.primary,
          decoration: TextDecoration.underline,
          decorationColor: isDestructive ? theme.colorScheme.error.withValues(alpha: 0.3) : theme.colorScheme.primary.withValues(alpha: 0.3),
        )
      ),
      onTap: () => _launchURL(url),
    );
  }

  Widget _buildVideoEarningRow(ThemeData theme, String title, String amount, String date) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(date, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(amount, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPayoutRow(ThemeData theme, String period, String amount, String status) {
    Color statusColor = theme.colorScheme.surfaceContainerHighest;
    Color statusTextColor = theme.colorScheme.onSurface;
    
    if (status == 'Paid') {
      statusColor = Colors.green.withValues(alpha: 0.2);
      statusTextColor = Colors.green;
    } else if (status == 'Processing') {
      statusColor = Colors.orange.withValues(alpha: 0.2);
      statusTextColor = Colors.orange;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(period, style: theme.textTheme.bodyLarge),
          Row(
            children: [
              Text(amount, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status, 
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusTextColor, 
                    fontWeight: FontWeight.bold
                  )
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SALES PAGE UI ---
  Widget _buildSalesPage(ThemeData theme) {
    final neon = theme.extension<NeonAccentTheme>();
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Text(
                  'Xprex Your\nInfluence.',
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Don't just create content. Build an empire. Get the tools you need to dominate the feed.",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                
                // UPDATED: Replaced Ad Credits with Priority Support
                _buildBenefitRow(
                  theme: theme, 
                  icon: Icons.support_agent_rounded, 
                  iconColor: neon?.cyan ?? Colors.cyan, 
                  title: 'Priority Partner Support', 
                  desc: 'Direct access to our team. Get help and account reviews faster.'
                ),
                
                _buildBenefitRow(theme: theme, icon: Icons.rocket_launch_rounded, iconColor: neon?.purple ?? Colors.purple, title: '1.5x Reach Boost', desc: 'Dominate the algorithm. Your content gets priority placement.'),
                _buildBenefitRow(theme: theme, icon: Icons.verified, iconColor: neon?.blue ?? Colors.blue, title: 'Verification Badge', desc: 'Instant credibility. Stand out in comments.'),
                _buildBenefitRow(theme: theme, icon: Icons.monetization_on_rounded, iconColor: Colors.greenAccent, title: 'Revenue Pool Access', desc: 'Unlock the Creator Revenue Sharing program and get paid to post.'),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(color: theme.colorScheme.surface),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _startPayment,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.onSurface,
                    foregroundColor: theme.colorScheme.surface,
                  ),
                  child: const Text('Join the Elite • ₦7,000/mo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _launchURL('https://creators.getxprex.com/program'),
                child: Text(
                  'Learn more about monetization requirements',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitRow({required ThemeData theme, required IconData icon, required Color iconColor, required String title, required String desc}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(width: 16), 
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(desc, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ]))
      ]),
    );
  }

  // --- PAYMENT LOGIC ---
  void _startPayment() {
    final email = supabase.auth.currentUser?.email;
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No email found')));
      return;
    }
    
    // [PROTOCOL UPDATE] Using the Live Keys & Plan
    final amount = 7000 * 100; // Kobo (Still passed as fallback/display, but Plan overrides)
    final ref = 'Tx_${DateTime.now().millisecondsSinceEpoch}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.white,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: _PaystackWebView(
            apiKey: kPaystackPublicKey, // LIVE KEY
            email: email,
            amount: amount.toString(),
            plan: kPaystackPlanCode, // LIVE PLAN
            reference: ref,
            onSuccess: (ref) {
              Navigator.pop(context); 
              _confirmPurchaseOnBackend(ref); 
            },
            onCancel: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment cancelled')));
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmPurchaseOnBackend(String reference) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await supabase.rpc('confirm_premium_purchase', params: {
        'payment_reference': reference,
        'payment_amount': 7000,
        // The backend handles the 'subscription' logic via webhook mostly, 
        // but this confirms the immediate transaction success to the user.
      });
      if (!mounted) return;
      Navigator.pop(context); 
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Welcome to the Elite 🚀'),
          content: const Text('Payment verified! Let\'s set up your profile for payouts.'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // [UPDATED] Navigate to Step 1: Personal Info
                context.push('/setup/personal');
              },
              child: const Text('Let\'s Go'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification failed: $e')));
      }
    }
  }
}

class _PaystackWebView extends StatefulWidget {
  final String apiKey;
  final String email;
  final String amount;
  final String? plan; // [NEW] Plan code
  final String reference;
  final Function(String) onSuccess;
  final VoidCallback onCancel;
  
  const _PaystackWebView({
    required this.apiKey, 
    required this.email, 
    required this.amount, 
    this.plan,
    required this.reference, 
    required this.onSuccess, 
    required this.onCancel
  });

  @override
  State<_PaystackWebView> createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<_PaystackWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final String htmlContent = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <script src="https://js.paystack.co/v1/inline.js"></script>
      </head>
      <body onload="payWithPaystack()" style="background-color:white; display:flex; justify-content:center; align-items:center; height:100vh;">
        <p>Loading Secure Checkout...</p>
        <script>
          function payWithPaystack() {
            var handler = PaystackPop.setup({
              key: '${widget.apiKey}',
              email: '${widget.email}',
              amount: ${widget.amount},
              currency: 'NGN',
              ${widget.plan != null ? "plan: '${widget.plan}'," : ""} // [NEW] Inject Plan Code
              ref: '${widget.reference}',
              callback: function(response) { PaystackChannel.postMessage('success:' + response.reference); },
              onClose: function() { PaystackChannel.postMessage('close'); }
            });
            handler.openIframe();
          }
        </script>
      </body>
      </html>
    ''';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'PaystackChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message.startsWith('success:')) {
            widget.onSuccess(message.message.split(':')[1]);
          } else if (message.message == 'close') {
            widget.onCancel();
          }
        },
      )
      ..loadHtmlString(htmlContent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Secure Payment', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: widget.onCancel),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
