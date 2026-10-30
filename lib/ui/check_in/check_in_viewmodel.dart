import 'dart:async';

import 'package:get/get.dart';

import '../../Data/repositories/assessment_repository.dart';
import '../../Data/repositories/meditation_repository.dart';
import '../../Data/repositories/profile_repository.dart';
import '../../Models/assessment_definition.dart';
import '../../Models/assessment_result.dart';
import '../../Models/check_in_planner.dart';
import '../../Models/check_in_questions.dart';
import '../../Models/check_in_result.dart';
import '../../Models/meditation_models.dart';
import '../../Models/profile_options.dart';
import '../../Models/user_profile.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../app/app_routes.dart';
import '../reminders/reminder_controller.dart';
import '../shared/app_feedback.dart';

/// One of the three suggested starting points on the All set screen.
class StartingPoint {
  const StartingPoint.dailyCheckIn({required this.subtitle})
    : title = 'Daily mood check-in',
      session = null;

  StartingPoint.practice(MeditationSession this.session)
    : title = session.title,
      subtitle = '${session.lengthLabel} · ${session.goodFor}';

  final String title;
  final String subtitle;

  /// The practice to open, or null for the daily mood check-in.
  final MeditationSession? session;
}

/// The first check-in: an intro, nine questions (each can be skipped), and the
/// "All set" screen. It is created by the intro route and shared by the
/// screens after it.
class CheckInViewModel extends GetxController {
  CheckInViewModel(
    this._profileRepository,
    this._meditationRepository, {
    AssessmentRepository? assessments,
    DateTime Function()? clock,
  }) : _assessments = assessments,
       _clock = clock ?? DateTime.now;

  final ProfileRepository _profileRepository;
  final MeditationRepository _meditationRepository;

  /// Saves the WHO-5 answers as a normal Wellbeing result too.
  final AssessmentRepository? _assessments;
  final DateTime Function() _clock;

  final List<CheckInQuestion> questions = CheckInQuestions.all;

  /// The question being shown, from 0.
  final RxInt index = 0.obs;

  /// One answer per question: the value of the chosen option, a list of values
  /// for the goals question, or null if not answered or skipped.
  final RxList<Object?> answers = List<Object?>.filled(
    CheckInQuestions.count,
    null,
  ).obs;

  final RxString firstName = ''.obs;

  /// False when the user chose "Do this later".
  final RxBool answeredCheckIn = false.obs;

  // The All set screen.
  final Rxn<CheckInPlan> plan = Rxn<CheckInPlan>();
  final RxList<StartingPoint> startingPoints = <StartingPoint>[].obs;

  bool _finishing = false;

  @override
  void onInit() {
    super.onInit();
    unawaited(_loadName());
  }

  Future<void> _loadName() async {
    try {
      final UserProfile profile = await _profileRepository
          .getCurrentUserProfile();
      firstName.value = profile.firstName;
    } on Object {
      // "Welcome" without a name is fine.
    }
  }

  // ---------------------------------------------------------------------------
  // Questions.
  // ---------------------------------------------------------------------------

  CheckInQuestion get question => questions[index.value];

  int get questionCount => questions.length;

  bool get isLastQuestion => index.value >= questions.length - 1;

  bool isSelected(CheckInOption option) {
    final Object? answer = answers[index.value];
    if (question.multiSelect) {
      return answer is List && answer.contains(option.value);
    }
    return answer != null && answer == option.value;
  }

  /// Whether the current question has an answer, so "Next" can be used.
  bool get hasAnswer {
    final Object? answer = answers[index.value];
    if (question.multiSelect) {
      return answer is List && answer.isNotEmpty;
    }
    return answer != null;
  }

  void select(CheckInOption option) {
    if (question.multiSelect) {
      final Object? current = answers[index.value];
      final List<Object> chosen = current is List
          ? current.cast<Object>().toList()
          : <Object>[];
      if (!chosen.remove(option.value)) {
        chosen.add(option.value);
      }
      answers[index.value] = chosen;
    } else {
      answers[index.value] = option.value;
    }
  }

  /// "Begin" on the intro.
  void begin() => Get.toNamed(AppRoutes.checkInQuestion);

  /// "Next". The last question finishes the check-in.
  void next() {
    if (!hasAnswer) {
      return;
    }
    _advance();
  }

  /// "Skip this question": nothing is stored for it.
  void skip() {
    answers[index.value] = null;
    _advance();
  }

  /// Back to the previous question, with its answer kept. From the first
  /// question it goes back to the intro.
  void back() {
    if (index.value > 0) {
      index.value -= 1;
    } else {
      Get.back();
    }
  }

  void _advance() {
    if (isLastQuestion) {
      unawaited(finish());
    } else {
      index.value += 1;
    }
  }

  // ---------------------------------------------------------------------------
  // Finishing.
  // ---------------------------------------------------------------------------

  /// Saves the answers and shows the All set screen.
  Future<void> finish() async {
    if (_finishing) {
      return;
    }
    _finishing = true;
    answeredCheckIn.value = true;

    final CheckInResult result = CheckInResult.fromAnswers(
      answers.toList(growable: false),
    );
    final CheckInPlan plan = CheckInPlanner.plan(
      goals: result.goals,
      sleepQuality: result.sleepQuality,
      workStress: result.workStress,
      who5Score: result.who5Score,
    );

    // Not awaited: without a connection a write only finishes once the phone
    // is back online.
    unawaited(_save(result));
    unawaited(_saveWho5(result));
    await _showAllSet(plan, reminder: result.reminderPreference);
    Get.offNamed(AppRoutes.checkInDone);
  }

  /// The first check-in's WHO-5 counts as the first Wellbeing check-in:
  /// when all five were answered, it is also saved at
  /// `users/{uid}/assessments` like any WHO-5, so the schedule and the
  /// hospital programme see it. Skipped answers are never filled in.
  Future<void> _saveWho5(CheckInResult result) async {
    final AssessmentRepository? assessments = _assessments;
    if (assessments == null || result.who5Raw == null) {
      return;
    }
    try {
      final AssessmentContent content = await assessments.loadContent();
      final AssessmentDefinition? who5 = content.byId('who5');
      if (who5 == null || who5.items.length != result.who5Answers.length) {
        return;
      }
      final DateTime now = _clock();
      await assessments.saveResult(
        AssessmentResult.fromAttempt(
          def: who5,
          contentVersion: content.version,
          answers: result.who5Answers.map((int? a) => a!).toList(),
          startedAt: now,
          completedAt: now,
          source: AssessmentResult.setupSource,
        ),
      );
    } on Object {
      // The check-in itself is saved; Wellbeing is simply due as usual.
    }
  }

  /// "Do this later": no answers are stored, and the check-in stays pending.
  Future<void> doLater() async {
    if (_finishing) {
      return;
    }
    _finishing = true;
    await _showAllSet(CheckInPlanner.skippedPlan(), reminder: null);
    Get.toNamed(AppRoutes.checkInDone);
  }

  Future<void> _save(CheckInResult result) async {
    try {
      await _profileRepository.saveCheckIn(result);
      if (Get.isRegistered<HomeViewModel>()) {
        Get.find<HomeViewModel>().setCheckInStatus(
          ProfileOptions.checkInCompleted,
        );
      }
    } on Object {
      showMindMateSnackBar(
        'Could not save your check-in',
        'You can finish it again from Home.',
      );
    }
  }

  Future<void> _showAllSet(CheckInPlan plan, {String? reminder}) async {
    final List<StartingPoint> points = <StartingPoint>[
      StartingPoint.dailyCheckIn(
        subtitle: CheckInPlanner.reminderLine(reminder),
      ),
    ];
    for (final String id in plan.practiceIds) {
      try {
        final MeditationSession? session = await _meditationRepository
            .findSession(id);
        if (session != null) {
          points.add(StartingPoint.practice(session));
        }
      } on Object {
        // A practice that cannot be loaded is left out.
      }
    }
    this.plan.value = plan;
    startingPoints.assignAll(points);
  }

  // ---------------------------------------------------------------------------
  // All set.
  // ---------------------------------------------------------------------------

  void openStartingPoint(StartingPoint point) {
    final MeditationSession? session = point.session;
    if (session == null) {
      Get.toNamed(AppRoutes.moodLog);
    } else {
      Get.toNamed(AppRoutes.meditationDetails, arguments: session.id);
    }
  }

  /// After "All set": the "Gentle reminders" page the first time, then
  /// Home.
  Future<void> goHome() async {
    bool askFirst = false;
    if (Get.isRegistered<ReminderController>()) {
      askFirst = !await Get.find<ReminderController>().permissionPageShown();
    }
    Get.offAllNamed(askFirst ? AppRoutes.remindersPermission : AppRoutes.home);
  }
}
