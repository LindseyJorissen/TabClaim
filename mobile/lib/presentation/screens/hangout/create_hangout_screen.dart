import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/models/participant.dart';
import '../../widgets/participant_avatar/participant_avatar.dart';

class CreateHangoutScreen extends StatefulWidget {
  const CreateHangoutScreen({super.key});

  @override
  State<CreateHangoutScreen> createState() => _CreateHangoutScreenState();
}

class _CreateHangoutScreenState extends State<CreateHangoutScreen> {
  final _nameController = TextEditingController();
  final _participantController = TextEditingController();
  final List<Participant> _participants = [];
  int _payerIndex = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _participantController.dispose();
    super.dispose();
  }

  void _addParticipant() {
    final name = _participantController.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _participants.add(Participant(
        id: 'p_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        colorIndex: _participants.length,
        isHost: _participants.isEmpty,
      ));
      _participantController.clear();
    });
  }

  void _removeParticipant(int index) {
    setState(() {
      _participants.removeAt(index);
      if (_payerIndex >= _participants.length) {
        _payerIndex = _participants.isEmpty ? 0 : _participants.length - 1;
      }
    });
  }

  bool get _canProceed =>
      _nameController.text.trim().isNotEmpty && _participants.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New hangout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingH,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.base),
                    // ── Hangout name ──────────────────────────────────────
                    Text('What\'s the occasion?', style: AppTypography.h3),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _nameController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Pizza Night, Date Night…',
                      ),
                      style: AppTypography.body,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    // ── Participants ──────────────────────────────────────
                    Text('Who\'s there?', style: AppTypography.h3),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _participantController,
                            decoration: const InputDecoration(
                              hintText: 'Add a name…',
                            ),
                            style: AppTypography.body,
                            textCapitalization: TextCapitalization.words,
                            onSubmitted: (_) => _addParticipant(),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _AddButton(onTap: _addParticipant),
                      ],
                    ),
                    if (_participants.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.base),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _participants.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final p = _participants[index];
                          return _ParticipantRow(
                            participant: p,
                            isPayer: index == _payerIndex,
                            onSetPayer: () =>
                                setState(() => _payerIndex = index),
                            onRemove: () => _removeParticipant(index),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    // ── Who paid? ─────────────────────────────────────────
                    if (_participants.isNotEmpty) ...[
                      Text('Who paid the bill?', style: AppTypography.h3),
                      const SizedBox(height: AppSpacing.sm),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(_participants.length, (i) {
                            final p = _participants[i];
                            return Padding(
                              padding: const EdgeInsets.only(
                                  right: AppSpacing.sm),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _payerIndex = i),
                                child: Column(
                                  children: [
                                    ParticipantAvatar(
                                      participant: p,
                                      isSelected: i == _payerIndex,
                                      size: AppSpacing.participantAvatarSizeLg,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      p.name.split(' ').first,
                                      style: AppTypography.captionMedium,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ],
                ),
              ),
            ),
            // ── Continue CTA ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH,
                AppSpacing.sm,
                AppSpacing.screenPaddingH,
                AppSpacing.xl,
              ),
              child: ElevatedButton(
                onPressed: _canProceed
                    ? () {
                        // TODO: create hangout in state, navigate to scan
                        context.push('/hangout/new/scan');
                      }
                    : null,
                child: const Text('Scan receipt'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.participant,
    required this.isPayer,
    required this.onSetPayer,
    required this.onRemove,
  });
  final Participant participant;
  final bool isPayer;
  final VoidCallback onSetPayer;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: Row(
        children: [
          ParticipantAvatar(participant: participant, size: 36),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(participant.name, style: AppTypography.bodyMedium),
          ),
          if (isPayer)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: AppColors.primaryMuted,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                'Paid',
                style: AppTypography.label.copyWith(color: AppColors.primary),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.close_rounded,
                size: 18, color: AppColors.inkSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
