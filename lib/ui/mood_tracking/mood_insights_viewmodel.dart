import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';

import '../../Data/repositories/mood_repository.dart';
import '../../Models/mood_model.dart';
import '../../Models/mood_stats.dart';
import '../shared/app_feedback.dart';
import 'mood_tracking_viewmodel.dart';
import 'widgets/mood_visuals.dart';

enum InsightsPeriod { week, month, threeMonths }

extension InsightsPeriodDetails on InsightsPeriod {
  String get label {
    switch (this) {
      case InsightsPeriod.week:
        return 'Week';
      case InsightsPeriod.month:
        return 'Month';
      case InsightsPeriod.threeMonths:
        return '3 months';
    }
  }

  int get days {
    switch (this) {
      case InsightsPeriod.week:
        return 7;
      case InsightsPeriod.month:
        return 30;
      case InsightsPeriod.threeMonths:
        return MoodStats.historyWindowDays;
    }
  }

  /// Used in the pattern sentence, e.g. "... harder entries this week ...".
  String get phrase {
    switch (this) {
      case InsightsPeriod.week:
        return 'this week';
      case InsightsPeriod.month:
        return 'this month';
      case InsightsPeriod.threeMonths:
        return 'in the last 3 months';
    }
  }

  String get chartTitle {
    switch (this) {
      case InsightsPeriod.week:
        return 'Your mood, last 7 days';
      case InsightsPeriod.month:
        return 'Your mood, last 30 days';
      case InsightsPeriod.threeMonths:
        return 'Your mood, last 3 months';
    }
  }
}

/// Insights: streak, counts, daily chart, top moods and factors.
class MoodInsightsViewModel extends GetxController {
  MoodInsightsViewModel(this._moodRepository);

  final MoodRepository _moodRepository;

  /// The last 3 months of entries, newest first.
  final RxList<MoodModel> entries = <MoodModel>[].obs;
  final Rx<InsightsPeriod> period = InsightsPeriod.week.obs;
  final RxBool isLoading = false.obs;
  final RxBool hasLoadError = false.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(loadInsights());
  }

  void selectPeriod(InsightsPeriod value) => period.value = value;

  DateTime get _today => MoodStats.dayOf(DateTime.now());

  List<MoodModel> get periodEntries {
    final DateTime start = MoodStats.addDays(_today, 1 - period.value.days);
    return entries
        .where((MoodModel entry) => !entry.date.isBefore(start))
        .toList(growable: false);
  }

  int get streak => MoodStats.streak(
    entries.map((MoodModel entry) => entry.date),
    now: DateTime.now(),
  );

  int get entryCount => periodEntries.length;

  Map<DateTime, double> get _periodDayScores =>
      MoodStats.dayScores(periodEntries);

  int get loggedDays => _periodDayScores.length;

  int get goodDays => _periodDayScores.values.where(MoodStats.isGoodDay).length;

  List<MoodDayPoint> get chartPoints => MoodStats.dailyPoints(
    periodEntries,
    lastDay: _today,
    days: period.value.days,
  );

  /// "Daily average. No entry on Thursday." and similar.
  String get chartSubtitle {
    final List<MoodDayPoint> missing = chartPoints
        .where((MoodDayPoint point) => point.score == null)
        .toList(growable: false);
    if (missing.isEmpty) {
      return 'Daily average.';
    }
    if (period.value == InsightsPeriod.week && missing.length <= 2) {
      final String days = missing
          .map((MoodDayPoint point) => MoodFormat.weekday(point.day))
          .join(' or ');
      return 'Daily average. No entry on $days.';
    }
    final String noun = missing.length == 1 ? 'day' : 'days';
    return 'Daily average. ${missing.length} $noun without an entry.';
  }

  List<MapEntry<String, int>> get topMoods =>
      MoodStats.topMoods(periodEntries, limit: 5);

  List<MapEntry<String, int>> get topFactors =>
      MoodStats.topFactors(periodEntries, limit: 4);

  String? get patternSentence => MoodStats.patternSentence(
    periodEntries,
    periodPhrase: period.value.phrase,
  );

  Future<void> loadInsights() async {
    if (Firebase.apps.isEmpty) {
      return;
    }

    isLoading.value = true;
    try {
      entries.assignAll(await _moodRepository.getRecentWindow());
      hasLoadError.value = false;
    } catch (error) {
      hasLoadError.value = true;
      showMindMateSnackBar('Insights', moodErrorMessage(error));
    } finally {
      isLoading.value = false;
    }
  }
}
