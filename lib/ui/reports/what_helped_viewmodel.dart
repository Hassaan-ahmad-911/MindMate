import 'dart:async';

import 'package:get/get.dart';

import '../../Data/repositories/report_repository.dart';
import '../../Models/break_log.dart';
import '../../Models/journal_model.dart';
import '../../Models/meditation_log_entry.dart';
import '../../Models/mood_model.dart';
import '../../Models/mood_stats.dart';
import '../../Models/report_calculator.dart';

/// "What helped": patterns over the 30 days ending on [lastDay]. They show
/// what goes together, not what causes what.
class WhatHelpedViewModel extends GetxController {
  WhatHelpedViewModel(this._repository, {DateTime? lastDay})
    : lastDay = MoodStats.dayOf(lastDay ?? DateTime.now());

  final ReportRepository _repository;
  final DateTime lastDay;

  final RxBool isLoading = true.obs;
  final Rx<SourceResult<MoodModel>> moods =
      const SourceResult<MoodModel>.missing().obs;
  final Rx<SourceResult<MeditationLogEntry>> practice =
      const SourceResult<MeditationLogEntry>.missing().obs;
  final Rx<SourceResult<JournalSummary>> journal =
      const SourceResult<JournalSummary>.missing().obs;
  final Rx<SourceResult<BreakLogEntry>> breaks =
      const SourceResult<BreakLogEntry>.missing().obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    isLoading.value = true;
    final (DateTime start, DateTime end) = ReportCalculator.window(lastDay);
    await Future.wait(<Future<void>>[
      _repository.moods(start, end).then((r) => moods.value = r),
      _repository.practice(start, end).then((r) => practice.value = r),
      _repository.journal(start, end).then((r) => journal.value = r),
      _repository.breaks(start, end).then((r) => breaks.value = r),
    ]);
    if (!isClosed) {
      isLoading.value = false;
    }
  }

  /// Rows that qualify; empty when none do. Activities whose module is
  /// missing or failed are left out.
  List<ComparisonRow> get rows {
    final List<MoodModel>? m = moods.value.items;
    if (m == null) {
      return const <ComparisonRow>[];
    }
    return ReportCalculator.comparisonRows(
      moods: m,
      practiced: practice.value.items == null
          ? null
          : ReportCalculator.practiceDays(practice.value.items!),
      journaled: journal.value.items == null
          ? null
          : ReportCalculator.journalDays(journal.value.items!),
      tookBreak: breaks.value.items == null
          ? null
          : ReportCalculator.breakDays(breaks.value.items!),
    );
  }

  bool get comparisonFailed =>
      moods.value.failed ||
      practice.value.failed ||
      journal.value.failed ||
      breaks.value.failed;

  BeforeAfter? get beforeAfter {
    final List<MeditationLogEntry>? s = practice.value.items;
    return s == null ? null : ReportCalculator.beforeAfter(s);
  }

  HarderDays? get harder {
    final List<MoodModel>? m = moods.value.items;
    return m == null ? null : ReportCalculator.harderDays(m);
  }

  void back() => Get.back<void>();
}
