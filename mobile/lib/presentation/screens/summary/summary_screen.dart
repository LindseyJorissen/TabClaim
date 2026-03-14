import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/hangout_summary.dart';
import '../../../data/models/participant.dart';
import '../../../data/models/receipt_item.dart';
import '../../../data/models/settlement.dart';
import '../../../providers/hangout_draft_provider.dart';
import '../../../providers/hangout_history_provider.dart';
import '../../widgets/participant_avatar/participant_avatar.dart';
import '../hangout/claiming_screen.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key, required this.args});
  final SummaryArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(args.hangoutName),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _share(context),
            tooltip: 'Share',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPaddingH,
          AppSpacing.base,
          AppSpacing.screenPaddingH,
          AppSpacing.xxxl,
        ),
        children: [
          // ── Success header ──────────────────────────────────────────────
          _SuccessHeader(
            total: args.total,
            payerName: args.payerName,
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

          const SizedBox(height: AppSpacing.xxl),

          // ── Settlements ─────────────────────────────────────────────────
          Text('Who owes what', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),

          if (args.settlements.isEmpty)
            _EvenCard()
          else
            ...args.settlements.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _SettlementCard(
                      settlement: e.value,
                      participants: args.participants,
                    ).animate().fadeIn(
                          delay: (e.key * 80).ms,
                          duration: 300.ms,
                        ),
                  ),
                ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Per-person breakdown ────────────────────────────────────────
          Text('Per person', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),
          _PerPersonBreakdown(
            participants: args.participants,
            items: args.items,
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Done button ─────────────────────────────────────────────────
          ElevatedButton(
            onPressed: () {
              _saveToHistory(ref);
              ref.read(hangoutDraftProvider.notifier).clear();
              context.go(AppRoutes.home);
            },
            child: const Text('Done'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () => _share(context),
            child: const Text('Copy summary'),
          ),
        ],
      ),
    );
  }

  void _saveToHistory(WidgetRef ref) {
    final summary = HangoutSummary(
      id: 'h_${DateTime.now().millisecondsSinceEpoch}',
      name: args.hangoutName,
      createdAt: DateTime.now(),
      total: args.total,
      currency: 'USD',
      participantNames: args.participants.map((p) => p.name).toList(),
      settlements: args.settlements.map((s) {
        final from = args.participants
            .firstWhere((p) => p.id == s.fromParticipantId)
            .name;
        final to = args.participants
            .firstWhere((p) => p.id == s.toParticipantId)
            .name;
        return SettlementSummary(fromName: from, toName: to, amount: s.amount);
      }).toList(),
    );
    ref.read(hangoutHistoryProvider.notifier).save(summary);
  }

  void _share(BuildContext context) {
    final text = _buildShareText();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Summary copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _buildShareText() {
    final buf = StringBuffer();
    buf.writeln('💸 ${args.hangoutName}');
    buf.writeln('Total: ${CurrencyFormatter.format(args.total)}');
    buf.writeln();

    if (args.settlements.isEmpty) {
      buf.writeln('Everyone owes the same — split evenly!');
    } else {
      for (final s in args.settlements) {
        final from = args.participants
            .firstWhere((p) => p.id == s.fromParticipantId)
            .name;
        final to = args.participants
            .firstWhere((p) => p.id == s.toParticipantId)
            .name;
        buf.writeln('$from owes $to ${CurrencyFormatter.format(s.amount)}');
      }
    }

    buf.writeln();
    buf.writeln('Split with TabClaim');
    return buf.toString();
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SuccessHeader extends StatelessWidget {
  const _SuccessHeader({required this.total, required this.payerName});
  final double total;
  final String payerName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.successMuted,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.success,
              size: 30,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text('All done!', style: AppTypography.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$payerName paid ${CurrencyFormatter.format(total)} total',
            style: AppTypography.body.copyWith(color: AppColors.inkSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SettlementCard extends StatelessWidget {
  const _SettlementCard({
    required this.settlement,
    required this.participants,
  });
  final Settlement settlement;
  final List<Participant> participants;

  @override
  Widget build(BuildContext context) {
    final from = participants.firstWhere(
      (p) => p.id == settlement.fromParticipantId,
    );
    final to = participants.firstWhere(
      (p) => p.id == settlement.toParticipantId,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          ParticipantAvatar(participant: from, size: 40),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(from.name, style: AppTypography.bodyMedium),
                Text(
                  'owes ${to.name}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(settlement.amount),
            style: AppTypography.amount.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _EvenCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.successMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration_rounded,
              color: AppColors.success, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Everything is split evenly — no debts!',
            style:
                AppTypography.body.copyWith(color: AppColors.success),
          ),
        ],
      ),
    );
  }
}

class _PerPersonBreakdown extends StatelessWidget {
  const _PerPersonBreakdown({
    required this.participants,
    required this.items,
  });
  final List<Participant> participants;
  final List<ReceiptItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: participants.map((p) {
        final share = _shareFor(p.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                ParticipantAvatar(participant: p, size: 36),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(p.name, style: AppTypography.bodyMedium),
                ),
                Text(
                  CurrencyFormatter.format(share),
                  style: AppTypography.amountSmall,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  double _shareFor(String participantId) {
    double total = 0;
    for (final item in items) {
      final portion = item.assignments[participantId] ?? 0;
      total += item.totalPrice * portion;
    }
    return total;
  }
}
