import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/settlement_calculator.dart';
import '../../../data/models/hangout.dart';
import '../../../data/models/participant.dart';
import '../../../data/models/receipt.dart';
import '../../../data/models/receipt_item.dart';
import '../../../data/models/settlement.dart';
import '../../../providers/hangout_draft_provider.dart';
import '../../widgets/participant_avatar/participant_avatar.dart';

class ClaimingScreen extends ConsumerStatefulWidget {
  const ClaimingScreen({super.key, required this.hangoutId});
  final String hangoutId;

  @override
  ConsumerState<ClaimingScreen> createState() => _ClaimingScreenState();
}

class _ClaimingScreenState extends ConsumerState<ClaimingScreen> {
  // itemId → { participantId: portion }
  final Map<String, Map<String, double>> _assignments = {};
  String? _activeParticipantId;

  @override
  void initState() {
    super.initState();
    // Seed assignments from any pre-existing item assignments.
    final draft = ref.read(hangoutDraftProvider);
    if (draft == null) return;
    for (final item in draft.items) {
      if (item.type == ReceiptItemType.food && item.assignments.isNotEmpty) {
        _assignments[item.id] = Map.from(item.assignments);
      }
    }
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  List<ReceiptItem> _foodItems(HangoutDraft draft) =>
      draft.items.where((i) => i.type == ReceiptItemType.food).toList();

  int _claimedCount(HangoutDraft draft) => _foodItems(draft)
      .where((i) => (_assignments[i.id]?.isNotEmpty ?? false))
      .length;

  bool _allClaimed(HangoutDraft draft) =>
      _claimedCount(draft) == _foodItems(draft).length;

  // ── Assignment logic ──────────────────────────────────────────────────────

  void _onItemTap(ReceiptItem item, HangoutDraft draft) {
    final existing = _assignments[item.id] ?? {};

    if (_activeParticipantId != null) {
      HapticFeedback.lightImpact();
      // Assign 100% to active participant instantly.
      setState(() {
        _assignments[item.id] = {_activeParticipantId!: 1.0};
      });
    } else {
      // No active participant — open assignment sheet.
      _openAssignSheet(item, draft, existing);
    }
  }

  void _onItemLongPress(ReceiptItem item, HangoutDraft draft) {
    final existing = _assignments[item.id] ?? {};
    _openAssignSheet(item, draft, existing);
  }

  void _openAssignSheet(
    ReceiptItem item,
    HangoutDraft draft,
    Map<String, double> current,
  ) async {
    final result = await showModalBottomSheet<Map<String, double>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AssignSheet(
        item: item,
        participants: draft.participants,
        current: current,
      ),
    );
    if (result != null) {
      setState(() {
        if (result.isEmpty) {
          _assignments.remove(item.id);
        } else {
          _assignments[item.id] = result;
        }
      });
    }
  }

  // ── Finalize ──────────────────────────────────────────────────────────────

  void _finalize(HangoutDraft draft) {
    HapticFeedback.heavyImpact();
    // Merge assignments back onto items.
    final assignedItems = draft.items.map((item) {
      final a = _assignments[item.id];
      if (a == null) return item;
      return item.copyWith(assignments: a);
    }).toList();

    // Build a minimal Hangout to run through SettlementCalculator.
    final receipt = Receipt(
      id: 'r_local',
      hangoutId: widget.hangoutId,
      scannedAt: DateTime.now(),
      items: assignedItems,
    );

    final hangout = Hangout(
      id: widget.hangoutId,
      name: draft.name,
      createdAt: DateTime.now(),
      participants: draft.participants,
      receipts: [receipt],
      payerId: draft.payer.id,
    );

    final settlements = SettlementCalculator.computeSettlements(hangout);

    context.push(
      '/hangout/${widget.hangoutId}/summary',
      extra: _SummaryArgs(
        hangoutName: draft.name,
        participants: draft.participants,
        items: assignedItems,
        settlements: settlements,
        total: receipt.grandTotal,
        payerName: draft.payer.name,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(hangoutDraftProvider);

    if (draft == null || draft.participants.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No hangout in progress.')),
      );
    }

    final foodItems = _foodItems(draft);
    final claimed = _claimedCount(draft);
    final allDone = _allClaimed(draft);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(draft.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.base),
            child: _ProgressChip(claimed: claimed, total: foodItems.length),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Progress bar ──────────────────────────────────────────────
          _ProgressBar(
            fraction: foodItems.isEmpty ? 0 : claimed / foodItems.length,
          ),

          // ── Item list ─────────────────────────────────────────────────
          Expanded(
            child: foodItems.isEmpty
                ? Center(
                    child: Text(
                      'No items to claim.',
                      style: AppTypography.body
                          .copyWith(color: AppColors.inkSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPaddingH,
                      AppSpacing.base,
                      AppSpacing.screenPaddingH,
                      AppSpacing.xxl,
                    ),
                    itemCount: foodItems.length,
                    separatorBuilder: (_, i) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final item = foodItems[i];
                      final assignment = _assignments[item.id] ?? {};
                      final isAssigned = assignment.isNotEmpty;
                      return _ClaimCard(
                        item: item,
                        assignment: assignment,
                        participants: draft.participants,
                        onTap: () => _onItemTap(item, draft),
                        onLongPress: () => _onItemLongPress(item, draft),
                      )
                          .animate()
                          .fadeIn(
                            delay: (i * 30).ms,
                            duration: 250.ms,
                          )
                          .animate(
                            key: ValueKey('${item.id}_$isAssigned'),
                          )
                          .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.03, 1.03),
                            duration: 120.ms,
                            curve: Curves.easeOut,
                          )
                          .then()
                          .scale(
                            begin: const Offset(1.03, 1.03),
                            end: const Offset(1, 1),
                            duration: 100.ms,
                            curve: Curves.easeIn,
                          );
                    },
                  ),
          ),

          // ── Participant strip ─────────────────────────────────────────
          _ParticipantStrip(
            participants: draft.participants,
            activeId: _activeParticipantId,
            onSelect: (id) {
              HapticFeedback.selectionClick();
              setState(() => _activeParticipantId =
                  _activeParticipantId == id ? null : id);
            },
          ),

          // ── Finalize CTA ──────────────────────────────────────────────
          _FinalizeBar(
            allDone: allDone,
            unclaimedCount: foodItems.length - claimed,
            onFinalize: () => _finalize(draft),
            onSplitRemaining: () {
              HapticFeedback.mediumImpact();
              // Split all unassigned items evenly across all participants.
              setState(() {
                final portion = 1.0 / draft.participants.length;
                final evenly = {
                  for (final p in draft.participants) p.id: portion,
                };
                for (final item in foodItems) {
                  if (_assignments[item.id]?.isEmpty ?? true) {
                    _assignments[item.id] = evenly;
                  }
                }
              });
            },
          ),
        ],
      ),
    );
  }
}

// ── Claim card ────────────────────────────────────────────────────────────────

class _ClaimCard extends StatelessWidget {
  const _ClaimCard({
    required this.item,
    required this.assignment,
    required this.participants,
    required this.onTap,
    required this.onLongPress,
  });

  final ReceiptItem item;
  final Map<String, double> assignment;
  final List<Participant> participants;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  bool get _isAssigned => assignment.isNotEmpty;
  bool get _isSplit => assignment.length > 1;

  @override
  Widget build(BuildContext context) {
    final assignedParticipants = participants
        .where((p) => assignment.containsKey(p.id))
        .toList();

    final borderColor = _isAssigned
        ? AppColors.avatarColorForIndex(assignedParticipants.first.colorIndex)
        : AppColors.divider;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: _isAssigned ? borderColor.withValues(alpha: 0.5) : AppColors.divider,
            width: _isAssigned ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // ── Name + qty ────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: AppTypography.bodyMedium),
                  if (item.quantity > 1)
                    Text(
                      '${item.quantity} × ${CurrencyFormatter.format(item.unitPrice)}',
                      style: AppTypography.caption,
                    ),
                ],
              ),
            ),

            // ── Price ─────────────────────────────────────────────────
            Text(
              CurrencyFormatter.format(item.totalPrice),
              style: AppTypography.amountSmall,
            ),
            const SizedBox(width: AppSpacing.sm),

            // ── Assignment indicators ──────────────────────────────────
            if (_isAssigned)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...assignedParticipants.take(3).map(
                        (p) => Padding(
                          padding:
                              const EdgeInsets.only(left: 2),
                          child: ParticipantAvatar(
                            participant: p,
                            size: 28,
                          ),
                        ),
                      ),
                  if (_isSplit)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs),
                      child: Text(
                        'split',
                        style: AppTypography.label.copyWith(
                          color: AppColors.inkSecondary,
                        ),
                      ),
                    ),
                ],
              )
            else
              Text(
                'Tap to claim',
                style: AppTypography.caption.copyWith(
                  color: AppColors.inkMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Participant strip ─────────────────────────────────────────────────────────

class _ParticipantStrip extends StatelessWidget {
  const _ParticipantStrip({
    required this.participants,
    required this.activeId,
    required this.onSelect,
  });

  final List<Participant> participants;
  final String? activeId;
  final void Function(String id) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.sm,
        AppSpacing.screenPaddingH,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            activeId == null
                ? 'Select a person to start claiming'
                : 'Tap items to assign to ${participants.firstWhere((p) => p.id == activeId).name.split(' ').first}',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: participants.map((p) {
                final isActive = p.id == activeId;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.base),
                  child: GestureDetector(
                    onTap: () => onSelect(p.id),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ParticipantAvatar(
                          participant: p,
                          size: AppSpacing.participantAvatarSizeLg,
                          isSelected: isActive,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          p.name.split(' ').first,
                          style: AppTypography.captionMedium.copyWith(
                            color: isActive ? AppColors.primary : AppColors.inkSecondary,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Assignment bottom sheet ───────────────────────────────────────────────────

class _AssignSheet extends StatefulWidget {
  const _AssignSheet({
    required this.item,
    required this.participants,
    required this.current,
  });

  final ReceiptItem item;
  final List<Participant> participants;
  final Map<String, double> current;

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current.keys.toSet();
  }

  void _confirm() {
    if (_selected.isEmpty) {
      Navigator.of(context).pop(<String, double>{});
      return;
    }
    final portion = 1.0 / _selected.length;
    final assignments = {for (final id in _selected) id: portion};
    Navigator.of(context).pop(assignments);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPaddingH,
          AppSpacing.base,
          AppSpacing.screenPaddingH,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.item.name, style: AppTypography.h3),
                      Text(
                        CurrencyFormatter.format(widget.item.totalPrice),
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        setState(() => _selected.clear()),
                    child: const Text('Unassign'),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.base),
            Text(
              _selected.length > 1
                  ? 'Split evenly between ${_selected.length} people'
                  : 'Who gets this?',
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...widget.participants.map((p) {
              final selected = _selected.contains(p.id);
              return CheckboxListTile(
                value: selected,
                onChanged: (val) => setState(() {
                  if (val == true) {
                    _selected.add(p.id);
                  } else {
                    _selected.remove(p.id);
                  }
                }),
                secondary: ParticipantAvatar(
                  participant: p,
                  size: 36,
                  isSelected: selected,
                ),
                title: Text(p.name, style: AppTypography.bodyMedium),
                subtitle: selected && _selected.length > 1
                    ? Text(
                        CurrencyFormatter.format(
                          widget.item.totalPrice / _selected.length,
                        ),
                        style: AppTypography.caption,
                      )
                    : null,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.trailing,
              );
            }),
            const SizedBox(height: AppSpacing.base),
            ElevatedButton(
              onPressed: _selected.isEmpty ? null : _confirm,
              child: Text(
                _selected.length > 1
                    ? 'Split evenly (${CurrencyFormatter.format(widget.item.totalPrice / _selected.length)} each)'
                    : 'Confirm',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _ProgressChip extends StatelessWidget {
  const _ProgressChip({required this.claimed, required this.total});
  final int claimed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final done = claimed == total && total > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: done ? AppColors.successMuted : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        '$claimed / $total',
        style: AppTypography.captionMedium.copyWith(
          color: done ? AppColors.success : AppColors.inkSecondary,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: fraction,
      backgroundColor: AppColors.surfaceVariant,
      valueColor: AlwaysStoppedAnimation<Color>(
        fraction == 1.0 ? AppColors.success : AppColors.primary,
      ),
      minHeight: 3,
    );
  }
}

class _FinalizeBar extends StatelessWidget {
  const _FinalizeBar({
    required this.allDone,
    required this.unclaimedCount,
    required this.onFinalize,
    required this.onSplitRemaining,
  });

  final bool allDone;
  final int unclaimedCount;
  final VoidCallback onFinalize;
  final VoidCallback onSplitRemaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.sm,
        AppSpacing.screenPaddingH,
        AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!allDone && unclaimedCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: OutlinedButton(
                  onPressed: onSplitRemaining,
                  child: Text(
                    'Split $unclaimedCount remaining item${unclaimedCount == 1 ? '' : 's'} evenly',
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: allDone ? onFinalize : null,
              child: Text(allDone ? 'See who owes what' : 'Claim all items first'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Payload to summary screen ─────────────────────────────────────────────────

class SummaryArgs {
  const SummaryArgs({
    required this.hangoutName,
    required this.participants,
    required this.items,
    required this.settlements,
    required this.total,
    required this.payerName,
  });

  final String hangoutName;
  final List<Participant> participants;
  final List<ReceiptItem> items;
  final List<Settlement> settlements;
  final double total;
  final String payerName;
}

// Private alias used in this file.
typedef _SummaryArgs = SummaryArgs;
