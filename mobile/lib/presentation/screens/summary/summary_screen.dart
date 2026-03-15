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
import '../../../data/services/api_client.dart';
import '../../../data/services/hangout_sync_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/hangout_draft_provider.dart';
import '../../../providers/hangout_history_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/participant_avatar/participant_avatar.dart';
import '../hangout/claiming_screen.dart';

enum _SyncStatus { idle, syncing, synced, failed }

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key, required this.args});
  final SummaryArgs args;

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  _SyncStatus _syncStatus = _SyncStatus.idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _trySync());
  }

  // ── Sync ─────────────────────────────────────────────────────────────────

  String get _currency =>
      ref.read(settingsProvider).valueOrNull?.currency ?? 'USD';

  Future<void> _trySync() async {
    final auth = ref.read(authProvider).valueOrNull;
    if (auth == null || !auth.isAuthenticated) return; // guests don't sync

    setState(() => _syncStatus = _SyncStatus.syncing);
    try {
      await HangoutSyncService(ApiClient.instance)
          .sync(widget.args, currency: _currency);
      if (mounted) setState(() => _syncStatus = _SyncStatus.synced);
    } catch (_) {
      if (mounted) setState(() => _syncStatus = _SyncStatus.failed);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _done() {
    _saveToHistory();
    ref.read(hangoutDraftProvider.notifier).clear();
    context.go(AppRoutes.home);
  }

  void _saveToHistory() {
    final summary = HangoutSummary(
      id: 'h_${DateTime.now().millisecondsSinceEpoch}',
      name: widget.args.hangoutName,
      createdAt: DateTime.now(),
      total: widget.args.total,
      currency: _currency,
      participantNames:
          widget.args.participants.map((p) => p.name).toList(),
      settlements: widget.args.settlements.map((s) {
        final from = widget.args.participants
            .firstWhere((p) => p.id == s.fromParticipantId)
            .name;
        final to = widget.args.participants
            .firstWhere((p) => p.id == s.toParticipantId)
            .name;
        return SettlementSummary(fromName: from, toName: to, amount: s.amount);
      }).toList(),
    );
    ref.read(hangoutHistoryProvider.notifier).save(summary);
  }

  void _share() {
    Clipboard.setData(ClipboardData(text: _buildShareText()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Summary copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _buildShareText() {
    final c = _currency;
    final buf = StringBuffer();
    buf.writeln('💸 ${widget.args.hangoutName}');
    buf.writeln('Total: ${CurrencyFormatter.format(widget.args.total, currency: c)}');
    buf.writeln();

    if (widget.args.settlements.isEmpty) {
      buf.writeln('Everyone owes the same — split evenly!');
    } else {
      for (final s in widget.args.settlements) {
        final from = widget.args.participants
            .firstWhere((p) => p.id == s.fromParticipantId)
            .name;
        final to = widget.args.participants
            .firstWhere((p) => p.id == s.toParticipantId)
            .name;
        buf.writeln('$from owes $to ${CurrencyFormatter.format(s.amount, currency: c)}');
      }
    }

    buf.writeln();
    buf.writeln('Split with TabClaim');
    return buf.toString();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(settingsProvider).valueOrNull?.currency ?? 'USD';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.args.hangoutName),
        automaticallyImplyLeading: false,
        actions: [
          if (_syncStatus != _SyncStatus.idle)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _SyncBadge(status: _syncStatus),
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: _share,
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
            total: widget.args.total,
            payerName: widget.args.payerName,
            currency: currency,
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

          const SizedBox(height: AppSpacing.xxl),

          // ── Settlements ─────────────────────────────────────────────────
          Text('Who owes what', style: AppTypography.h3),
          const SizedBox(height: AppSpacing.sm),

          if (widget.args.settlements.isEmpty)
            _EvenCard()
          else
            ...widget.args.settlements.asMap().entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _SettlementCard(
                      settlement: e.value,
                      participants: widget.args.participants,
                      currency: currency,
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
            participants: widget.args.participants,
            items: widget.args.items,
            currency: currency,
          ),

          const SizedBox(height: AppSpacing.xxl),

          // ── Actions ─────────────────────────────────────────────────────
          ElevatedButton(
            onPressed: _done,
            child: const Text('Done'),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: _share,
            child: const Text('Copy summary'),
          ),
        ],
      ),
    );
  }
}

// ── Sync badge ────────────────────────────────────────────────────────────────

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.status});
  final _SyncStatus status;

  @override
  Widget build(BuildContext context) {
    return switch (status) {
      _SyncStatus.syncing => const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      _SyncStatus.synced => const Tooltip(
          message: 'Saved to account',
          child: Icon(Icons.cloud_done_outlined,
              size: 20, color: AppColors.success),
        ),
      _SyncStatus.failed => const Tooltip(
          message: 'Saved locally only',
          child: Icon(Icons.cloud_off_outlined,
              size: 20, color: AppColors.warning),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SuccessHeader extends StatelessWidget {
  const _SuccessHeader({
    required this.total,
    required this.payerName,
    required this.currency,
  });
  final double total;
  final String payerName;
  final String currency;

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
            '$payerName paid ${CurrencyFormatter.format(total, currency: currency)} total',
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
    required this.currency,
  });
  final Settlement settlement;
  final List<Participant> participants;
  final String currency;

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
                Text('owes ${to.name}', style: AppTypography.caption),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(settlement.amount, currency: currency),
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
            style: AppTypography.body.copyWith(color: AppColors.success),
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
    required this.currency,
  });
  final List<Participant> participants;
  final List<ReceiptItem> items;
  final String currency;

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
                  CurrencyFormatter.format(share, currency: currency),
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
