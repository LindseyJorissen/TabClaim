import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/hangout_summary.dart';
import '../../../providers/hangout_history_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(hangoutHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('TabClaim'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingH,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              // ── Start CTA ────────────────────────────────────────────────
              _StartCard(
                onTap: () => context.push(AppRoutes.createHangout),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Recent', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.base),
              // ── History list ─────────────────────────────────────────────
              Expanded(
                child: historyAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (_, _) => const Center(
                    child: Text('Could not load history'),
                  ),
                  data: (history) => history.isEmpty
                      ? _EmptyState()
                      : ListView.separated(
                          itemCount: history.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, i) => _HangoutCard(
                            summary: history[i],
                            onDelete: () => ref
                                .read(hangoutHistoryProvider.notifier)
                                .delete(history[i].id),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _StartCard extends StatelessWidget {
  const _StartCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New hangout',
                      style: AppTypography.h2.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Scan a receipt and start claiming',
                      style: AppTypography.body.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.radius),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: AppColors.inkMuted,
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            'No hangouts yet',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.inkSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Start by scanning a receipt',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _HangoutCard extends StatelessWidget {
  const _HangoutCard({required this.summary, required this.onDelete});
  final HangoutSummary summary;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final names = summary.participantNames.take(3).join(', ');
    final overflow = summary.participantNames.length > 3
        ? ' +${summary.participantNames.length - 3}'
        : '';

    return Dismissible(
      key: ValueKey(summary.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Row(
          children: [
            // Date badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryMuted,
                borderRadius: BorderRadius.circular(AppSpacing.radius),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${summary.createdAt.day}',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.primary),
                  ),
                  Text(
                    _monthAbbr(summary.createdAt.month),
                    style:
                        AppTypography.caption.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.base),
            // Name + people
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary.name, style: AppTypography.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    '$names$overflow',
                    style: AppTypography.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Total
            Text(
              CurrencyFormatter.format(summary.total),
              style: AppTypography.amountSmall,
            ),
          ],
        ),
      ),
    );
  }

  static String _monthAbbr(int month) {
    const abbrs = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return abbrs[month - 1];
  }
}
