import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';

class MonetizationScreen extends ConsumerStatefulWidget {
  const MonetizationScreen({super.key});

  @override
  ConsumerState<MonetizationScreen> createState() => _MonetizationScreenState();
}

class _MonetizationScreenState extends ConsumerState<MonetizationScreen> {
  Map<String, dynamic>? _eligibilityData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEligibility();
  }

  Future<void> _loadEligibility() async {
    final authService = ref.read(authServiceProvider);
    final profileService = ref.read(profileServiceProvider);
    
    try {
      final data = await profileService.getMonetizationEligibility(authService.currentUserId!);
      setState(() {
        _eligibilityData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading eligibility: $e')),
        );
      }
    }
  }

  Future<void> _enablePremium() async {
    final profileService = ref.read(profileServiceProvider);
    final authService = ref.read(authServiceProvider);
    
    try {
      await profileService.updateProfile(
        authUserId: authService.currentUserId!,
        isPremium: true,
        monetizationStatus: 'active',
      );

      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Success!'),
          content: const Text('Premium membership activated. You can now monetize your content!'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.pop();
              },
              child: const Text('Great!'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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

    final eligible = _eligibilityData?['eligible'] ?? false;
    final progress = _eligibilityData?['progress'] ?? 0;
    final criteria = _eligibilityData?['criteria'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(title: const Text('Monetization')),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Column(
          children: [
            SizedBox(
              height: 200,
              width: 200,
              child: Stack(
                children: [
                  Center(
                    child: SizedBox(
                      height: 180,
                      width: 180,
                      child: CircularProgressIndicator(
                        value: progress / 100,
                        strokeWidth: 12,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$progress%', style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text('Complete', style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text('Eligibility Checklist', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            if (criteria != null) ...[
              _buildCriteriaItem('1,000+ Followers', criteria['min_followers'] ?? false, '${_eligibilityData!['followers']} followers', theme),
              _buildCriteriaItem('10,000+ Video Views', criteria['min_video_views'] ?? false, '${_eligibilityData!['video_views']} views', theme),
              _buildCriteriaItem('Account Age 30+ Days', criteria['min_account_age'] ?? false, '${_eligibilityData!['account_age_days']} days', theme),
              _buildCriteriaItem('Email Verified', criteria['email_verified'] ?? false, '', theme),
              _buildCriteriaItem('18+ Confirmed', criteria['age_confirmed'] ?? false, '', theme),
              _buildCriteriaItem('No Active Flags', criteria['no_active_flags'] ?? false, '', theme),
            ],
            const SizedBox(height: 32),
            if (eligible) ...[
              Container(
                padding: AppSpacing.paddingLg,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  children: [
                    Icon(Icons.star, size: 64, color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(height: 16),
                    Text('You\'re Eligible!', style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
                    const SizedBox(height: 8),
                    Text('Start earning from your content today', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer), textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _enablePremium,
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
                child: const Text('Enable Premium'),
              ),
            ] else ...[
              Container(
                padding: AppSpacing.paddingLg,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text('Keep Creating!', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('Complete all criteria to unlock monetization', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCriteriaItem(String title, bool met, String subtitle, ThemeData theme) {
    return ListTile(
      leading: Icon(met ? Icons.check_circle : Icons.radio_button_unchecked, color: met ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
      title: Text(title),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
    );
  }
}
