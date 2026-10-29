import 'meditation_log_entry.dart';
import 'mood_stats.dart';

/// Numbers for the library and the "Well done" screen. A practice counts on
/// the day it ended.
class MeditationStats {
  const MeditationStats._();

  /// First day of the "last 7 days" window: today and the 6 days before.
  static DateTime weekStart(DateTime now) =>
      MoodStats.addDays(MoodStats.dayOf(now), -6);

  /// Oldest day to load: enough for the streak (see
  /// [MoodStats.historyWindowDays]).
  static DateTime historyStart(DateTime now) =>
      MoodStats.addDays(MoodStats.dayOf(now), 1 - MoodStats.historyWindowDays);

  static Iterable<MeditationLogEntry> _thisWeek(
    Iterable<MeditationLogEntry> logs,
    DateTime now,
  ) {
    final DateTime start = weekStart(now);
    return logs.where((MeditationLogEntry log) => !log.endedAt.isBefore(start));
  }

  /// Seconds practised in the last 7 days, rounded down to whole minutes.
  static int minutesThisWeek(
    Iterable<MeditationLogEntry> logs, {
    required DateTime now,
  }) {
    final int seconds = _thisWeek(logs, now).fold<int>(
      0,
      (int total, MeditationLogEntry log) => total + log.secondsPractised,
    );
    return seconds ~/ 60;
  }

  /// Practices in the last 7 days, finished or not.
  static int sessionsThisWeek(
    Iterable<MeditationLogEntry> logs, {
    required DateTime now,
  }) {
    return _thisWeek(logs, now).length;
  }

  /// Days in a row with at least one practice, ending today (or yesterday if
  /// there is none yet today). The same rule as the mood streak.
  static int streak(
    Iterable<MeditationLogEntry> logs, {
    required DateTime now,
  }) {
    return MoodStats.streak(
      logs.map((MeditationLogEntry log) => log.endedAt),
      now: now,
    );
  }

  /// How many times each practice was finished, by session id.
  static Map<String, int> completedCounts(Iterable<MeditationLogEntry> logs) {
    final Map<String, int> counts = <String, int>{};
    for (final MeditationLogEntry log in logs) {
      if (log.completed) {
        counts[log.sessionId] = (counts[log.sessionId] ?? 0) + 1;
      }
    }
    return counts;
  }
}
