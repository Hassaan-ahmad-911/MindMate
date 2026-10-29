import 'dart:async';

import 'package:get/get.dart';

import '../../Data/repositories/report_repository.dart';
import '../../Models/assessment_result.dart';
import '../../Models/break_log.dart';
import '../../Models/journal_model.dart';
import '../../Models/meditation_log_entry.dart';
import '../../Models/mood_catalog.dart';
import '../../Models/mood_model.dart';
import '../../Models/mood_stats.dart';
import '../../Models/report_calculator.dart';
import '../../Models/report_period.dart';
import '../app/app_routes.dart';

/// Everything loaded for one date range, per source.
class ReportBundle {
  ReportBundle(this.start, this.end);

  final DateTime start;
  final DateTime end;
  final Map<ReportSource, SourceResult<Object>> results =
      <ReportSource, SourceResult<Object>>{};

  List<T>? items<T>(ReportSource source) => results[source]?.items?.cast<T>();

  bool failed(ReportSource source) => results[source]?.failed ?? false;

  bool available(ReportSource source) => results[source]?.available ?? false;
}

/// One column of "Day by day" or one square of the month calendar.
class ReportDay {
  const ReportDay({
    required this.day,
    required this.group,
    required this.mood,
    required this.practised,
    required this.journaled,
    required this.tookBreak,
    required this.isFuture,
  });

  final DateTime day;
  final MoodGroup? group;

  /// The day's latest mood, for its face.
  final String? mood;

  /// Null when that module is not available.
  final bool? practised;
  final bool? journaled;
  final bool? tookBreak;
  final bool isFuture;
}

/// Reports, week and month. Reads only.
class ReportsViewModel extends GetxController {
  ReportsViewModel(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ReportRepository _repository;
  final DateTime Function() _clock;

  late final Rx<ReportPeriod> period = ReportPeriod.week(_clock()).obs;
  final Rxn<ReportBundle> bundle = Rxn<ReportBundle>();
  final RxBool isLoading = true.obs;

  /// Loaded ranges in this visit, so switching back does not reload.
  final Map<String, ReportBundle> _cache = <String, ReportBundle>{};
  int _request = 0;

  @override
  void onInit() {
    super.onInit();
    unawaited(_show(period.value));
  }

  DateTime get now => _clock();

  ReportKind get kind => period.value.kind;

  bool get canGoForward =>
      !period.value.isCurrent(_clock()) &&
      period.value.end.isBefore(
        MoodStats.addDays(MoodStats.dayOf(_clock()), 1),
      );

  void setKind(ReportKind kind) {
    if (kind == period.value.kind) {
      return;
    }
    unawaited(_show(ReportPeriod.of(kind, _clock())));
  }

  void previousPeriod() => unawaited(_show(period.value.previous));

  void nextPeriod() {
    if (canGoForward) {
      unawaited(_show(period.value.next));
    }
  }

  /// The range loaded for [p]: the period before it and the 30 days ending
  /// on its last day, up to its end.
  static (DateTime, DateTime) rangeFor(ReportPeriod p) {
    final DateTime windowStart = ReportCalculator.window(p.lastDay).$1;
    final DateTime prevStart = p.previous.start;
    return (prevStart.isBefore(windowStart) ? prevStart : windowStart, p.end);
  }

  Future<void> _show(ReportPeriod p) async {
    period.value = p;
    final (DateTime start, DateTime end) = rangeFor(p);
    final String key = '${start.toIso8601String()}|${end.toIso8601String()}';
    final ReportBundle? cached = _cache[key];
    if (cached != null) {
      bundle.value = cached;
      isLoading.value = false;
      return;
    }
    final int request = ++_request;
    isLoading.value = true;
    final ReportBundle loaded = ReportBundle(start, end);
    await Future.wait(
      ReportSource.values.map((ReportSource s) => _loadSource(loaded, s)),
    );
    _cache[key] = loaded;
    if (request == _request && !isClosed) {
      bundle.value = loaded;
      isLoading.value = false;
    }
  }

  Future<void> _loadSource(ReportBundle b, ReportSource source) async {
    final SourceResult<Object> result;
    switch (source) {
      case ReportSource.moods:
        result = await _repository.moods(b.start, b.end);
      case ReportSource.practice:
        result = await _repository.practice(b.start, b.end);
      case ReportSource.journal:
        result = await _repository.journal(b.start, b.end);
      case ReportSource.breaks:
        result = await _repository.breaks(b.start, b.end);
      case ReportSource.checkIns:
        result = await _repository.checkIns(b.start, b.end);
    }
    b.results[source] = result;
  }

  /// "Could not load. Tap to retry" reloads only the failed sources.
  Future<void> retry() async {
    final ReportBundle? b = bundle.value;
    if (b == null) {
      return;
    }
    await Future.wait(
      ReportSource.values
          .where(b.failed)
          .map((ReportSource s) => _loadSource(b, s)),
    );
    bundle.refresh();
  }

  // Slices of the loaded data.

  List<T>? _in<T>(
    ReportSource source,
    DateTime Function(T) dateOf,
    DateTime start,
    DateTime end,
  ) {
    final List<T>? all = bundle.value?.items<T>(source);
    return all == null
        ? null
        : ReportCalculator.within<T>(all, dateOf, start, end);
  }

  List<MoodModel>? moodsIn(DateTime s, DateTime e) =>
      _in<MoodModel>(ReportSource.moods, (MoodModel m) => m.date, s, e);

  List<MeditationLogEntry>? sessionsIn(DateTime s, DateTime e) =>
      _in<MeditationLogEntry>(
        ReportSource.practice,
        (MeditationLogEntry m) => m.startedAt,
        s,
        e,
      );

  List<JournalSummary>? journalIn(DateTime s, DateTime e) =>
      _in<JournalSummary>(
        ReportSource.journal,
        (JournalSummary j) => j.createdAt,
        s,
        e,
      );

  List<BreakLogEntry>? breaksIn(DateTime s, DateTime e) => _in<BreakLogEntry>(
    ReportSource.breaks,
    (BreakLogEntry b) => b.startedAt,
    s,
    e,
  );

  List<AssessmentSummary>? checkInsIn(DateTime s, DateTime e) =>
      _in<AssessmentSummary>(
        ReportSource.checkIns,
        (AssessmentSummary a) => a.completedAt,
        s,
        e,
      );

  bool failed(ReportSource s) => bundle.value?.failed(s) ?? false;

  bool available(ReportSource s) => bundle.value?.available(s) ?? false;

  bool get anyFailed => ReportSource.values.any(failed);

  PeriodStats statsFor(ReportPeriod p) => ReportCalculator.stats(
    moods: moodsIn(p.start, p.end),
    sessions: sessionsIn(p.start, p.end),
    journal: journalIn(p.start, p.end),
    breaks: breaksIn(p.start, p.end),
    checkIns: checkInsIn(p.start, p.end),
  );

  PeriodStats get current => statsFor(period.value);

  PeriodStats get previous => statsFor(period.value.previous);

  List<Highlight> get highlights =>
      ReportCalculator.highlights(current, previous, kind);

  /// Days of the selected period with their mood and activities.
  List<ReportDay> get days {
    final ReportPeriod p = period.value;
    final List<MoodModel> moods =
        moodsIn(p.start, p.end) ?? const <MoodModel>[];
    final Map<DateTime, MoodGroup> groups = ReportCalculator.dayGroups(moods);
    final List<MoodDayPoint> points = MoodStats.dailyPoints(
      moods,
      lastDay: p.lastDay,
      days: p.days.length,
    );
    final List<MeditationLogEntry>? sessions = sessionsIn(p.start, p.end);
    final List<JournalSummary>? journal = journalIn(p.start, p.end);
    final List<BreakLogEntry>? breaks = breaksIn(p.start, p.end);
    final Set<DateTime>? practice = sessions == null
        ? null
        : ReportCalculator.practiceDays(sessions);
    final Set<DateTime>? wrote = journal == null
        ? null
        : ReportCalculator.journalDays(journal);
    final Set<DateTime>? rested = breaks == null
        ? null
        : ReportCalculator.breakDays(breaks);
    final DateTime today = MoodStats.dayOf(_clock());
    return <ReportDay>[
      for (final MoodDayPoint point in points)
        ReportDay(
          day: point.day,
          group: groups[point.day],
          mood: point.latestMood,
          practised: practice?.contains(point.day),
          journaled: wrote?.contains(point.day),
          tookBreak: rested?.contains(point.day),
          isFuture: point.day.isAfter(today),
        ),
    ];
  }

  List<WeekAverage> get weeks => ReportCalculator.weekByWeek(
    moodsIn(period.value.start, period.value.end) ?? const <MoodModel>[],
    period.value,
  );

  String? change(int Function(PeriodStats) value) {
    final PeriodStats before = previous;
    return ReportCalculator.changeLabel(
      value(current),
      value(before),
      previousHasData: before.hasAnyData,
      kind: kind,
    );
  }

  // Navigation.

  void back() => Get.back<void>();

  void openDay(DateTime day) {
    if (!day.isAfter(_clock())) {
      Get.toNamed<void>(AppRoutes.moodHistory, arguments: day);
    }
  }

  void logMood() => Get.toNamed<void>(AppRoutes.moodLog);

  /// The last day the "last 30 days" screens end on.
  DateTime get windowEnd {
    final DateTime today = MoodStats.dayOf(_clock());
    final DateTime last = period.value.lastDay;
    return last.isAfter(today) ? today : last;
  }

  void openHelped() =>
      Get.toNamed<void>(AppRoutes.reportsHelped, arguments: windowEnd);

  void openCheckIns() =>
      Get.toNamed<void>(AppRoutes.reportsCheckIns, arguments: windowEnd);

  void openShare() => Get.toNamed<void>(AppRoutes.reportsShare);
}
