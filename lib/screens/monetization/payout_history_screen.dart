import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xprex/providers/auth_provider.dart';
import 'package:xprex/theme.dart';

// --- PROVIDER: Fetch ALL Payout History (No Limit) ---
final payoutHistoryFullProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final userId = authService.currentUserId;
  if (userId == null) return [];

  final response = await Supabase.instance.client
      .from('payouts')
      .select('*')
      .eq('user_id', userId)
      .order('period', ascending: false); // Newest first

  return List<Map<String, dynamic>>.from(response);
});

class PayoutHistoryScreen extends ConsumerWidget {
  const PayoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(payoutHistoryFullProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Payout History',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (payouts) {
          if (payouts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No payouts records found.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: AppSpacing.paddingMd, // [cite: 170]
            itemCount: payouts.length,
            separatorBuilder: (ctx, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final payout = payouts[index];
              
              // Parse Data
              final date = DateTime.tryParse(payout['period'].toString());
              final dateLabel = date != null ? DateFormat('MMMM yyyy').format(date) : payout['period'].toString();
              final amount = double.tryParse(payout['amount'].toString()) ?? 0.0;
              final status = payout['status'].toString();
              
              // Optional: Show "Processed on..." date if paid
              final paidDateRaw = payout['processed_at'];
              final paidDate = paidDateRaw != null ? DateTime.tryParse(paidDateRaw.toString()) : null;
              final paidDateStr = paidDate != null ? DateFormat('MMM d, yyyy').format(paidDate) : null;

              return _buildPayoutCard(theme, dateLabel, amount, status, paidDateStr);
            },
          );
        },
      ),
    );
  }

  Widget _buildPayoutCard(ThemeData theme, String period, double amount, String status, String? processedDate) {
    // Status Logic
    Color statusBg;
    Color statusText;
    IconData statusIcon;

    if (status == 'Paid') {
      statusBg = Colors.green.withValues(alpha: 0.15);
      statusText = Colors.green;
      statusIcon = Icons.check_circle_outline;
    } else if (status == 'Processing') {
      statusBg = Colors.orange.withValues(alpha: 0.15);
      statusText = Colors.orange;
      statusIcon = Icons.hourglass_empty;
    } else {
      statusBg = theme.colorScheme.errorContainer;
      statusText = theme.colorScheme.error;
      statusIcon = Icons.error_outline;
    }

    return Container(
      padding: AppSpacing.paddingMd, // [cite: 170]
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.md), // [cite: 177]
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Period and Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                period,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm), // 
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 14, color: statusText),
                    const SizedBox(width: 4),
                    Text(
                      status.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith( // [cite: 223]
                        color: statusText,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          
          // Bottom Row: Amount and Detail
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount',
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₦${amount.toStringAsFixed(2)}',
                    style: theme.textTheme.headlineSmall?.copyWith( // [cite: 204]
                      fontWeight: FontWeight.bold,
                      fontSize: 20, 
                    ),
                  ),
                ],
              ),
              if (processedDate != null)
                Text(
                  'Sent on $processedDate',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), // [cite: 224]
                ),
            ],
          ),
        ],
      ),
    );
  }
}
