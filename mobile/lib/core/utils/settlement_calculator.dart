import '../../data/models/hangout.dart';
import '../../data/models/participant.dart';
import '../../data/models/receipt.dart';
import '../../data/models/receipt_item.dart';
import '../../data/models/settlement.dart';

/// Calculates who owes whom based on item assignments.
///
/// Algorithm:
/// 1. For each food item, split cost by assignment proportions.
/// 2. Fees and taxes are split evenly across all participants.
/// 3. Discounts are spread evenly and reduce everyone's share.
/// 4. Compute net balance for each participant (negative = owes payer).
/// 5. Simplify into minimum number of settlements.
abstract final class SettlementCalculator {
  /// Returns a [Map<participantId, double>] of each person's total share.
  static Map<String, double> computeShares(Hangout hangout) {
    final shares = <String, double>{};
    final participantIds = hangout.participants.map((p) => p.id).toList();

    // Initialize everyone at 0.
    for (final id in participantIds) {
      shares[id] = 0.0;
    }

    for (final receipt in hangout.receipts) {
      _applyFoodItems(receipt, shares);
      _applyFeesAndTax(receipt, shares, participantIds);
      _applyDiscounts(receipt, shares, participantIds);
    }

    return shares;
  }

  /// Returns simplified list of who owes whom.
  /// The payer is the creditor; everyone else pays them.
  static List<Settlement> computeSettlements(
    Hangout hangout, {
    String currency = 'USD',
  }) {
    if (hangout.payerId == null) return [];

    final shares = computeShares(hangout);
    final settlements = <Settlement>[];

    for (final participant in hangout.participants) {
      if (participant.id == hangout.payerId) continue;
      final amount = shares[participant.id] ?? 0.0;
      if (amount <= 0.005) continue; // ignore sub-cent amounts

      settlements.add(Settlement(
        fromParticipantId: participant.id,
        toParticipantId: hangout.payerId!,
        amount: _round(amount),
        currency: currency,
      ));
    }

    return settlements;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static void _applyFoodItems(Receipt receipt, Map<String, double> shares) {
    for (final item in receipt.foodItems) {
      if (item.assignments.isEmpty) continue;

      final total = item.totalPrice;
      for (final entry in item.assignments.entries) {
        shares[entry.key] = (shares[entry.key] ?? 0) + total * entry.value;
      }

      // Handle sub-items if expanded.
      if (item.isExpanded && item.subItems != null) {
        for (final sub in item.subItems!) {
          _applyFoodItems(
            Receipt(
              id: receipt.id,
              hangoutId: receipt.hangoutId,
              scannedAt: receipt.scannedAt,
              items: [sub],
            ),
            shares,
          );
        }
      }
    }
  }

  static void _applyFeesAndTax(
    Receipt receipt,
    Map<String, double> shares,
    List<String> participantIds,
  ) {
    final feeTotal = receipt.totalFees;
    if (feeTotal == 0 || participantIds.isEmpty) return;
    final perPerson = feeTotal / participantIds.length;
    for (final id in participantIds) {
      shares[id] = (shares[id] ?? 0) + perPerson;
    }
  }

  static void _applyDiscounts(
    Receipt receipt,
    Map<String, double> shares,
    List<String> participantIds,
  ) {
    final discountTotal = receipt.totalDiscounts;
    if (discountTotal == 0 || participantIds.isEmpty) return;
    final perPerson = discountTotal / participantIds.length;
    for (final id in participantIds) {
      shares[id] = (shares[id] ?? 0) - perPerson;
    }
  }

  static double _round(double value) =>
      (value * 100).roundToDouble() / 100;
}
