import 'package:freezed_annotation/freezed_annotation.dart';
import 'receipt_item.dart';

part 'receipt.freezed.dart';
part 'receipt.g.dart';

@freezed
class Receipt with _$Receipt {
  const factory Receipt({
    required String id,
    required String hangoutId,
    required DateTime scannedAt,
    @Default([]) List<ReceiptItem> items,
    String? imagePath, // local or remote path to receipt image
    String? restaurantName,
    String? currency,
  }) = _Receipt;

  factory Receipt.fromJson(Map<String, dynamic> json) =>
      _$ReceiptFromJson(json);
}

extension ReceiptX on Receipt {
  List<ReceiptItem> get foodItems =>
      items.where((i) => i.type == ReceiptItemType.food).toList();

  List<ReceiptItem> get feeItems =>
      items.where((i) => i.type == ReceiptItemType.fee || i.type == ReceiptItemType.tax).toList();

  List<ReceiptItem> get discountItems =>
      items.where((i) => i.type == ReceiptItemType.discount).toList();

  double get subtotal =>
      foodItems.fold(0.0, (sum, i) => sum + i.totalPrice);

  double get totalFees =>
      feeItems.fold(0.0, (sum, i) => sum + i.totalPrice);

  double get totalDiscounts =>
      discountItems.fold(0.0, (sum, i) => sum + i.totalPrice.abs());

  double get grandTotal => subtotal + totalFees - totalDiscounts;

  int get unassignedCount =>
      foodItems.where((i) => i.isUnassigned).length;

  bool get allAssigned => unassignedCount == 0;

  List<ReceiptItem> get itemsNeedingReview =>
      items.where((i) => i.needsReview).toList();
}
