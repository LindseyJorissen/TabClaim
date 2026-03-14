import 'package:freezed_annotation/freezed_annotation.dart';

part 'receipt_item.freezed.dart';
part 'receipt_item.g.dart';

/// How an item was scanned / what kind it is.
enum ReceiptItemType {
  food,       // regular line item
  fee,        // service charge, delivery fee, etc.
  discount,   // promo, coupon
  tax,        // GST, VAT, etc.
}

/// A single claimable item from a receipt.
///
/// Groups: If quantity > 1 the item can be expanded into
/// [quantity] individual sub-items. Each sub-item can be
/// assigned to a different participant.
@freezed
class ReceiptItem with _$ReceiptItem {
  const factory ReceiptItem({
    required String id,
    required String receiptId,
    required String name,
    required double unitPrice, // price per unit
    @Default(1) int quantity,
    @Default(ReceiptItemType.food) ReceiptItemType type,

    // Assignments: participantId → portion (0.0–1.0)
    // e.g. {"alice": 0.5, "bob": 0.5} for a split
    @Default({}) Map<String, double> assignments,

    // Expanded sub-items for quantity > 1 grouping.
    // null means not yet expanded (show as group).
    List<ReceiptItem>? subItems,

    @Default(false) bool isExpanded,

    // OCR confidence 0.0–1.0. Low = prompt user to review.
    @Default(1.0) double ocrConfidence,
  }) = _ReceiptItem;

  factory ReceiptItem.fromJson(Map<String, dynamic> json) =>
      _$ReceiptItemFromJson(json);
}

extension ReceiptItemX on ReceiptItem {
  double get totalPrice => unitPrice * quantity;

  bool get isFullyAssigned {
    if (assignments.isEmpty) return false;
    final total = assignments.values.fold(0.0, (a, b) => a + b);
    return (total - 1.0).abs() < 0.001;
  }

  bool get isUnassigned => assignments.isEmpty;

  /// Returns true if this item needs OCR review.
  bool get needsReview => ocrConfidence < 0.7;
}
