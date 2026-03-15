import '../../data/models/receipt_item.dart';

/// Intermediate representation of a parsed receipt line
/// before it becomes a full [ReceiptItem].
class ParsedReceiptLine {
  const ParsedReceiptLine({
    required this.name,
    required this.unitPrice,
    required this.quantity,
    required this.type,
    required this.confidence,
    this.rawLine = '',
  });

  final String name;
  final double unitPrice;
  final int quantity;
  final ReceiptItemType type;

  /// 0.0–1.0. Low values prompt the user to review this line.
  final double confidence;

  final String rawLine;

  ReceiptItem toReceiptItem({required String receiptId}) {
    return ReceiptItem(
      id: 'item_${DateTime.now().microsecondsSinceEpoch}_${name.hashCode.abs()}',
      receiptId: receiptId,
      name: name,
      unitPrice: unitPrice,
      quantity: quantity,
      type: type,
      ocrConfidence: confidence,
    );
  }
}

/// Parses raw OCR text lines into [ParsedReceiptLine] objects.
///
/// Strategy:
///  1. Skip header / footer lines (table number, address, date, etc.)
///  2. Detect fees, taxes, discounts by keyword matching.
///  3. Parse quantity × price patterns (e.g. "2 x 5.50", "3@ 4.00").
///  4. Extract trailing price from each line.
///  5. Score confidence based on how clean the parse was.
abstract final class ReceiptParser {
  // ── Public API ─────────────────────────────────────────────────────────────

  static List<ParsedReceiptLine> parseLines(List<String> lines) {
    final results = <ParsedReceiptLine>[];

    for (final raw in lines) {
      final line = raw.trim();
      if (_shouldSkip(line)) continue;

      final parsed = _parseLine(line);
      if (parsed != null) results.add(parsed);
    }

    return results;
  }

  // ── Skip heuristics ───────────────────────────────────────────────────────

  static bool _shouldSkip(String line) {
    if (line.length < 3) return true;

    // Pure separators
    if (RegExp(r'^[-=*_\s]+$').hasMatch(line)) return true;

    // Lines with no digits at all (likely headers/addresses)
    if (!line.contains(RegExp(r'\d'))) return true;

    // Common receipt headers/footers
    final skipPatterns = [
      RegExp(r'\b(table|server|cashier|order|receipt|invoice)\b', caseSensitive: false),
      RegExp(r'\b(thank you|thanks|visit|www\.|\.com)\b', caseSensitive: false),
      RegExp(r'\b(tel|phone|address|open|hours)\b', caseSensitive: false),
      RegExp(r'^\d{1,2}[/\-]\d{1,2}[/\-]\d{2,4}'), // date
      RegExp(r'^\d{1,2}:\d{2}'),                      // time
    ];

    for (final p in skipPatterns) {
      if (p.hasMatch(line)) return true;
    }

    return false;
  }

  // ── Line parser ───────────────────────────────────────────────────────────

  static ParsedReceiptLine? _parseLine(String line) {
    // 1. Detect type (fee/tax/discount/food)
    final type = _detectType(line);

    // 2. Extract price
    final price = _extractPrice(line);
    if (price == null || price <= 0) return null;

    // 3. Extract quantity (default 1)
    final qty = _extractQuantity(line);

    // 4. Clean up name
    final name = _extractName(line, price, qty);
    if (name.isEmpty) return null;

    // 5. Score confidence
    final confidence = _scoreConfidence(line, name, price);

    return ParsedReceiptLine(
      name: name,
      unitPrice: type == ReceiptItemType.discount ? -price.abs() : price,
      quantity: qty,
      type: type,
      confidence: confidence,
      rawLine: line,
    );
  }

  // ── Type detection ────────────────────────────────────────────────────────

  static ReceiptItemType _detectType(String line) {
    final lower = line.toLowerCase();

    if (RegExp(
      r'\b(discount|promo|coupon|voucher|off|saving|rebate|reduction)\b',
    ).hasMatch(lower)) {
      return ReceiptItemType.discount;
    }

    if (RegExp(
      r'\b(tax|vat|gst|hst|pst|levy|surcharge)\b',
    ).hasMatch(lower)) {
      return ReceiptItemType.tax;
    }

    if (RegExp(
      r'\b(service\s*charge|service\s*fee|delivery|tip|gratuity|cover\s*charge|handling)\b',
    ).hasMatch(lower)) {
      return ReceiptItemType.fee;
    }

    // "total" / "subtotal" lines — skip, not food
    if (RegExp(r'\b(total|subtotal|amount\s*due|balance)\b').hasMatch(lower)) {
      return ReceiptItemType.fee; // will be filtered as total line
    }

    return ReceiptItemType.food;
  }

  // ── Price extraction ──────────────────────────────────────────────────────

  /// Finds the last price-like token in a line (rightmost = item price).
  static double? _extractPrice(String line) {
    // Match patterns like: 12.50 | 12,50 | $12.50 | -12.50
    final matches = RegExp(
      r'[-]?\$?\s*(\d{1,6}[.,]\d{2})',
    ).allMatches(line).toList();

    if (matches.isEmpty) {
      // Try integer price (e.g. "Coffee 3")
      final intMatch = RegExp(r'\b(\d{1,4})\s*$').firstMatch(line);
      if (intMatch != null) {
        final val = double.tryParse(intMatch.group(1)!);
        // Sanity check: item prices are unlikely to be >9999 or <0.10
        if (val != null && val >= 0.10 && val <= 9999) return val;
      }
      return null;
    }

    // Use rightmost price match
    final last = matches.last;
    final raw = last.group(1)!.replaceAll(',', '.');
    return double.tryParse(raw);
  }

  // ── Quantity extraction ───────────────────────────────────────────────────

  static int _extractQuantity(String line) {
    // "2 x", "2x", "2@", "QTY 2", "2 ×"
    final qtyPattern = RegExp(
      r'(?:^|\s)(\d{1,2})\s*[xX×@]',
    );
    final match = qtyPattern.firstMatch(line);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 1;
    }

    // "QTY: 3" / "QTY 3"
    final qtyLabel = RegExp(
      r'\bqty\s*:?\s*(\d{1,2})\b',
      caseSensitive: false,
    ).firstMatch(line);
    if (qtyLabel != null) {
      return int.tryParse(qtyLabel.group(1)!) ?? 1;
    }

    return 1;
  }

  // ── Name extraction ───────────────────────────────────────────────────────

  static String _extractName(String line, double price, int qty) {
    var name = line;

    // Remove trailing price (last occurrence)
    name = name.replaceAll(RegExp(r'\$?\s*\d{1,6}[.,]\d{2}\s*$'), '').trim();

    // Remove leading quantity patterns
    name = name.replaceAll(RegExp(r'^\d{1,2}\s*[xX×@]\s*'), '').trim();
    name = name.replaceAll(RegExp(r'^qty\s*:?\s*\d{1,2}\s*', caseSensitive: false), '').trim();

    // Remove currency symbols and stray punctuation at ends
    name = name.replaceAll(RegExp(r'^[\$€£¥\s]+|[\s\-\.]+$'), '').trim();

    // Collapse multiple spaces
    name = name.replaceAll(RegExp(r'\s{2,}'), ' ');

    // Title-case if all caps (common in OCR output from thermal printers)
    if (name == name.toUpperCase() && name.length > 2) {
      name = _toTitleCase(name);
    }

    return name;
  }

  // ── Confidence scoring ────────────────────────────────────────────────────

  static double _scoreConfidence(String line, String name, double price) {
    double score = 1.0;

    // Name too short after cleaning
    if (name.length < 2) score -= 0.4;

    // Name has leftover digits/symbols (suggests bad parse)
    if (RegExp(r'\d{3,}').hasMatch(name)) score -= 0.2;
    if (name.contains(RegExp(r'[|\\^~`]'))) score -= 0.15;

    // Price looks suspiciously high for a single item
    if (price > 500) score -= 0.25;

    // Short line overall (might be a code / SKU / table number)
    if (line.length < 8) score -= 0.2;

    return score.clamp(0.0, 1.0);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _toTitleCase(String s) {
    return s.toLowerCase().replaceAllMapped(
      RegExp(r'\b\w'),
      (m) => m.group(0)!.toUpperCase(),
    );
  }
}
