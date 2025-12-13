import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';

// --- REACTIVE PROVIDER ---
// This listens to the database in real-time. 
final monetizationProfileProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final authService = ref.watch(authServiceProvider);
  final userId = authService.currentUserId;
  
  if (userId == null) {
    return Stream.value({});
  }

  return Supabase.instance.client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('auth_user_id', userId)
      .map((event) => event.isNotEmpty ? event.first : {});
});

class MonetizationScreen extends ConsumerStatefulWidget {
  const MonetizationScreen({super.key});

  @override
  ConsumerState<MonetizationScreen> createState() => _MonetizationScreenState();
}

class _MonetizationScreenState extends ConsumerState<MonetizationScreen> {
  // PAYSTACK CONFIG (Test Key)
  final String _paystackPublicKey = 'pk_test_99d8aff0dc4162e41153b3b57e424bd9c3b37639';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(monetizationProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: profileAsync.when(
          data: (data) => Text(
            (data['is_premium'] == true) ? 'Partner Program' : 'Premium',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Monetization'),
        ),
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (profileData) {
          if (profileData.isEmpty) return const Center(child: Text("Profile not found"));

          final isPremium = profileData['is_premium'] == true;

          // REACTIVE SWITCH
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
  // 1. PROFESSIONAL DASHBOARD (Medium-Inspired)
  // ===========================================================================
  Widget _buildProfessionalDashboard(ThemeData theme, Map<String, dynamic> profileData) {
    final earnings = profileData['earnings_balance'] ?? 0.0;
    final isVerified = profileData['is_verified'] == true;
    
    // Ad credits are now just a stat, not a loud button
    // We treat "Ad Credits" as a balance available.
    final adCredits = 2000; 

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 1. STATUS CARD (Like Medium's "Status: Enrolled") ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8), // Sharper corners for pro feel
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
                          isVerified ? 'Active & Enrolled' : 'Verification Pending',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                if (!isVerified)
                  TextButton(
                    onPressed: () => context.push('/verify'),
                    child: const Text('Complete Setup'),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),

          // --- 2. EARNINGS SUMMARY (The "Statement" Look) ---
          Text('Overview', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'This page displays earnings accrued in the selected period. Payouts are processed on the 30th.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          // Big Number
          Text('Total earnings', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(
            '₦${earnings.toStringAsFixed(2)}', 
            style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -1),
          ),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // --- 3. PAYOUT SETTINGS & TOOLS (The "Accordion" feel) ---
          _buildSettingsTile(
            theme, 
            title: 'Payout settings', 
            subtitle: isVerified ? 'Bank account connected' : 'Connect bank account',
            icon: Icons.account_balance,
            onTap: () => context.push('/setup/bank'),
          ),
          _buildSettingsTile(
            theme, 
            title: 'Ad Credit Manager', 
            subtitle: 'Balance: ₦$adCredits',
            icon: Icons.campaign_outlined,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad Manager coming soon')));
            },
          ),
           _buildSettingsTile(
            theme, 
            title: 'Quick links', 
            subtitle: 'Program Terms, Support, FAQs',
            icon: Icons.link,
            onTap: () {}, // Link to docs later
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // --- 4. EARNINGS BY VIDEO (Mocked for "Earnings by Story" feel) ---
          Text('Earnings by video', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Mock Data to simulate the feel
          _buildVideoEarningRow(theme, "12 Brutal Truths About Narcissists", "₦4,200.50", "Dec 4, 2025"),
          _buildVideoEarningRow(theme, "Why Nice Guys Finish Last", "₦1,850.00", "Dec 10, 2025"),
          _buildVideoEarningRow(theme, "Day in the Life: Lagos Tech", "₦920.00", "Dec 12, 2025"),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

           // --- 5. PAYOUT HISTORY ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payout History', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              TextButton(onPressed: (){}, child: const Text('View all')),
            ],
          ),
          const SizedBox(height: 8),
          _buildPayoutRow(theme, "Nov 1 - Nov 30", "₦0.00", "Paid"),
          _buildPayoutRow(theme, "Oct 1 - Oct 31", "₦0.00", "Paid"),
        ],
      ),
    );
  }

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
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(status, style: theme.textTheme.bodySmall),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. SALES PAGE UI (Unchanged Logic, just ensuring it's here)
  // ===========================================================================
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
                
                _buildBenefitRow(theme: theme, icon: Icons.campaign_rounded, iconColor: neon?.cyan ?? Colors.cyan, title: 'Monthly Ad Credits', desc: 'Get ₦2,000 every month to promote your brand.'),
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
                onTap: () => _showRequirementsSheet(context, theme, null),
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

  void _showRequirementsSheet(BuildContext context, ThemeData theme, Map<String, dynamic>? profileData) {
    final criteria = profileData?['criteria'] as Map<String, dynamic>?;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Eligibility Requirements', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24),
            if (criteria != null) ...[
               _buildReqItem('1,000+ Followers', criteria['min_followers'] ?? false, theme),
               _buildReqItem('10,000+ Video Views', criteria['min_video_views'] ?? false, theme),
               _buildReqItem('Account Age 30+ Days', criteria['min_account_age'] ?? false, theme),
               _buildReqItem('Email Verified', criteria['email_verified'] ?? false, theme),
            ] else 
              const Text('Standard Criteria apply.'),
          ],
        ),
      ),
    );
  }

  Widget _buildReqItem(String text, bool met, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(children: [
        Icon(met ? Icons.check_circle : Icons.circle_outlined, color: met ? Colors.green : theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(text, style: theme.textTheme.bodyLarge),
      ]),
    );
  }

  // --- PAYMENT LOGIC PRESERVED ---
  void _startPayment() {
    final email = supabase.auth.currentUser?.email;
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No email found')));
      return;
    }
    final amount = 7000 * 100; // Kobo
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
            apiKey: _paystackPublicKey,
            email: email,
            amount: amount.toString(),
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
      });
      if (!mounted) return;
      Navigator.pop(context); // Close loader
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
                context.push('/verify');
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

// --- THE ROBUST WEBVIEW COMPONENT ---
class _PaystackWebView extends StatefulWidget {
  final String apiKey;
  final String email;
  final String amount;
  final String reference;
  final Function(String) onSuccess;
  final VoidCallback onCancel;

  const _PaystackWebView({required this.apiKey, required this.email, required this.amount, required this.reference, required this.onSuccess, required this.onCancel});

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
