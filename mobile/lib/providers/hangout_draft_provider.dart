import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/participant.dart';
import '../data/models/receipt_item.dart';

/// In-progress hangout being set up.
/// Holds state across CreateHangout → Scan → Review → Claiming.
class HangoutDraft {
  HangoutDraft({
    required this.name,
    required this.participants,
    required this.payerIndex,
    this.items = const [],
  });

  final String name;
  final List<Participant> participants;
  final int payerIndex; // index into participants who paid
  final List<ReceiptItem> items; // populated after review

  Participant get payer => participants[payerIndex.clamp(0, participants.length - 1)];

  HangoutDraft copyWith({
    String? name,
    List<Participant>? participants,
    int? payerIndex,
    List<ReceiptItem>? items,
  }) =>
      HangoutDraft(
        name: name ?? this.name,
        participants: participants ?? this.participants,
        payerIndex: payerIndex ?? this.payerIndex,
        items: items ?? this.items,
      );
}

class HangoutDraftNotifier extends StateNotifier<HangoutDraft?> {
  HangoutDraftNotifier() : super(null);

  void start({
    required String name,
    required List<Participant> participants,
    required int payerIndex,
  }) {
    state = HangoutDraft(
      name: name,
      participants: participants,
      payerIndex: payerIndex,
    );
  }

  void setItems(List<ReceiptItem> items) {
    if (state == null) return;
    state = state!.copyWith(items: items);
  }

  void clear() => state = null;
}

final hangoutDraftProvider =
    StateNotifierProvider<HangoutDraftNotifier, HangoutDraft?>(
  (ref) => HangoutDraftNotifier(),
);
