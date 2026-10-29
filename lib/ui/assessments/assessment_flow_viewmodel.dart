import 'dart:async';

import 'package:get/get.dart';

import '../../Data/repositories/assessment_repository.dart';
import '../../Data/repositories/meditation_repository.dart';
import '../../Models/assessment_definition.dart';
import '../../Models/assessment_result.dart';
import '../../Models/assessment_rules.dart';
import '../../Models/assessment_scorer.dart';
import '../../Models/hospital_programme.dart';
import '../../Models/meditation_models.dart';
import '../../services/share_service.dart';
import '../app/app_routes.dart';
import '../programme/wellbeing_programme_controller.dart';
import '../shared/app_feedback.dart';

enum AssessmentStep { loading, error, intro, question, safety, result }

/// One questionnaire from intro to result. The same flow serves all six;
/// what differs comes from the content file. Opened as `/assessments/{id}`,
/// or with a saved [AssessmentResult] as the argument to show it read-only.
///
/// Answers and scores are never logged or sent anywhere except the user's
/// own result document, and only once the check-in is completed.
class AssessmentFlowViewModel extends GetxController {
  AssessmentFlowViewModel(
    this._repository, {
    required this.assessmentId,
    AssessmentResult? savedResult,
    MeditationRepository? meditation,
    ShareService? share,
    DateTime Function()? clock,
    WellbeingProgrammeController? programme,
  }) : _savedResult = savedResult,
       _meditation = meditation,
       _share = share,
       _clock = clock ?? DateTime.now,
       _programme = programme;

  final AssessmentRepository _repository;
  final String assessmentId;
  final AssessmentResult? _savedResult;
  final MeditationRepository? _meditation;
  final ShareService? _share;
  final DateTime Function() _clock;
  final WellbeingProgrammeController? _programme;

  /// The user's hospital, or null for someone not in a programme. Changes
  /// the question 9 footnote and what "Stop the check here" does.
  final Rxn<HospitalMembership> hospital = Rxn<HospitalMembership>();

  final Rx<AssessmentStep> step = AssessmentStep.loading.obs;

  /// One per item; null until answered.
  final RxList<int?> answers = <int?>[].obs;
  final Rxn<int> extraAnswer = Rxn<int>();

  /// The question on screen: 0 to n - 1 for the items, n for the extra
  /// (difficulty) question.
  final RxInt index = 0.obs;

  final Rxn<AssessmentResult> result = Rxn<AssessmentResult>();
  final Rxn<AssessmentResult> previous = Rxn<AssessmentResult>();
  final Rxn<MeditationSession> practice = Rxn<MeditationSession>();
  final RxString practiceGroup = ''.obs;
  final RxBool isSaving = false.obs;
  final RxBool saveFailed = false.obs;

  late AssessmentDefinition def;
  late Item9Safety safety;
  int _contentVersion = 1;
  DateTime _startedAt = DateTime.now();
  bool _safetyShown = false;
  List<AssessmentResult> _history = const <AssessmentResult>[];

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() async {
    step.value = AssessmentStep.loading;
    try {
      final AssessmentContent content = await _repository.loadContent();
      final AssessmentDefinition? found = content.byId(assessmentId);
      if (found == null) {
        step.value = AssessmentStep.error;
        return;
      }
      def = found;
      safety = content.item9;
      _contentVersion = content.version;
    } catch (_) {
      step.value = AssessmentStep.error;
      return;
    }
    unawaited(_loadHospital());

    final AssessmentResult? saved = _savedResult;
    if (saved != null) {
      answers.assignAll(saved.answers);
      result.value = saved;
      step.value = AssessmentStep.result;
      await _loadHistory();
      _findPrevious(saved);
      unawaited(_loadPractice());
      return;
    }
    _reset();
    step.value = AssessmentStep.intro;
    unawaited(_loadHistory());
  }

  Future<void> _loadHospital() async {
    try {
      hospital.value = await _programme?.loadMembership();
    } catch (_) {
      hospital.value = null;
    }
  }

  /// The footnote for someone in a hospital ([lead], then [bold]), or null
  /// for everyone else, who see the content file's footnote.
  ({String lead, String bold})? get programmeFootnote {
    final HospitalMembership? m = hospital.value;
    return m == null ? null : ProgrammeWording.item9Footnote(m);
  }

  Future<void> _loadHistory() async {
    try {
      _history = await _repository.getHistory(assessmentId);
    } catch (_) {
      _history = const <AssessmentResult>[];
    }
  }

  void _findPrevious(AssessmentResult current) {
    AssessmentResult? before;
    for (final AssessmentResult r in _history) {
      if (r.id != current.id && r.completedAt.isBefore(current.completedAt)) {
        if (before == null || r.completedAt.isAfter(before.completedAt)) {
          before = r;
        }
      }
    }
    previous.value = before;
  }

  void _reset() {
    answers.assignAll(List<int?>.filled(def.items.length, null));
    extraAnswer.value = null;
    index.value = 0;
    _safetyShown = false;
    result.value = null;
    previous.value = null;
    practice.value = null;
    saveFailed.value = false;
  }

  // Questions.

  int get itemCount => def.items.length;

  bool get onExtra => index.value >= itemCount;

  AssessmentItem? get currentItem => onExtra ? null : def.items[index.value];

  /// The muted line above the question (not for the extra question).
  String? get stem => onExtra ? null : def.stem;

  String get questionText =>
      onExtra ? def.extraItem!.text : def.items[index.value].text;

  List<AnswerOption> get options =>
      onExtra ? def.extraItem!.options : def.items[index.value].options;

  int? get selected => onExtra ? extraAnswer.value : answers[index.value];

  bool get canGoNext => selected != null;

  /// Whether "Next" ends the check-in.
  bool get isLastQuestion {
    if (onExtra) {
      return true;
    }
    if (index.value < itemCount - 1) {
      return false;
    }
    final AssessmentItem item = def.items[index.value];
    final bool supportNext = AssessmentFlowRules.shouldShowSafety(
      item,
      answers[index.value],
      _safetyShown,
    );
    return !supportNext && !AssessmentFlowRules.showsExtra(def, answers);
  }

  String get nextLabel => isLastQuestion ? 'See my result' : 'Next';

  void start() {
    _reset();
    _startedAt = _clock();
    step.value = AssessmentStep.question;
  }

  void select(int value) {
    if (onExtra) {
      extraAnswer.value = value;
    } else {
      answers[index.value] = value;
    }
  }

  void next() {
    if (!canGoNext) {
      return;
    }
    if (onExtra) {
      unawaited(_finish());
      return;
    }
    final AssessmentItem item = def.items[index.value];
    if (AssessmentFlowRules.shouldShowSafety(
      item,
      answers[index.value],
      _safetyShown,
    )) {
      _safetyShown = true;
      _repository.markItem9Positive();
      step.value = AssessmentStep.safety;
      return;
    }
    _advance();
  }

  void _advance() {
    if (index.value < itemCount - 1) {
      index.value += 1;
    } else if (AssessmentFlowRules.showsExtra(def, answers)) {
      index.value = itemCount;
    } else {
      unawaited(_finish());
    }
  }

  /// Back keeps every answer. From the first question it returns to the
  /// intro.
  void back() {
    if (step.value == AssessmentStep.safety) {
      step.value = AssessmentStep.question;
      return;
    }
    if (index.value == 0) {
      step.value = AssessmentStep.intro;
      return;
    }
    index.value -= 1;
  }

  /// Whether closing would lose answers.
  bool get closeNeedsConfirm =>
      step.value == AssessmentStep.question ||
      step.value == AssessmentStep.safety;

  void close() => Get.back<void>();

  // Question 9 support.

  /// "I'm safe, continue": on to the difficulty question or the result.
  void continueAfterSafety() {
    step.value = AssessmentStep.question;
    _advance();
  }

  /// "Stop the check here": opens the support page. The hub shows its
  /// support banner for the rest of this session.
  ///
  /// Someone not in a hospital: nothing is saved. Someone in a hospital: the
  /// nine answers are saved as a normal result (the unscored difficulty
  /// question left empty), so the server is asked to evaluate and the
  /// officer is emailed today, as the footnote said.
  void stopHere() {
    _repository.markItem9Positive();
    if (hospital.value != null) {
      unawaited(_saveStopped());
    }
    Get.offNamed<void>(AppRoutes.support);
  }

  Future<void> _saveStopped() async {
    final AssessmentResult built = AssessmentResult.fromAttempt(
      def: def,
      contentVersion: _contentVersion,
      answers: answers.map((int? a) => a ?? 0).toList(),
      startedAt: _startedAt,
      completedAt: _clock(),
    );
    try {
      // The repository then asks the server to evaluate.
      await _repository.saveResult(built);
    } catch (_) {
      // Offline: Firestore keeps the write and sends it later.
    }
  }

  void openSupport() => Get.toNamed<void>(AppRoutes.support);

  /// Opens the phone's share sheet with a short neutral message. The user
  /// picks who to send it to; the app sends nothing itself.
  Future<void> reachOut() async {
    final bool opened =
        await (_share?.shareText(safety.trustMessage) ??
            Future<bool>.value(false));
    if (!opened) {
      showMindMateSnackBar(
        'Sharing is not available',
        'Message someone you trust from your phone: '
            '"${safety.trustMessage}"',
      );
    }
  }

  // The result.

  Future<void> _finish() async {
    final AssessmentResult built = AssessmentResult.fromAttempt(
      def: def,
      contentVersion: _contentVersion,
      answers: answers.map((int? a) => a ?? 0).toList(),
      extraAnswers: <String, int>{
        if (onExtra && extraAnswer.value != null)
          def.extraItem!.id: extraAnswer.value!,
      },
      startedAt: _startedAt,
      completedAt: _clock(),
    );
    previous.value = _history.isEmpty ? null : _history.first;
    result.value = built;
    step.value = AssessmentStep.result;
    unawaited(_loadPractice());
    await _save(built);
  }

  Future<void> _save(AssessmentResult built) async {
    isSaving.value = true;
    saveFailed.value = false;
    try {
      final AssessmentResult saved = await _repository.saveResult(built);
      if (!isClosed && result.value == built) {
        result.value = saved;
        _history = <AssessmentResult>[saved, ..._history];
      }
    } catch (_) {
      if (!isClosed) {
        saveFailed.value = true;
      }
    } finally {
      if (!isClosed) {
        isSaving.value = false;
      }
    }
  }

  Future<void> retrySave() async {
    final AssessmentResult? current = result.value;
    if (current != null && current.id.isEmpty) {
      await _save(current);
    }
  }

  AssessmentScore get score => result.value!.scoreWith(def);

  AssessmentBand? get band => def.bandById(result.value?.bandId);

  int? get change => result.value == null
      ? null
      : AssessmentMath.change(result.value!, previous.value);

  String? get nextStep => AssessmentScorer.nextStep(def, score);

  /// PHQ-4: the fuller check-ins its parts suggest (PHQ-9, GAD-7, or both).
  List<FollowUpRule> get followUps {
    final AssessmentResult? current = result.value;
    return current == null
        ? const <FollowUpRule>[]
        : def.followUpsFor(current.answers);
  }

  /// "Take it now": that check-in in place of this result.
  void takeFollowUp(FollowUpRule rule) {
    Get.offNamed<void>('${AppRoutes.assessments}/${rule.assessmentId}');
  }

  bool get item9Positive => score.item9Positive;

  /// The CBI line under the title.
  String? get topLine {
    final Map<String, double>? areas = result.value?.areas;
    if (def.topLines.isEmpty || areas == null || areas.isEmpty) {
      return null;
    }
    if (areas.values.every((double v) => v < 50)) {
      return def.topLines['allLow'];
    }
    return def.topLines[score.highestArea];
  }

  /// The areas, the one needing most attention first: highest first when
  /// lower is better (CBI), lowest first when higher is better (workplace).
  List<MapEntry<AssessmentArea, double>> get sortedAreas {
    final Map<String, double> areas =
        result.value?.areas ?? const <String, double>{};
    final List<MapEntry<AssessmentArea, double>> list =
        <MapEntry<AssessmentArea, double>>[
          for (final AssessmentArea area in def.areas)
            if (areas[area.id] != null)
              MapEntry<AssessmentArea, double>(area, areas[area.id]!),
        ];
    list.sort(
      (
        MapEntry<AssessmentArea, double> a,
        MapEntry<AssessmentArea, double> b,
      ) => def.lowerIsBetter
          ? b.value.compareTo(a.value)
          : a.value.compareTo(b.value),
    );
    return list;
  }

  Future<void> _loadPractice() async {
    final MeditationRepository? meditation = _meditation;
    if (meditation == null || result.value == null) {
      return;
    }
    final String? id = AssessmentScorer.practiceId(def, score);
    if (id == null) {
      return;
    }
    try {
      final MeditationSession? session = await meditation.findSession(id);
      if (session == null || isClosed) {
        return;
      }
      practiceGroup.value = meditation.groupById(session.groupId)?.title ?? '';
      practice.value = session;
    } catch (_) {
      // No practice card without the meditation content.
    }
  }

  /// "After a shift · 8 min".
  String get practiceLabel {
    final MeditationSession? session = practice.value;
    if (session == null) {
      return '';
    }
    return practiceGroup.value.isEmpty
        ? session.lengthLabel
        : '${practiceGroup.value} · ${session.lengthLabel}';
  }

  void openPractice() {
    final MeditationSession? session = practice.value;
    if (session != null) {
      Get.toNamed<void>(AppRoutes.meditationDetails, arguments: session.id);
    }
  }

  /// The question and chosen answer of every item, for the review sheet.
  List<MapEntry<String, String>> get reviewRows {
    final List<MapEntry<String, String>> rows = <MapEntry<String, String>>[];
    for (int i = 0; i < def.items.length; i += 1) {
      final AssessmentItem item = def.items[i];
      rows.add(
        MapEntry<String, String>(
          item.text,
          item.labelFor(i < answers.length ? answers[i] : null) ?? '—',
        ),
      );
    }
    final ExtraItem? extra = def.extraItem;
    final int? extraValue = result.value?.extraAnswers[extra?.id];
    if (extra != null && extraValue != null) {
      rows.add(
        MapEntry<String, String>(extra.text, extra.labelFor(extraValue) ?? '—'),
      );
    }
    return rows;
  }

  /// "Take it again" from the review sheet.
  void takeAgain() {
    _reset();
    step.value = AssessmentStep.intro;
  }

  void done() => Get.back<void>();
}
