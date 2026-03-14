import 'package:freezed_annotation/freezed_annotation.dart';

part 'settlement.freezed.dart';
part 'settlement.g.dart';

/// A single debt: [fromParticipantId] owes [toParticipantId] [amount].
@freezed
class Settlement with _$Settlement {
  const factory Settlement({
    required String fromParticipantId,
    required String toParticipantId,
    required double amount,
    required String currency,
    @Default(false) bool isPaid,
    DateTime? paidAt,
  }) = _Settlement;

  factory Settlement.fromJson(Map<String, dynamic> json) =>
      _$SettlementFromJson(json);
}
