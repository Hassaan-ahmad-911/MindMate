import 'dart:async';

import 'package:get/get.dart';

import '../../Data/repositories/report_repository.dart';
import '../../Models/assessment_definition.dart';
import '../../Models/assessment_result.dart';
import '../../Models/journal_model.dart';
import '../../Models/mood_stats.dart';
import '../../Models/report_calculator.dart';
import '../app/app_routes.dart';

/// "Check-ins and writing" for the 30 days ending on [lastDay].
class CheckInsWritingViewModel extends GetxController {
  CheckInsWritingViewModel(this._repository, {DateTime? lastDay})
    : lastDay = MoodStats.dayOf(lastDay ?? DateTime.now());

  final ReportRepository _repository;
  final DateTime lastDay;

  final RxBool isLoading = true.obs;
  final Rx<SourceResult<AssessmentLatest>> checkIns =
      const SourceResult<AssessmentLatest>.missing().obs;
  final Rx<SourceResult<JournalSummary>> journal =
      const SourceResult<JournalSummary>.missing().obs;
  final Rxn<AssessmentContent> content = Rxn<AssessmentContent>();

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    isLoading.value = true;
    final (DateTime start, DateTime end) = ReportCalculator.window(lastDay);
    await Future.wait(<Future<void>>[
      _repository.latestCheckIns(start, end).then((r) => checkIns.value = r),
      _repository.journal(start, end).then((r) => journal.value = r),
      _repository.checkInContent().then((c) => content.value = c),
    ]);
    if (!isClosed) {
      isLoading.value = false;
    }
  }

  List<AssessmentLatest> get rows =>
      checkIns.value.items ?? const <AssessmentLatest>[];

  /// The questionnaires with no result in these 30 days.
  List<String> get notTaken {
    final AssessmentContent? c = content.value;
    if (c == null) {
      return const <String>[];
    }
    final Set<String> taken = rows
        .map((AssessmentLatest r) => r.latest.assessmentId)
        .toSet();
    return c.assessments
        .where((AssessmentDefinition d) => !taken.contains(d.id))
        .map((AssessmentDefinition d) => d.name)
        .toList();
  }

  ToneSummary? get tone {
    final List<JournalSummary>? j = journal.value.items;
    return j == null ? null : ReportCalculator.toneSummary(j);
  }

  void seeAll() => Get.toNamed<void>(AppRoutes.assessmentHistory);

  void back() => Get.back<void>();
}
