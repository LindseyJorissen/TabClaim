import 'package:freezed_annotation/freezed_annotation.dart';
import 'participant.dart';
import 'receipt.dart';
import 'settlement.dart';

part 'hangout.freezed.dart';
part 'hangout.g.dart';

enum HangoutStatus {
  setup,      // adding participants, payer
  scanning,   // scanning receipt
  reviewing,  // OCR review
  claiming,   // assigning items
  finalized,  // totals locked in
}

@freezed
class Hangout with _$Hangout {
  const factory Hangout({
    required String id,
    required String name,
    required DateTime createdAt,
    @Default(HangoutStatus.setup) HangoutStatus status,
    @Default([]) List<Participant> participants,
    @Default([]) List<Receipt> receipts,
    @Default([]) List<Settlement> settlements,
    String? payerId,    // which participant paid
    String? currency,
    String? venueNote,  // e.g. "Pizza Night 🍕"
  }) = _Hangout;

  factory Hangout.fromJson(Map<String, dynamic> json) =>
      _$HangoutFromJson(json);
}

extension HangoutX on Hangout {
  Participant? get payer =>
      payerId == null ? null : participants.firstWhere(
        (p) => p.id == payerId,
        orElse: () => participants.first,
      );

  double get grandTotal =>
      receipts.fold(0.0, (sum, r) => sum + r.grandTotal);

  int get totalItemCount =>
      receipts.fold(0, (sum, r) => sum + r.foodItems.length);

  int get unassignedItemCount =>
      receipts.fold(0, (sum, r) => sum + r.unassignedCount);

  bool get allItemsAssigned => unassignedItemCount == 0;

  bool get isFinalized => status == HangoutStatus.finalized;
}
