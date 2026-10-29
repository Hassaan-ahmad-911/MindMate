import 'assessment_definition.dart';
import 'assessment_result.dart';
import 'assessment_rules.dart';
import 'break_log.dart';
import 'journal_model.dart';
import 'meditation_log_entry.dart';
import 'mood_catalog.dart';
import 'mood_model.dart';
import 'mood_stats.dart';
import 'report_period.dart';

/// One row of "Your mood on days when you…".
class ComparisonRow {
  const ComparisonRow({
    required this.label,
    required this.onAverage,
    required this.otherAverage,
    required this.onDays,
    required this.otherDays,
  });

  final String label;

  /// Average day score (-2 to 2) on days with the activity.
  final double onAverage;
  final double otherAverage;
  final int onDays;
  final int otherDays;
}

/// "Before and after practice".
class BeforeAfter {
  const BeforeAfter({
    required this.before,
    required this.after,
    required this.better,
    required this.count,
  });

  /// Average feeling, 1 to 5.
  final double before;
  final double after;

  /// Practices where the feeling after was higher than before.
  final int better;
  final int count;
}

/// "On harder days".
class HarderDays {
  const HarderDays({
    required this.hardDays,
    required this.topFactors,
    required this.sentenceFactor,
    required this.sentenceCount,
  });

  final int hardDays;

  /// Up to 3 factors with the number of hard days they came up on.
  final List<MapEntry<String, int>> topFactors;

  /// The factor for "{Factor} came up on {x} of your {n} harder days", or
  /// null when it does not qualify (n >= 2 and x >= 60% of n).
  final String? sentenceFactor;
  final int sentenceCount;

  String? get sentence => sentenceFactor == null
      ? null
      : '$sentenceFactor came up on $sentenceCount of your $hardDays '
            'harder days.';
}

enum HighlightIcon { up, heart, leaf, moon, factor, clipboard, pen }

class Highlight {
  const Highlight(this.icon, this.text);

  final HighlightIcon icon;
  final String text;
}

/// The totals of one period, used by the tiles and the highlight rules.
class PeriodStats {
  const PeriodStats({
    required this.moodDays,
    required this.goodDays,
    required this.hardDays,
    required this.practiceDays,
    required this.calmMinutes,
    required this.journalEntries,
    required this.breaks,
    required this.checkIns,
    required this.harder,
  });

  final int moodDays;
  final int goodDays;
  final int hardDays;
  final int practiceDays;
  final int calmMinutes;
  final int journalEntries;

  /// Completed short breaks.
  final int breaks;
  final int checkIns;
  final HarderDays? harder;

  bool get hasAnyData =>
      moodDays > 0 ||
      calmMinutes > 0 ||
      practiceDays > 0 ||
      journalEntries > 0 ||
      breaks > 0 ||
      checkIns > 0;
}

/// One bar of "Week by week".
class WeekAverage {
  const WeekAverage({
    required this.label,
    required this.start,
    required this.average,
  });

  final String label;
  final DateTime start;

  /// Null ("—", no bar) when the week has fewer than 2 mood days.
  final double? average;
}

/// The journal tone card.
class ToneSummary {
  const ToneSummary({
    required this.entries,
    required this.light,
    required this.mixed,
    required this.heavy,
    required this.mostly,
    required this.topTopics,
  });

  final int entries;
  final int light;
  final int mixed;
  final int heavy;

  /// The most common tone, or null when no entry has one.
  final JournalTone? mostly;
  final List<MapEntry<String, int>> topTopics;
}

/// The mood section of the PDF.
class MoodSummary {
  const MoodSummary({
    required this.daysLogged,
    required this.totalDays,
    required this.good,
    required this.between,
    required this.hard,
    required this.topMoods,
    required this.hardFactors,
    required this.dailyScores,
  });

  final int daysLogged;
  final int totalDays;
  final int good;
  final int between;
  final int hard;
  final List<String> topMoods;
  final List<MapEntry<String, int>> hardFactors;

  /// One value per day, null when nothing was logged.
  final List<double?> dailyScores;
}

/// The practice and activity section of the PDF.
class PracticeSummary {
  const PracticeSummary({
    required this.sessions,
    required this.minutes,
    required this.feelBefore,
    required this.feelAfter,
    required this.breaks,
    required this.journalEntries,
  });

  final int sessions;
  final int minutes;
  final double? feelBefore;
  final double? feelAfter;
  final int? breaks;
  final int? journalEntries;
}

/// One row of the PDF's check-in table. Never holds answers; only the
/// question 9 flag, shown when the user shares the PDF.
class CheckInRow {
  const CheckInRow({
    required this.scale,
    required this.name,
    required this.date,
    required this.score,
    required this.range,
    required this.previous,
    required this.item9Positive,
  });

  final String scale;
  final String name;
  final DateTime date;
  final String score;
  final String range;

  /// "14 (24 Sep)" or "None".
  final String previous;
  final bool item9Positive;
}

/// Every new calculation for Reports. Pure Dart. Day score, day group, top
/// moods and factors come from [MoodStats]; ranges and scores from the
/// assessment models.
class ReportCalculator {
  const ReportCalculator._();

  /// The days a comparison row needs on each side.
  static const int minDaysPerSide = 3;
  static const int minBeforeAfter = 3;
  static const int windowDays = 30;
  static const int practiceSeconds = 60;
  static const int maxHighlights = 3;

  // Days.

  /// The last 30 days ending on [lastDay]: [start, end).
  static (DateTime, DateTime) window(DateTime lastDay) {
    final DateTime end = MoodStats.addDays(MoodStats.dayOf(lastDay), 1);
    return (MoodStats.addDays(end, -windowDays), end);
  }

  static List<T> within<T>(
    Iterable<T> items,
    DateTime Function(T) dateOf,
    DateTime start,
    DateTime end,
  ) {
    return items.where((T item) {
      final DateTime d = dateOf(item);
      return !d.isBefore(start) && d.isBefore(end);
    }).toList();
  }

  static Map<DateTime, MoodGroup> dayGroups(Iterable<MoodModel> moods) {
    return MoodStats.dayScores(moods).map(
      (DateTime day, double score) =>
          MapEntry<DateTime, MoodGroup>(day, MoodStats.groupForDayScore(score)),
    );
  }

  /// Days with a practice of at least a minute.
  static Set<DateTime> practiceDays(Iterable<MeditationLogEntry> sessions) => {
    for (final MeditationLogEntry s in sessions)
      if (s.secondsPractised >= practiceSeconds) MoodStats.dayOf(s.startedAt),
  };

  static Set<DateTime> journalDays(Iterable<JournalSummary> entries) => {
    for (final JournalSummary e in entries) MoodStats.dayOf(e.createdAt),
  };

  /// Days with a completed break.
  static Set<DateTime> breakDays(Iterable<BreakLogEntry> breaks) => {
    for (final BreakLogEntry b in breaks)
      if (b.completed) MoodStats.dayOf(b.startedAt),
  };

  static int calmMinutes(Iterable<MeditationLogEntry> sessions) =>
      sessions.fold<int>(
        0,
        (int sum, MeditationLogEntry s) => sum + s.secondsPractised,
      ) ~/
      60;

  // What helped.

  /// "Your mood on days when you…": each activity whose module is
  /// available (a non-null set), only if both sides have 3+ mood days.
  static List<ComparisonRow> comparisonRows({
    required Iterable<MoodModel> moods,
    Set<DateTime>? practiced,
    Set<DateTime>? journaled,
    Set<DateTime>? tookBreak,
  }) {
    final Map<DateTime, double> scores = MoodStats.dayScores(moods);
    final List<ComparisonRow> rows = <ComparisonRow>[];
    void add(String label, Set<DateTime>? days) {
      if (days == null) {
        return;
      }
      final List<double> on = <double>[];
      final List<double> other = <double>[];
      scores.forEach((DateTime day, double score) {
        (days.contains(day) ? on : other).add(score);
      });
      if (on.length < minDaysPerSide || other.length < minDaysPerSide) {
        return;
      }
      rows.add(
        ComparisonRow(
          label: label,
          onAverage: _mean(on),
          otherAverage: _mean(other),
          onDays: on.length,
          otherDays: other.length,
        ),
      );
    }

    add('Practised', practiced);
    add('Wrote in your journal', journaled);
    add('Took a short break', tookBreak);
    return rows;
  }

  /// Null with fewer than 3 practices that have both feelings.
  static BeforeAfter? beforeAfter(Iterable<MeditationLogEntry> sessions) {
    final List<MeditationLogEntry> rated = sessions
        .where(
          (MeditationLogEntry s) => s.feelBefore != null && s.feelAfter != null,
        )
        .toList();
    if (rated.length < minBeforeAfter) {
      return null;
    }
    return BeforeAfter(
      before: _mean(
        rated.map((MeditationLogEntry s) => s.feelBefore!.toDouble()),
      ),
      after: _mean(
        rated.map((MeditationLogEntry s) => s.feelAfter!.toDouble()),
      ),
      better: rated
          .where((MeditationLogEntry s) => s.feelAfter! > s.feelBefore!)
          .length,
      count: rated.length,
    );
  }

  /// Factors across Hard days, counted once per day. Null with no Hard days.
  static HarderDays? harderDays(Iterable<MoodModel> moods) {
    final Map<DateTime, MoodGroup> groups = dayGroups(moods);
    final Map<DateTime, Set<String>> factorsByDay = <DateTime, Set<String>>{};
    for (final MoodModel m in moods) {
      final DateTime day = MoodStats.dayOf(m.date);
      if (groups[day] == MoodGroup.hard) {
        factorsByDay.putIfAbsent(day, () => <String>{}).addAll(m.factors);
      }
    }
    final int n = groups.values
        .where((MoodGroup g) => g == MoodGroup.hard)
        .length;
    if (n == 0) {
      return null;
    }
    // One stand-in entry per hard day, so MoodStats counts days, not entries.
    final List<MapEntry<String, int>> top = MoodStats.topFactors(
      factorsByDay.entries.map(
        (MapEntry<DateTime, Set<String>> e) => MoodModel(
          mood: 'Okay',
          valence: 0,
          intensity: MoodCatalog.mild,
          factors: e.value.toList(),
          note: '',
          date: e.key,
        ),
      ),
      limit: 3,
    );
    String? factor;
    int count = 0;
    if (top.isNotEmpty && n >= 2 && top.first.value >= 0.6 * n) {
      factor = top.first.key;
      count = top.first.value;
    }
    return HarderDays(
      hardDays: n,
      topFactors: top,
      sentenceFactor: factor,
      sentenceCount: count,
    );
  }

  // Periods.

  /// Totals for one period. Pass only that period's items. A null list
  /// means the module is missing and counts as nothing.
  static PeriodStats stats({
    Iterable<MoodModel>? moods,
    Iterable<MeditationLogEntry>? sessions,
    Iterable<JournalSummary>? journal,
    Iterable<BreakLogEntry>? breaks,
    Iterable<AssessmentSummary>? checkIns,
  }) {
    final Map<DateTime, MoodGroup> groups = dayGroups(
      moods ?? const <MoodModel>[],
    );
    return PeriodStats(
      moodDays: groups.length,
      goodDays: groups.values
          .where((MoodGroup g) => g == MoodGroup.good)
          .length,
      hardDays: groups.values
          .where((MoodGroup g) => g == MoodGroup.hard)
          .length,
      practiceDays: practiceDays(
        sessions ?? const <MeditationLogEntry>[],
      ).length,
      calmMinutes: calmMinutes(sessions ?? const <MeditationLogEntry>[]),
      journalEntries: (journal ?? const <JournalSummary>[]).length,
      breaks: (breaks ?? const <BreakLogEntry>[])
          .where((BreakLogEntry b) => b.completed)
          .length,
      checkIns: (checkIns ?? const <AssessmentSummary>[]).length,
      harder: harderDays(moods ?? const <MoodModel>[]),
    );
  }

  /// The blue card's lines, at most 3, in rule order. Empty when nothing
  /// was logged at all (the card then invites logging a mood).
  static List<Highlight> highlights(
    PeriodStats now,
    PeriodStats? before,
    ReportKind kind,
  ) {
    if (!now.hasAnyData) {
      return const <Highlight>[];
    }
    final String unit = kind == ReportKind.week ? 'week' : 'month';
    final List<Highlight> lines = <Highlight>[];
    final int prevGood = before?.goodDays ?? 0;
    if (now.goodDays > prevGood) {
      lines.add(
        Highlight(
          HighlightIcon.up,
          'More good days than last $unit: ${now.goodDays}, up from $prevGood',
        ),
      );
    } else if (now.goodDays < prevGood && now.hardDays >= 3) {
      lines.add(
        Highlight(
          HighlightIcon.heart,
          'A harder $unit: ${now.hardDays} hard days. Be gentle with '
          'yourself.',
        ),
      );
    }
    if (now.practiceDays >= 1) {
      lines.add(
        Highlight(
          HighlightIcon.leaf,
          'You practised on ${_plural(now.practiceDays, 'day')}, '
          '${now.calmMinutes} minutes in all',
        ),
      );
    }
    final String? factor = now.harder?.sentenceFactor;
    if (factor != null) {
      lines.add(
        Highlight(
          factor == 'Night shift' ? HighlightIcon.moon : HighlightIcon.factor,
          '${factor == 'Night shift' ? 'Night shifts' : factor} came up on '
          'most of your harder days',
        ),
      );
    }
    if (now.checkIns >= 1) {
      lines.add(
        Highlight(
          HighlightIcon.clipboard,
          'You completed ${_plural(now.checkIns, 'check-in')}',
        ),
      );
    }
    if (now.journalEntries >= 1) {
      lines.add(
        Highlight(
          HighlightIcon.pen,
          'You wrote ${_plural(now.journalEntries, 'journal entry', 'journal entries')}',
        ),
      );
    }
    return lines.take(maxHighlights).toList();
  }

  /// "↑ 12 from last week", "↓ 3 from last week", "Same as last week", or
  /// null when the previous period has no data at all.
  static String? changeLabel(
    int now,
    int before, {
    required bool previousHasData,
    required ReportKind kind,
  }) {
    if (!previousHasData) {
      return null;
    }
    final String unit = kind == ReportKind.week ? 'week' : 'month';
    if (now == before) {
      return 'Same as last $unit';
    }
    final String arrow = now > before ? '↑' : '↓';
    return '$arrow ${(now - before).abs()} from last $unit';
  }

  /// The average day score of each Monday-to-Sunday week that overlaps
  /// [month], counting only the month's own days.
  static List<WeekAverage> weekByWeek(
    Iterable<MoodModel> moods,
    ReportPeriod month,
  ) {
    final Map<DateTime, double> scores = MoodStats.dayScores(moods);
    final List<WeekAverage> weeks = <WeekAverage>[];
    DateTime start = ReportPeriod.weekStart(month.start);
    int i = 1;
    while (start.isBefore(month.end)) {
      final DateTime end = MoodStats.addDays(start, 7);
      final List<double> values = <double>[
        for (final MapEntry<DateTime, double> e in scores.entries)
          if (!e.key.isBefore(start) &&
              e.key.isBefore(end) &&
              month.contains(e.key))
            e.value,
      ];
      weeks.add(
        WeekAverage(
          label: 'Week $i',
          start: start,
          average: values.length < 2 ? null : _mean(values),
        ),
      );
      start = end;
      i += 1;
    }
    return weeks;
  }

  /// "+0.6", "−0.4", "0.0".
  static String signed(double value) {
    final String n = value.abs().toStringAsFixed(1);
    if (value > 0.049) {
      return '+$n';
    }
    if (value < -0.049) {
      return '−$n';
    }
    return '0.0';
  }

  // Check-ins and writing.

  static ToneSummary? toneSummary(Iterable<JournalSummary> entries) {
    final List<JournalSummary> list = entries.toList();
    if (list.isEmpty) {
      return null;
    }
    int count(JournalTone t) =>
        list.where((JournalSummary e) => e.tone == t).length;
    final int light = count(JournalTone.light);
    final int mixed = count(JournalTone.mixed);
    final int heavy = count(JournalTone.heavy);
    JournalTone? mostly;
    int best = 0;
    // Ties go to Mixed, then Heavy, then Light, as on the journal insights.
    for (final MapEntry<JournalTone, int> e in <MapEntry<JournalTone, int>>[
      MapEntry<JournalTone, int>(JournalTone.mixed, mixed),
      MapEntry<JournalTone, int>(JournalTone.heavy, heavy),
      MapEntry<JournalTone, int>(JournalTone.light, light),
    ]) {
      if (e.value > best) {
        best = e.value;
        mostly = e.key;
      }
    }
    final Map<String, int> topics = <String, int>{};
    for (final JournalSummary e in list) {
      for (final String t in e.topics.toSet()) {
        topics[t] = (topics[t] ?? 0) + 1;
      }
    }
    final List<MapEntry<String, int>> top = topics.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) {
        final int byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return ToneSummary(
      entries: list.length,
      light: light,
      mixed: mixed,
      heavy: heavy,
      mostly: mostly,
      topTopics: top.take(3).toList(),
    );
  }

  /// The change in the headline score since the previous result.
  static int? checkInChange(AssessmentLatest row) {
    final double? now = row.latest.headline;
    final double? before = row.previous?.headline;
    if (now == null || before == null) {
      return null;
    }
    return now.round() - before.round();
  }

  /// "11 / 27", "64 / 100", "62%", or for the CBI
  /// "Work 68, Personal 54, Patients 33".
  static String scoreText(AssessmentDefinition def, AssessmentSummary s) {
    if (!def.hasTotal) {
      final Map<String, double> areas = s.areas ?? const <String, double>{};
      return def.areas
          .where((AssessmentArea a) => areas[a.id] != null)
          .map((AssessmentArea a) => '${a.label} ${areas[a.id]!.round()}')
          .join(', ');
    }
    final double total = s.total ?? 0;
    if (def.method == ScoringMethod.areaPercent) {
      return AssessmentMath.formatScore(def, total);
    }
    return '${total.round()} / ${def.max.round()}';
  }

  /// The PDF's check-in rows, newest first.
  static List<CheckInRow> checkInRows(
    Iterable<AssessmentLatest> rows,
    AssessmentContent content,
  ) {
    final List<CheckInRow> out = <CheckInRow>[];
    for (final AssessmentLatest row in rows) {
      final AssessmentDefinition? def = content.byId(row.latest.assessmentId);
      if (def == null) {
        continue;
      }
      final AssessmentSummary? prev = row.previous;
      out.add(
        CheckInRow(
          scale: def.scale == 'MindMate' ? def.name : def.scale,
          name: def.name,
          date: row.latest.completedAt,
          score: scoreText(def, row.latest),
          range: def.bandById(row.latest.headlineBandId)?.label ?? '',
          previous: prev == null || prev.headline == null
              ? 'None'
              : '${AssessmentMath.formatScore(def, prev.headline!)} '
                    '(${AssessmentMath.shortDate(prev.completedAt)})',
          item9Positive: row.latest.item9Positive,
        ),
      );
    }
    return out;
  }

  // The PDF.

  static MoodSummary? moodSummary(
    Iterable<MoodModel> moods, {
    required DateTime start,
    required DateTime end,
  }) {
    final List<MoodModel> list = within(
      moods,
      (MoodModel m) => m.date,
      start,
      end,
    );
    final Map<DateTime, MoodGroup> groups = dayGroups(list);
    final int totalDays = MoodStats.dayOf(end).difference(start).inDays;
    if (groups.isEmpty) {
      return null;
    }
    int count(MoodGroup g) =>
        groups.values.where((MoodGroup x) => x == g).length;
    return MoodSummary(
      daysLogged: groups.length,
      totalDays: totalDays,
      good: count(MoodGroup.good),
      between: count(MoodGroup.between),
      hard: count(MoodGroup.hard),
      topMoods: MoodStats.topMoods(
        list,
        limit: 3,
      ).map((MapEntry<String, int> e) => e.key).toList(),
      hardFactors:
          harderDays(list)?.topFactors ?? const <MapEntry<String, int>>[],
      dailyScores: MoodStats.dailyPoints(
        list,
        lastDay: MoodStats.addDays(end, -1),
        days: totalDays,
      ).map((MoodDayPoint p) => p.score).toList(),
    );
  }

  /// Null when nothing at all was logged. A null [breaks] or [journal]
  /// means that module is missing.
  static PracticeSummary? practiceSummary({
    required Iterable<MeditationLogEntry> sessions,
    Iterable<BreakLogEntry>? breaks,
    Iterable<JournalSummary>? journal,
  }) {
    final List<MeditationLogEntry> list = sessions.toList();
    final int breakCount = (breaks ?? const <BreakLogEntry>[])
        .where((BreakLogEntry b) => b.completed)
        .length;
    final int journalCount = (journal ?? const <JournalSummary>[]).length;
    if (list.isEmpty && breakCount == 0 && journalCount == 0) {
      return null;
    }
    final BeforeAfter? ba = beforeAfter(list);
    return PracticeSummary(
      sessions: list.length,
      minutes: calmMinutes(list),
      feelBefore: ba?.before,
      feelAfter: ba?.after,
      breaks: breaks == null ? null : breakCount,
      journalEntries: journal == null ? null : journalCount,
    );
  }

  /// "3h 10m", "42m", "0m".
  static String hoursMinutes(int minutes) {
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    if (h == 0) {
      return '${m}m';
    }
    return '${h}h ${m}m';
  }

  static double _mean(Iterable<double> values) {
    final List<double> list = values.toList();
    return list.isEmpty
        ? 0
        : list.reduce((double a, double b) => a + b) / list.length;
  }

  static String _plural(int n, String one, [String? many]) =>
      n == 1 ? '1 $one' : '$n ${many ?? '${one}s'}';
}
