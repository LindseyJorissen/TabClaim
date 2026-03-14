import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hangout_summary.dart';

/// Persists completed hangouts to SharedPreferences.
class HangoutHistoryRepository {
  static const _key = 'hangout_history_v1';

  Future<List<HangoutSummary>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) {
          try {
            return HangoutSummary.fromJson(
                jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<HangoutSummary>()
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // newest first
  }

  Future<void> save(HangoutSummary summary) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];

    // Replace if same id already exists, otherwise prepend.
    final updated = raw.where((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return m['id'] != summary.id;
      } catch (_) {
        return true;
      }
    }).toList();

    updated.insert(0, jsonEncode(summary.toJson()));

    // Keep at most 50 hangouts.
    await prefs.setStringList(_key, updated.take(50).toList());
  }

  Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final updated = raw.where((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return m['id'] != id;
      } catch (_) {
        return true;
      }
    }).toList();
    await prefs.setStringList(_key, updated);
  }
}
