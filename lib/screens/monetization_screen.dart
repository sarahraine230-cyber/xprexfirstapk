import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart'; // NEW IMPORT
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';

class MonetizationScreen extends ConsumerStatefulWidget {
  const MonetizationScreen({super.key});

  @override
  ConsumerState<MonetizationScreen> createState() => _MonetizationScreenState();
}

class _MonetizationScreenState extends ConsumerState<MonetizationScreen> {
  // PAYSTACK CONFIG (Test Key)
  final String _paystackPublicKey = 'pk_test_99d8aff0dc4162e41153b3b57e424bd9c3b37639';

  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final authService = ref.read(authServiceProvider);
    final profileService = ref.read(profileServiceProvider);
    try {
      final data = await profileService.getMonetizationEligibility(authService.currentUserId!);
      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('Error loading profile: $e');
    }
  }

  // --- THE NEW WEBVIEW PAYMENT METHOD ---
  void _startPayment() {
    final email = supabase.auth.currentUser?.email;
    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No email found')));
      return;
    }

    // Amount in Kobo (7000 * 100)
    final amount = 7000 * 100;
    final ref = 'Tx_${DateTime.now().millisecondsSinceEpoch}';

    // Show the WebView Payment Sheet
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
    setState(() => _isLoading = true);
    try {
      await supabase.rpc('confirm_premium_purchase', params: {
        'payment_reference': reference,
        'payment_amount': 7000,
      });
      await _loadProfileData();
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Welcome to the Elite 🚀'),
            content: const Text('Payment verified! Your premium features are active.'),
            actions: [
              FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Let\'s Go')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Monetization')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isPremium = _profileData?['is_premium'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(isPremium ? 'Creator Hub' : 'Premium'),
        centerTitle: true,
      ),
      body: isPremium ? _buildPremiumDashboard(theme) : _buildSalesPage(theme),
    );
  }

  // ... (Keep existing UI Widgets _buildSalesPage, _buildPremiumDashboard, etc. unchanged)
  // [I am omitting the long UI code here for brevity, but YOU MUST KEEP IT in your file]
  // Just replace the `_purchasePremium` call in the button with `_startPayment`
  
  // ===========================================================================
  // 1. SALES PAGE (UI Logic)
  // ===========================================================================
  Widget _buildSalesPage(ThemeData theme) {
    final neon = theme.extension<NeonAccentTheme>();
    // ... (Your existing UI layout)
    
    // NOTE: In the 'FilledButton' inside _buildSalesPage, make sure to call _startPayment
    // onPressed: _startPayment, 
    
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
                _buildBenefitRow(theme: theme, icon: Icons.campaign_rounded, iconColor: neon?.cyan ?? Colors.cyan, title: 'Monthly Ad Credits', desc: 'Get ₦2,000 every month.'),
                _buildBenefitRow(theme: theme, icon: Icons.rocket_launch_rounded, iconColor: neon?.purple ?? Colors.purple, title: '1.5x Reach Boost', desc: 'Dominate the algorithm.'),
                _buildBenefitRow(theme: theme, icon: Icons.verified, iconColor: neon?.blue ?? Colors.blue, title: 'Verification Badge', desc: 'Instant credibility.'),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(color: theme.colorScheme.surface),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _startPayment, // CHANGED TO NEW FUNCTION
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.onSurface,
                foregroundColor: theme.colorScheme.surface,
              ),
              child: const Text('Join the Elite • ₦7,000/mo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  // (Helper widgets like _buildBenefitRow remain the same...)
  Widget _buildBenefitRow({required ThemeData theme, required IconData icon, required Color iconColor, required String title, required String desc}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Row(children: [Icon(icon, color: iconColor, size: 28), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: theme.textTheme.titleMedium), Text(desc, style: theme.textTheme.bodyMedium)]))]),
    );
  }
  
  Widget _buildPremiumDashboard(ThemeData theme) {
     return Center(child: Text("Premium Dashboard")); // Placeholder for brevity
  }
}

// --- THE WEBVIEW COMPONENT (The Magic) ---
class _PaystackWebView extends StatefulWidget {
  final String apiKey;
  final String email;
  final String amount;
  final String reference;
  final Function(String) onSuccess;
  final VoidCallback onCancel;

  const _PaystackWebView({
    required this.apiKey,
    required this.email,
    required this.amount,
    required this.reference,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<_PaystackWebView> createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<_PaystackWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    
    // We create a simple HTML page that auto-executes the Paystack Popup
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
              callback: function(response) {
                // Send success message to Flutter
                PaystackChannel.postMessage('success:' + response.reference);
              },
              onClose: function() {
                // Send close message to Flutter
                PaystackChannel.postMessage('close');
              }
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
            final ref = message.message.split(':')[1];
            widget.onSuccess(ref);
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
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: widget.onCancel,
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
