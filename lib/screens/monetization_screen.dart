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
// If 'is_premium' changes, the UI updates instantly.
final monetizationProfileProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final authService = ref.watch(authServiceProvider);
  final userId = authService.currentUserId;
  
  if (userId == null) {
    return Stream.value({});
  }

  // We stream the profile row. 
  // If you manually edit Supabase, this updates the app immediately.
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
        // Dynamic Title based on state
        title: profileAsync.when(
          data: (data) => Text(
            (data['is_premium'] == true) ? 'Creator Hub' : 'Premium',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Monetization'),
        ),
        centerTitle: true,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (profileData) {
          if (profileData.isEmpty) return const Center(child: Text("Profile not found"));

          final isPremium = profileData['is_premium'] == true;

          // REACTIVE SWITCH:
          // If is_premium is true, we ALWAYS show the Dashboard.
          // If false, we show the Sales Page.
          if (isPremium) {
            return _buildPremiumDashboard(theme, profileData);
          } else {
            return _buildSalesPage(theme);
          }
        },
      ),
    );
  }

  // --- THE ROBUST WEBVIEW PAYMENT LOGIC ---
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
              Navigator.pop(context); // Close sheet
              _confirmPurchaseOnBackend(ref); // Verify
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
    // We show a loader dialog while verifying
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

      // Success Dialog
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
                // CRITICAL: Navigate to the Sequence
                context.push('/verify');
              },
              child: const Text('Let\'s Go'),
            ),
          ],
        ),
      );
      // Note: We don't need to manually refresh the UI here. 
      // The 'monetizationProfileProvider' stream will automatically fire 
      // when the 'confirm_premium_purchase' function updates the database.
      
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loader
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification failed: $e')));
      }
    }
  }

  // ===========================================================================
  // 1. SALES PAGE UI
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
                onTap: () => _showRequirementsSheet(context, theme, null), // Pass null for profileData
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
  
  // ===========================================================================
  // 2. DASHBOARD VIEW (With Verification Logic)
  // ===========================================================================
  Widget _buildPremiumDashboard(ThemeData theme, Map<String, dynamic> profileData) {
    final earnings = profileData['earnings_balance'] ?? 0.0;
    // Hardcoded benefits for MVP
    final adCredits = 2000; 
    final progress = profileData['progress'] ?? 0;
    final views = profileData['total_video_views'] ?? 0;
    
    // VERIFICATION CHECK
    final isVerified = profileData['is_verified'] == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- VERIFICATION BANNER ---
          if (!isVerified)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade900.withValues(alpha: 0.2),
                border: Border.all(color: Colors.amber.shade700),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.hourglass_top, color: Colors.amber.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Verification Pending', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.amber.shade700)),
                        const SizedBox(height: 4),
                        Text('Your ID is under review. Earnings will accumulate but cannot be withdrawn yet.', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else 
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade900.withValues(alpha: 0.2),
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Text('Account Verified. Payouts Active.', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),

          // Earnings Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estimated Earnings', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                const SizedBox(height: 8),
                Text('₦${earnings.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Next Payout: Dec 30', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Ad Credits
              Expanded(child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.campaign, color: theme.colorScheme.secondary, size: 32),
                  const SizedBox(height: 12),
                  Text('Ad Credits', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('₦$adCredits', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                ]),
              )),
              const SizedBox(width: 16),
              // Views
              Expanded(child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.bar_chart, color: theme.colorScheme.tertiary, size: 32),
                  const SizedBox(height: 12),
                  Text('30d Views', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('$views', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                ]),
              )),
            ],
          ),
          const SizedBox(height: 32),
          Text('Monetization Progress', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              height: 160,
              width: 160,
              child: Stack(
                children: [
                  SizedBox.expand(child: CircularProgressIndicator(value: progress / 100, strokeWidth: 12, backgroundColor: theme.colorScheme.surfaceContainerHighest, color: theme.colorScheme.primary, strokeCap: StrokeCap.round)),
                  Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$progress%', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                    Text('Qualified', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ])),
                ],
              ),
            ),
          ),
        ],
      ),
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
