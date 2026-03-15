import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/hangout_summary.dart';
import '../data/repositories/hangout_history_repository.dart';

final _repo = HangoutHistoryRepository();

class HangoutHistoryNotifier
    extends AsyncNotifier<List<HangoutSummary>> {
  @override
  Future<List<HangoutSummary>> build() => _repo.loadAll();

  Future<void> save(HangoutSummary summary) async {
    await _repo.save(summary);
    state = AsyncData(await _repo.loadAll());
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((s) => s.id != id).toList());
  }
}

final hangoutHistoryProvider =
    AsyncNotifierProvider<HangoutHistoryNotifier, List<HangoutSummary>>(
  HangoutHistoryNotifier.new,
);
