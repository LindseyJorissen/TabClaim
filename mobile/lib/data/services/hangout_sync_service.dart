import 'package:dio/dio.dart';
import '../models/receipt_item.dart';
import '../../presentation/screens/hangout/claiming_screen.dart' show SummaryArgs;

/// Syncs a finalized hangout to the backend in four steps:
///   1. Create hangout + participants
///   2. Create receipt + items
///   3. Assign food items to participants
///   4. Finalize (server computes settlements)
class HangoutSyncService {
  const HangoutSyncService(this._dio);
  final Dio _dio;

  Future<void> sync(SummaryArgs args) async {
    // ── 1. Create hangout ────────────────────────────────────────────────────
    final hangoutResp = await _dio.post<Map<String, dynamic>>(
      '/hangouts',
      data: {
        'name': args.hangoutName,
        'currency': 'USD',
        'participants': args.participants
            .map((p) => {
                  'name': p.name,
                  'colorIndex': p.colorIndex,
                  'isPayer': p.id == args.payerId,
                })
            .toList(),
      },
    );

    final hangoutId = hangoutResp.data!['id'] as String;

    // Map local participant ID → server participant ID (order is preserved).
    final serverParts = hangoutResp.data!['participants'] as List<dynamic>;
    final idMap = <String, String>{
      for (var i = 0; i < args.participants.length; i++)
        args.participants[i].id: serverParts[i]['id'] as String,
    };

    // ── 2. Create receipt + items ────────────────────────────────────────────
    final receiptResp = await _dio.post<Map<String, dynamic>>(
      '/receipts',
      data: {
        'hangoutId': hangoutId,
        'items': args.items
            .map((item) => {
                  'name': item.name,
                  'unitPrice': item.unitPrice,
                  'quantity': item.quantity,
                  'type': item.type.name.toUpperCase(),
                  'ocrConfidence': item.ocrConfidence,
                })
            .toList(),
      },
    );

    final serverItems = receiptResp.data!['items'] as List<dynamic>;

    // ── 3. Assign food items ─────────────────────────────────────────────────
    for (var i = 0; i < args.items.length; i++) {
      final item = args.items[i];
      if (item.type != ReceiptItemType.food || item.assignments.isEmpty) {
        continue;
      }

      final serverItemId = serverItems[i]['id'] as String;
      final serverAssignments = <String, double>{
        for (final e in item.assignments.entries)
          if (idMap.containsKey(e.key)) idMap[e.key]!: e.value,
      };
      if (serverAssignments.isEmpty) continue;

      await _dio.patch<void>(
        '/receipts/items/$serverItemId/assign',
        data: {'assignments': serverAssignments},
      );
    }

    // ── 4. Finalize ──────────────────────────────────────────────────────────
    await _dio.post<void>('/hangouts/$hangoutId/finalize');
  }
}
