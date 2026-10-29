import 'dart:async';

import 'package:get/get.dart';

import '../../Data/repositories/assessment_repository.dart';
import '../../Models/assessment_definition.dart';
import '../../Models/assessment_result.dart';
import '../../Models/assessment_rules.dart';
import '../app/app_routes.dart';

/// The Check-ins hub: the suggested card and the latest range of each
/// questionnaire.
class AssessmentsHubViewModel extends GetxController {
  AssessmentsHubViewModel(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AssessmentRepository _repository;
  final DateTime Function() _clock;

  final Rxn<AssessmentContent> content = Rxn<AssessmentContent>();
  final RxMap<String, AssessmentResult> latest =
      <String, AssessmentResult>{}.obs;
  final Rxn<AssessmentSuggestion> suggestion = Rxn<AssessmentSuggestion>();
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxBool showSupportBanner = false.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load({bool quiet = false}) async {
    if (!quiet) {
      isLoading.value = true;
    }
    hasError.value = false;
    showSupportBanner.value = _repository.item9PositiveThisSession;
    try {
      final AssessmentContent loaded = await _repository.loadContent();
      content.value = loaded;
      final Map<String, AssessmentResult> found = await _repository
          .getLatestById();
      latest.assignAll(found);
      suggestion.value = AssessmentSuggestion.pick(
        all: loaded.assessments,
        order: loaded.suggestOrder,
        latest: found,
        now: _clock(),
      );
    } catch (_) {
      hasError.value = true;
    } finally {
      if (!isClosed) {
        isLoading.value = false;
      }
    }
  }

  /// "PHQ-9 · 9 questions".
  static String cardLine(AssessmentDefinition def) =>
      '${def.scale} · ${def.items.length} questions';

  /// "You have not taken it yet. 19 questions, about 4 minutes." or "Last
  /// taken 24 Sep. Good time for another look."
  static String suggestionLine(AssessmentSuggestion s) {
    final DateTime? last = s.lastTaken;
    if (last == null) {
      return 'You have not taken it yet. ${s.def.items.length} questions, '
          '${s.def.aboutMinutes}.';
    }
    return 'Last taken ${AssessmentMath.shortDate(last)}. '
        'Good time for another look.';
  }

  /// The range of the latest result: for the CBI, the highest area's.
  AssessmentBand? latestBand(AssessmentDefinition def) {
    final AssessmentResult? r = latest[def.id];
    return r == null ? null : def.bandById(r.headlineBandId);
  }

  Future<void> openCheckIn(String id) async {
    await Get.toNamed<void>('${AppRoutes.assessments}/$id');
    if (!isClosed) {
      await load(quiet: true);
    }
  }

  void openHistory() => Get.toNamed<void>(AppRoutes.assessmentHistory);

  void openSupport() => Get.toNamed<void>(AppRoutes.support);

  void back() => Get.back<void>();
}
