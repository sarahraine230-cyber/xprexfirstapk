import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_paystack/flutter_paystack.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/config/supabase_config.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';

class MonetizationScreen extends ConsumerStatefulWidget {
  const MonetizationScreen({super.key});

  @override
  ConsumerState<MonetizationScreen> createState() => _MonetizationScreenState();
}

class _MonetizationScreenState extends ConsumerState<MonetizationScreen> {
  // PAYSTACK CONFIGURATION
  // Test Public Key
  final String _paystackPublicKey = 'pk_test_99d8aff0dc4162e41153b3b57e424bd9c3b37639';
  final _paystackPlugin = PaystackPlugin();

  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _paystackPlugin.initialize(publicKey: _paystackPublicKey);
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

  String _getReference() {
    String platform;
    if (Platform.isIOS) {
      platform = 'iOS';
    } else {
      platform = 'Android';
    }
    return 'ChargedFrom${platform}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _purchasePremium() async {
    // Direct access to email to avoid getter error
    final email = supabase.auth.currentUser?.email;

    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No email found for this user.')),
      );
      return;
    }

    try {
      // 1. Prepare the Charge
      Charge charge = Charge()
        ..amount = 7000 * 100 // Amount in kobo
        ..reference = _getReference()
        ..email = email
        ..currency = 'NGN';
        // REMOVED: ..status = 'native' (This caused the build failure)

      // 2. Checkout
      CheckoutResponse response = await _paystackPlugin.checkout(
        context,
        method: CheckoutMethod.card,
        charge: charge,
        fullscreen: true,
        logo: const Icon(Icons.verified, size: 24, color: Colors.purple),
      );

      // 3. Handle Response
      if (response.status == true) {
        debugPrint('✅ Paystack payment success: ${response.reference}');
        await _confirmPurchaseOnBackend(response.reference!);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment cancelled or failed.')),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Payment Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment Error: $e')),
        );
      }
    }
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
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Welcome to the Elite 🚀'),
            content: const Text('Payment verified! Your premium features, ad credits, and boost are now active.'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Let\'s Go'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Backend Verification Failed: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification failed: $e. Please contact support with Ref: $reference')),
        );
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

                _buildBenefitRow(
                  theme: theme,
                  icon: Icons.campaign_rounded,
                  iconColor: neon?.cyan ?? Colors.cyan,
                  title: 'Monthly Ad Credits',
                  desc: 'Get ₦2,000 every month to promote your brand directly on the timeline.',
                ),
                _buildBenefitRow(
                  theme: theme,
                  icon: Icons.rocket_launch_rounded,
                  iconColor: neon?.purple ?? Colors.purple,
                  title: '1.5x Reach Boost',
                  desc: 'Dominate the algorithm. Your content gets priority placement in For You.',
                ),
                _buildBenefitRow(
                  theme: theme,
                  icon: Icons.verified,
                  iconColor: neon?.blue ?? Colors.blue,
                  title: 'Verification Badge',
                  desc: 'Instant credibility. Stand out in comments and search results.',
                ),
                _buildBenefitRow(
                  theme: theme,
                  icon: Icons.monetization_on_rounded,
                  iconColor: Colors.greenAccent,
                  title: 'Revenue Pool Access',
                  desc: 'Unlock the Creator Revenue Sharing program and get paid to post.',
                ),
              ],
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _purchasePremium,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.onSurface,
                    foregroundColor: theme.colorScheme.surface,
                  ),
                  child: const Text(
                    'Join the Elite • ₦7,000/mo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  _showRequirementsSheet(context, theme);
                },
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

  Widget _buildBenefitRow({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(desc, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumDashboard(ThemeData theme) {
    final earnings = _profileData?['earnings_balance'] ?? 0.0;
    final adCredits = 2000;
    final progress = _profileData?['progress'] ?? 0;
    final views = _profileData?['video_views'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                Text(
                  'Estimated Earnings',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  '₦${earnings.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Next Payout: Dec 30',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.campaign, color: theme.colorScheme.secondary, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        'Ad Credits',
                        style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₦$adCredits',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.bar_chart, color: theme.colorScheme.tertiary, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        '30d Views',
                        style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$views',
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
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
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: progress / 100,
                      strokeWidth: 12,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      color: theme.colorScheme.primary,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$progress%', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                        Text('Qualified', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRequirementsSheet(BuildContext context, ThemeData theme) {
    final criteria = _profileData?['criteria'] as Map<String, dynamic>?;
    
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
              const Text('Loading criteria...'),
          ],
        ),
      ),
    );
  }

  Widget _buildReqItem(String text, bool met, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            color: met ? Colors.green : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(text, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}
