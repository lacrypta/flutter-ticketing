import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ticket/ticket.dart';

/// The session's scan log.
///
/// In-memory for now. M3 moves this into drift so it survives a crash — at
/// which point it also starts holding attendee names and live ticket codes on
/// disk, which is why the README flags encryption as a decision to make
/// *before* that lands rather than after.
class HistoryController extends Notifier<List<ScanRecord>> {
  @override
  List<ScanRecord> build() => const [];

  void record(ScanRecord record) {
    // One entry per token: re-scanning the same entrada updates its row rather
    // than growing the list, so the count means "people seen", not "taps".
    final existing = state.indexWhere((r) => r.token == record.token);
    if (existing >= 0) {
      final next = [...state];
      next[existing] = record;
      state = next;
    } else {
      state = [record, ...state];
    }
  }

  void clear() => state = const [];

  int get successCount => state.where((r) => r.succeeded).length;
}

final historyProvider = NotifierProvider<HistoryController, List<ScanRecord>>(
  HistoryController.new,
);

/// Successful check-ins, for the header badge and the history summary.
final historySuccessCountProvider = Provider<int>(
  (ref) => ref.watch(historyProvider).where((r) => r.succeeded).length,
);
