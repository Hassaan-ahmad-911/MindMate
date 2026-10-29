import '../../Models/break_log.dart';
import '../../services/break_log_service.dart';

/// The short-break history.
class BreakRepository {
  BreakRepository(this._service);

  final BreakLogService _service;

  String newId() => _service.newId();

  Future<void> saveBreak(BreakLogEntry entry) => _service.saveBreak(entry);

  /// Breaks with [start] <= startedAt < [end].
  Future<List<BreakLogEntry>> getBreaksBetween(DateTime start, DateTime end) =>
      _service.getBreaksBetween(start, end);

  /// How many breaks started in the last seven days.
  Future<int> countThisWeek({DateTime? now}) async {
    final DateTime time = now ?? DateTime.now();
    final List<BreakLogEntry> entries = await _service.getBreaksSince(
      BreakStats.weekStart(time),
    );
    return BreakStats.countThisWeek(
      entries.map((BreakLogEntry entry) => entry.startedAt),
      time,
    );
  }
}
