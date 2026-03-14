import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/receipt_parser.dart';
import '../../../data/models/receipt_item.dart';
import 'scan_receipt_screen.dart';

// ── Local editable model ──────────────────────────────────────────────────────

class _EditableItem {
  _EditableItem({
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.type,
    required this.ocrConfidence,
    String? id,
  }) : id = id ?? 'item_${DateTime.now().microsecondsSinceEpoch}_${name.hashCode.abs()}';

  final String id;
  String name;
  double unitPrice;
  int quantity;
  ReceiptItemType type;
  double ocrConfidence;

  double get total => unitPrice * quantity;
  bool get needsReview => ocrConfidence < 0.7;

  static _EditableItem fromParsed(ParsedReceiptLine line) => _EditableItem(
        name: line.name,
        unitPrice: line.unitPrice.abs(),
        quantity: line.quantity,
        type: line.type,
        ocrConfidence: line.confidence,
      );

  static _EditableItem blank() => _EditableItem(
        name: '',
        unitPrice: 0,
        quantity: 1,
        type: ReceiptItemType.food,
        ocrConfidence: 1.0,
      );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ReviewReceiptScreen extends StatefulWidget {
  const ReviewReceiptScreen({
    super.key,
    required this.hangoutId,
    required this.payload,
  });

  final String hangoutId;
  final ScanPayload? payload;

  @override
  State<ReviewReceiptScreen> createState() => _ReviewReceiptScreenState();
}

class _ReviewReceiptScreenState extends State<ReviewReceiptScreen> {
  late final List<_EditableItem> _items;
  bool _showReviewBanner = false;

  @override
  void initState() {
    super.initState();
    final parsed = widget.payload?.result?.items ?? [];
    _items = parsed.map(_EditableItem.fromParsed).toList();
    _showReviewBanner = _items.any((i) => i.needsReview);
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  List<_EditableItem> get _foodItems =>
      _items.where((i) => i.type == ReceiptItemType.food).toList();

  List<_EditableItem> get _feeItems => _items
      .where((i) =>
          i.type == ReceiptItemType.fee || i.type == ReceiptItemType.tax)
      .toList();

  List<_EditableItem> get _discountItems =>
      _items.where((i) => i.type == ReceiptItemType.discount).toList();

  double get _subtotal =>
      _foodItems.fold(0.0, (s, i) => s + i.total);

  double get _feesTotal =>
      _feeItems.fold(0.0, (s, i) => s + i.total);

  double get _discountsTotal =>
      _discountItems.fold(0.0, (s, i) => s + i.total.abs());

  double get _grandTotal => _subtotal + _feesTotal - _discountsTotal;

  bool get _canConfirm => _items.isNotEmpty && _items.any((i) => i.type == ReceiptItemType.food);

  // ── Mutations ─────────────────────────────────────────────────────────────

  void _deleteItem(String id) {
    setState(() => _items.removeWhere((i) => i.id == id));
  }

  void _addBlankItem() {
    final blank = _EditableItem.blank();
    setState(() => _items.add(blank));
    // Open edit sheet immediately for the new item.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openEditSheet(blank);
    });
  }

  void _openEditSheet(_EditableItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EditItemSheet(
        item: item,
        onSave: (name, price, qty, type) {
          setState(() {
            item.name = name;
            item.unitPrice = price;
            item.quantity = qty;
            item.type = type;
            item.ocrConfidence = 1.0; // user reviewed — confidence reset
          });
          _showReviewBanner = _items.any((i) => i.needsReview);
        },
      ),
    );
  }

  void _confirm() {
    // Pass items forward to the claiming screen.
    context.push(
      '/hangout/${widget.hangoutId}/claim',
      extra: _items
          .map((i) => ReceiptItem(
                id: i.id,
                receiptId: 'receipt_local',
                name: i.name,
                unitPrice: i.unitPrice,
                quantity: i.quantity,
                type: i.type,
                ocrConfidence: i.ocrConfidence,
              ))
          .toList(),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _items.isEmpty
              ? 'Review receipt'
              : 'Review · ${_items.length} item${_items.length == 1 ? '' : 's'}',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // ── Low-confidence banner ───────────────────────────────────────
          if (_showReviewBanner)
            _ReviewBanner(
              count: _items.where((i) => i.needsReview).length,
              onDismiss: () => setState(() => _showReviewBanner = false),
            ).animate().slideY(begin: -1, end: 0, duration: 300.ms),

          // ── Item list ───────────────────────────────────────────────────
          Expanded(
            child: _items.isEmpty
                ? _EmptyState(onAdd: _addBlankItem)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPaddingH,
                      AppSpacing.base,
                      AppSpacing.screenPaddingH,
                      AppSpacing.base,
                    ),
                    children: [
                      ..._buildSection('Items', _foodItems),
                      if (_feeItems.isNotEmpty)
                        ..._buildSection('Fees & Tax', _feeItems),
                      if (_discountItems.isNotEmpty)
                        ..._buildSection('Discounts', _discountItems),
                      const SizedBox(height: AppSpacing.base),
                      _AddItemButton(onTap: _addBlankItem),
                      const SizedBox(height: AppSpacing.xl),
                      _TotalBreakdown(
                        subtotal: _subtotal,
                        fees: _feesTotal,
                        discounts: _discountsTotal,
                        total: _grandTotal,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
          ),

          // ── Confirm CTA ─────────────────────────────────────────────────
          _ConfirmBar(
            total: _grandTotal,
            canConfirm: _canConfirm,
            onConfirm: _confirm,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSection(String title, List<_EditableItem> items) {
    if (items.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm, top: AppSpacing.xs),
        child: Text(title, style: AppTypography.label),
      ),
      ...items.map(
        (item) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _ItemCard(
            item: item,
            onEdit: () => _openEditSheet(item),
            onDelete: () => _deleteItem(item.id),
          ),
        ),
      ),
    ];
  }
}

// ── Item card ─────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final _EditableItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final needsReview = item.needsReview;

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onEdit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: needsReview
                ? Border.all(color: AppColors.warning, width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              // ── Type indicator dot ────────────────────────────────────
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _typeColor(item.type),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // ── Name + qty ────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name.isEmpty ? 'Unnamed item' : item.name,
                            style: AppTypography.bodyMedium.copyWith(
                              color: item.name.isEmpty
                                  ? AppColors.inkMuted
                                  : AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (needsReview)
                          const Padding(
                            padding: EdgeInsets.only(left: AppSpacing.xs),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: AppColors.warning,
                            ),
                          ),
                      ],
                    ),
                    if (item.quantity > 1)
                      Text(
                        '${item.quantity} × ${CurrencyFormatter.format(item.unitPrice)}',
                        style: AppTypography.caption,
                      ),
                  ],
                ),
              ),

              // ── Price ─────────────────────────────────────────────────
              const SizedBox(width: AppSpacing.sm),
              Text(
                CurrencyFormatter.format(item.total),
                style: AppTypography.amountSmall,
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _typeColor(ReceiptItemType type) => switch (type) {
        ReceiptItemType.food => AppColors.primary,
        ReceiptItemType.fee => AppColors.warning,
        ReceiptItemType.tax => AppColors.warning,
        ReceiptItemType.discount => AppColors.success,
      };
}

// ── Edit bottom sheet ─────────────────────────────────────────────────────────

class _EditItemSheet extends StatefulWidget {
  const _EditItemSheet({required this.item, required this.onSave});

  final _EditableItem item;
  final void Function(String name, double price, int qty, ReceiptItemType type)
      onSave;

  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _qtyCtrl;
  late ReceiptItemType _type;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _priceCtrl = TextEditingController(
      text: widget.item.unitPrice == 0 ? '' : widget.item.unitPrice.toStringAsFixed(2),
    );
    _qtyCtrl = TextEditingController(text: widget.item.quantity.toString());
    _type = widget.item.type;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    widget.onSave(name, price, qty.clamp(1, 99), _type);
    Navigator.of(context).pop();
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
            // Handle (provided by theme)
            const SizedBox(height: AppSpacing.xs),
            Text('Edit item', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.base),

            // ── Name ─────────────────────────────────────────────────────
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(hintText: 'Item name'),
              style: AppTypography.body,
              textCapitalization: TextCapitalization.words,
              autofocus: widget.item.name.isEmpty,
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Price + Qty ───────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _priceCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Price',
                      prefixText: '\$ ',
                    ),
                    style: AppTypography.body,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _qtyCtrl,
                    decoration: const InputDecoration(hintText: 'Qty'),
                    style: AppTypography.body,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.base),

            // ── Type chips ────────────────────────────────────────────────
            Text('Type', style: AppTypography.label),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              children: ReceiptItemType.values.map((t) {
                final selected = _type == t;
                return FilterChip(
                  label: Text(_typeName(t)),
                  selected: selected,
                  onSelected: (_) => setState(() => _type = t),
                  selectedColor: AppColors.primaryMuted,
                  checkmarkColor: AppColors.primary,
                  labelStyle: AppTypography.captionMedium.copyWith(
                    color: selected ? AppColors.primary : AppColors.inkSecondary,
                  ),
                  side: BorderSide(
                    color: selected ? AppColors.primary : AppColors.divider,
                  ),
                  backgroundColor: AppColors.surface,
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Save ──────────────────────────────────────────────────────
            ElevatedButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  static String _typeName(ReceiptItemType t) => switch (t) {
        ReceiptItemType.food => 'Food',
        ReceiptItemType.fee => 'Fee',
        ReceiptItemType.tax => 'Tax',
        ReceiptItemType.discount => 'Discount',
      };
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _ReviewBanner extends StatelessWidget {
  const _ReviewBanner({required this.count, required this.onDismiss});
  final int count;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.sm,
        AppSpacing.screenPaddingH,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$count item${count == 1 ? '' : 's'} may need review — tap to edit.',
              style:
                  AppTypography.caption.copyWith(color: AppColors.ink),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                size: 16, color: AppColors.inkSecondary),
          ),
        ],
      ),
    );
  }
}

class _AddItemButton extends StatelessWidget {
  const _AddItemButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
              color: AppColors.divider, style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded,
                size: 18, color: AppColors.inkSecondary),
            const SizedBox(width: AppSpacing.xs),
            Text('Add item', style: AppTypography.bodyMedium.copyWith(
              color: AppColors.inkSecondary,
            )),
          ],
        ),
      ),
    );
  }
}

class _TotalBreakdown extends StatelessWidget {
  const _TotalBreakdown({
    required this.subtotal,
    required this.fees,
    required this.discounts,
    required this.total,
  });

  final double subtotal;
  final double fees;
  final double discounts;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        children: [
          _Row('Subtotal', subtotal),
          if (fees > 0) _Row('Fees & tax', fees),
          if (discounts > 0) _Row('Discounts', -discounts, isDiscount: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1),
          ),
          Row(
            children: [
              Text('Total', style: AppTypography.h3),
              const Spacer(),
              Text(CurrencyFormatter.format(total), style: AppTypography.amount),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.amount, {this.isDiscount = false});
  final String label;
  final double amount;
  final bool isDiscount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: AppTypography.body.copyWith(
            color: AppColors.inkSecondary,
          )),
          const Spacer(),
          Text(
            isDiscount
                ? '− ${CurrencyFormatter.format(amount.abs())}'
                : CurrencyFormatter.format(amount),
            style: AppTypography.amountSmall.copyWith(
              color: isDiscount ? AppColors.success : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.total,
    required this.canConfirm,
    required this.onConfirm,
  });

  final double total;
  final bool canConfirm;
  final VoidCallback onConfirm;

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
        child: ElevatedButton(
          onPressed: canConfirm ? onConfirm : null,
          child: Text(
            canConfirm
                ? 'Looks good — start claiming'
                : 'Add at least one item',
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 56, color: AppColors.inkMuted),
          const SizedBox(height: AppSpacing.base),
          Text('No items found',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.inkSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Text('OCR found nothing — add items manually.',
              style: AppTypography.caption),
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add item'),
          ),
        ],
      ),
    );
  }
}
