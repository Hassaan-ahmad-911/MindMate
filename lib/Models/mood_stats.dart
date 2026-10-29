import 'mood_catalog.dart';
import 'mood_model.dart';

/// Mood calculations shared by the mood module and the home dashboard.
/// Everything here uses `valence`, never `intensity`.
class MoodStats {
  const MoodStats._();

  /// How many days of entries the dashboard, Mood home and Insights load.
  /// Streaks are counted within this window.
  static const int historyWindowDays = 90;

  /// Midnight at the start of [date]'s day.
  static DateTime dayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  static bool isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  /// Average valence of [entries]. Null when there are none.
  static double? averageValence(Iterable<MoodModel> entries) {
    int count = 0;
    int total = 0;
    for (final MoodModel entry in entries) {
      count += 1;
      total += entry.valence;
    }
    return count == 0 ? null : total / count;
  }

  /// Day score: the average valence of each day's entries, keyed by day.
  static Map<DateTime, double> dayScores(Iterable<MoodModel> entries) {
    final Map<DateTime, List<int>> byDay = <DateTime, List<int>>{};
    for (final MoodModel entry in entries) {
      byDay.putIfAbsent(dayOf(entry.date), () => <int>[]).add(entry.valence);
    }
    return byDay.map(
      (DateTime day, List<int> values) => MapEntry<DateTime, double>(
        day,
        values.reduce((int a, int b) => a + b) / values.length,
      ),
    );
  }

  /// Calendar dot and week circle colour for a day score.
  static MoodGroup groupForDayScore(double score) {
    if (score > 0.5) {
      return MoodGroup.good;
    }
    if (score < -0.5) {
      return MoodGroup.hard;
    }
    return MoodGroup.between;
  }

  static bool isGoodDay(double score) => score > 0;

  /// Days in a row with at least one entry, ending today, or yesterday when
  /// nothing is logged yet today.
  static int streak(Iterable<DateTime> entryDates, {required DateTime now}) {
    final Set<DateTime> days = entryDates.map(dayOf).toSet();
    final DateTime today = dayOf(now);

    DateTime cursor;
    if (days.contains(today)) {
      cursor = today;
    } else if (days.contains(addDays(today, -1))) {
      cursor = addDays(today, -1);
    } else {
      return 0;
    }

    int count = 0;
    while (days.contains(cursor)) {
      count += 1;
      cursor = addDays(cursor, -1);
    }
    return count;
  }

  /// A day score from -2..2 shown out of 10 on the home dashboard.
  static double scoreOutOfTen(double average) =>
      ((average + 2) / 4 * 10).clamp(0, 10).toDouble();

  /// The [limit] most logged moods, most frequent first.
  static List<MapEntry<String, int>> topMoods(
    Iterable<MoodModel> entries, {
    int limit = 5,
  }) {
    final Map<String, int> counts = <String, int>{};
    for (final MoodModel entry in entries) {
      counts[entry.mood] = (counts[entry.mood] ?? 0) + 1;
    }
    return _top(counts, limit, _moodOrder);
  }

  /// The [limit] most mentioned factors, most frequent first.
  static List<MapEntry<String, int>> topFactors(
    Iterable<MoodModel> entries, {
    int limit = 4,
  }) {
    return _top(_factorCounts(entries), limit, _factorOrder);
  }

  /// "{n} of your {m} harder entries {periodPhrase} mentioned {factor}."
  ///
  /// Shown only when one factor appears in at least 2 hard entries and in at
  /// least 60% of the hard entries. [periodPhrase] is e.g. "this week".
  static String? patternSentence(
    Iterable<MoodModel> entries, {
    required String periodPhrase,
  }) {
    final List<MoodModel> hard = entries
        .where((MoodModel entry) => entry.group == MoodGroup.hard)
        .toList(growable: false);
    if (hard.length < 2) {
      return null;
    }

    final List<MapEntry<String, int>> ranked = _top(
      _factorCounts(hard),
      1,
      _factorOrder,
    );
    if (ranked.isEmpty) {
      return null;
    }

    final String factor = ranked.first.key;
    final int count = ranked.first.value;
    if (count < 2 || count / hard.length < 0.6) {
      return null;
    }

    return '$count of your ${hard.length} harder entries $periodPhrase '
        'mentioned ${factor.toLowerCase()}.';
  }

  /// One point per day for [days] days ending on [lastDay]. Days with no
  /// entry have a null score.
  static List<MoodDayPoint> dailyPoints(
    Iterable<MoodModel> entries, {
    required DateTime lastDay,
    required int days,
  }) {
    final DateTime end = dayOf(lastDay);
    final Map<DateTime, double> scores = dayScores(entries);
    final Map<DateTime, MoodModel> latest = <DateTime, MoodModel>{};
    for (final MoodModel entry in entries) {
      final DateTime day = dayOf(entry.date);
      final MoodModel? current = latest[day];
      if (current == null || entry.date.isAfter(current.date)) {
        latest[day] = entry;
      }
    }

    return List<MoodDayPoint>.generate(days, (int index) {
      final DateTime day = addDays(end, index - days + 1);
      return MoodDayPoint(
        day: day,
        score: scores[day],
        latestMood: latest[day]?.mood,
      );
    });
  }

  static Map<String, int> _factorCounts(Iterable<MoodModel> entries) {
    final Map<String, int> counts = <String, int>{};
    for (final MoodModel entry in entries) {
      for (final String factor in entry.factors.toSet()) {
        counts[factor] = (counts[factor] ?? 0) + 1;
      }
    }
    return counts;
  }

  static int _moodOrder(String name) {
    final int index = MoodCatalog.moods.indexWhere(
      (MoodDefinition mood) => mood.name == name,
    );
    return index < 0 ? MoodCatalog.moods.length : index;
  }

  static int _factorOrder(String name) {
    final int index = MoodCatalog.factors.indexOf(name);
    return index < 0 ? MoodCatalog.factors.length : index;
  }

  /// Highest count first; ties keep catalog order.
  static List<MapEntry<String, int>> _top(
    Map<String, int> counts,
    int limit,
    int Function(String key) order,
  ) {
    final List<MapEntry<String, int>> sorted = counts.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) {
        final int byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : order(a.key).compareTo(order(b.key));
      });
    return sorted.take(limit).toList(growable: false);
  }
}

/// One day on the Insights chart.
class MoodDayPoint {
  const MoodDayPoint({
    required this.day,
    required this.score,
    required this.latestMood,
  });

  final DateTime day;

  /// Day score, or null when nothing was logged.
  final double? score;

  /// The day's most recent mood, shown on the latest point.
  final String? latestMood;
}
