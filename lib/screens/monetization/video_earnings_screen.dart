import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:xprex/theme.dart';
// IMPORTANT: We import the monetization screen to reuse the provider we already built.
// This prevents code duplication.
import 'package:xprex/screens/monetization_screen.dart';

class VideoEarningsScreen extends ConsumerWidget {
  final String period;

  const VideoEarningsScreen({super.key, required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    // Reuse the exact same logic/provider from the main screen
    final earningsAsync = ref.watch(earningsBreakdownProvider(period));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$period Earnings',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: earningsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (rawItems) {
          // 1. FILTER: Only show videos that made money (> 0)
          final items = rawItems.where((item) {
            final amount = double.tryParse(item['amount'].toString()) ?? 0.0;
            return amount > 0;
          }).toList();

          // 2. SORT: Highest earnings first
          items.sort((a, b) {
            final amtA = double.tryParse(a['amount'].toString()) ?? 0.0;
            final amtB = double.tryParse(b['amount'].toString()) ?? 0.0;
            return amtB.compareTo(amtA); // Descending
          });

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.monetization_on_outlined, size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(
                    'No earnings recorded for $period yet.',
                    style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          // Calculate Total for Header
          final totalForPeriod = items.fold(0.0, (sum, item) => sum + (double.tryParse(item['amount'].toString()) ?? 0.0));

          return Column(
            children: [
              // --- HEADER SUMMARY ---
              Container(
                width: double.infinity,
                padding: AppSpacing.paddingMd,
                color: theme.colorScheme.surface,
                child: Column(
                  children: [
                    Text('Total Video Revenue', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(
                      '₦${totalForPeriod.toStringAsFixed(2)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // --- THE LEADERBOARD LIST ---
              Expanded(
                child: ListView.separated(
                  padding: AppSpacing.paddingMd,
                  itemCount: items.length,
                  separatorBuilder: (ctx, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final rank = index + 1;
                    final title = item['title'] ?? 'Unknown Video';
                    final dateRaw = item['date'];
                    final dateParsed = DateTime.tryParse(dateRaw.toString());
                    final dateStr = dateParsed != null ? DateFormat('MMM d').format(dateParsed) : '';
                    final amount = double.tryParse(item['amount'].toString()) ?? 0.0;

                    return _buildEarningTile(theme, rank, title, dateStr, amount);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEarningTile(ThemeData theme, int rank, String title, String date, double amount) {
    // Styling for Top 3
    Color? rankColor;
    if (rank == 1) rankColor = const Color(0xFFFFD700); // Gold
    else if (rank == 2) rankColor = const Color(0xFFC0C0C0); // Silver
    else if (rank == 3) rankColor = const Color(0xFFCD7F32); // Bronze
    else rankColor = theme.colorScheme.onSurfaceVariant.withOpacity(0.5);

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Rank Number
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rank <= 3 ? rankColor!.withOpacity(0.2) : null,
              border: rank <= 3 ? Border.all(color: rankColor!, width: 2) : null,
            ),
            child: Text(
              '#$rank',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: rank <= 3 ? rankColor : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // Video Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Last earned: $date',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          
          // Amount
          const SizedBox(width: 12),
          Text(
            '₦${amount.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              // Highlight the money in primary color if it's significant
              color: theme.colorScheme.onSurface, 
            ),
          ),
        ],
      ),
    );
  }
}
