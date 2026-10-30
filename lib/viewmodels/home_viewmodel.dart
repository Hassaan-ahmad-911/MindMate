import 'dart:async';

import 'package:get/get.dart';

import '../Data/repositories/auth_repository.dart';
import '../Data/repositories/home_repository.dart';
import '../Data/repositories/meditation_repository.dart';
import '../Data/repositories/mood_repository.dart';
import '../Data/repositories/profile_repository.dart';
import '../Models/home_dashboard.dart';
import '../Models/hospital_programme.dart';
import '../Models/meditation_log_entry.dart';
import '../Models/meditation_models.dart';
import '../Models/meditation_stats.dart';
import '../Models/meditation_suggester.dart';
import '../Models/mood_model.dart';
import '../Models/mood_stats.dart';
import '../Models/profile_options.dart';
import '../Models/programme_schedule.dart';
import '../Models/user_profile.dart';
import '../ui/app/app_routes.dart';
import '../ui/programme/wellbeing_programme_controller.dart';
import '../ui/reminders/reminder_controller.dart';
import '../ui/shared/app_feedback.dart';

/// How far one section of the dashboard has got. Each section loads, and
/// fails, on its own.
enum SectionStatus { loading, ready, failed }

/// The dashboard. It reads moods, meditation and the profile through their own
/// repositories and uses the same calculations as those modules (mood streak,
/// the practice suggestion), so the numbers always agree with them.
class HomeViewModel extends GetxController {
  HomeViewModel(
    this._authRepository,
    this._moodRepository,
    this._profileRepository,
    this._meditationRepository,
    this._homeRepository, {
    DateTime Function()? clock,
    bool Function(String route)? routeExists,
    this.bubbleDelay = const Duration(seconds: 3),
    WellbeingProgrammeController? programme,
    ReminderController? reminders,
  }) : _clock = clock ?? DateTime.now,
       _reminders = reminders,
       _routeExists = routeExists ?? _isRegistered,
       _programme = programme,
       _programmeLoading = programme != null;

  final AuthRepository _authRepository;
  final MoodRepository _moodRepository;
  final ProfileRepository _profileRepository;
  final MeditationRepository _meditationRepository;
  final HomeRepository _homeRepository;
  final DateTime Function() _clock;
  final bool Function(String route) _routeExists;

  /// The hospital programme; null in tests that do not use it.
  final WellbeingProgrammeController? _programme;

  /// The gentle reminders; null in tests that do not use them.
  final ReminderController? _reminders;

  /// How long after the page appears the speech bubble pops in.
  final Duration bubbleDelay;

  static bool _isRegistered(String route) =>
      Get.routeTree.matchRoute(route).route != null;

  // ---------------------------------------------------------------------------
  // State.
  // ---------------------------------------------------------------------------

  final Rx<SectionStatus> profileStatus = SectionStatus.loading.obs;
  final Rx<SectionStatus> moodStatus = SectionStatus.loading.obs;
  final Rx<SectionStatus> meditationStatus = SectionStatus.loading.obs;

  final Rxn<UserProfile> profile = Rxn<UserProfile>();

  /// The last 90 days, newest first.
  final RxList<MoodModel> moodHistory = <MoodModel>[].obs;

  /// Practices from the last 90 days, newest first.
  final RxList<MeditationLogEntry> meditationLogs = <MeditationLogEntry>[].obs;

  /// How many guided practices there are (breathing practices not counted).
  final RxnInt guidedPracticeCount = RxnInt();

  final Rxn<MeditationSuggestion> suggestion = Rxn<MeditationSuggestion>();

  /// Unread notifications from elsewhere (none yet). The bell's gold dot also
  /// shows when Today has something ready now.
  final RxInt unreadNotifications = 0.obs;

  /// The speech bubble over the robot, or null for none.
  final RxnString bubbleText = RxnString();

  /// For users in a hospital: what today's check-ins are worked out from.
  /// Null for everyone else, who keep the original mood card.
  final Rxn<ProgrammeStatus> programmeStatus = Rxn<ProgrammeStatus>();
  bool _programmeLoading;

  /// True when the page plays its entrance animations: the first time it
  /// appears in an app launch, with reduce-motion off.
  bool animateIntro = false;

  Timer? _bubbleTimer;
  bool _bubbleDue = false;
  bool _bubbleDone = false;
  Future<bool>? _firstOpenToday;

  @override
  void onInit() {
    super.onInit();
    unawaited(loadAll());
    // The once-a-day evaluation, and an alert not shown yet.
    final WellbeingProgrammeController? programme = _programme;
    if (programme != null) {
      unawaited(programme.homeOpened());
    }
    // Plans the reminders, opens one tapped before the app was ready, or
    // (once) the "Gentle reminders" page.
    unawaited(_reminders?.homeOpened());
  }

  // ---------------------------------------------------------------------------
  // Loading.
  // ---------------------------------------------------------------------------

  /// Loads every section at once. Each one shows its own skeleton and its own
  /// failure.
  Future<void> loadAll() async {
    profileStatus.value = SectionStatus.loading;
    moodStatus.value = SectionStatus.loading;
    meditationStatus.value = SectionStatus.loading;
    await Future.wait(<Future<void>>[
      _loadProfile(),
      _loadMoods(),
      _loadMeditation(),
      _loadProgramme(),
    ]);
  }

  /// Pull to refresh: the same, but what is on screen stays until the new
  /// numbers arrive.
  Future<void> refreshAll() async {
    await Future.wait(<Future<void>>[
      _loadProfile(),
      _loadMoods(),
      _loadMeditation(),
      _loadProgramme(),
    ]);
  }

  /// When the user comes back from another screen: the mood card and the
  /// stats are brought up to date without any skeleton.
  Future<void> refreshQuiet() async {
    await Future.wait(<Future<void>>[
      _loadMoods(),
      _loadMeditation(),
      _loadProgramme(),
    ]);
  }

  Future<void> retryProfile() async {
    profileStatus.value = SectionStatus.loading;
    await _loadProfile();
  }

  Future<void> retryMood() async {
    moodStatus.value = SectionStatus.loading;
    await _loadMoods();
  }

  Future<void> retryMeditation() async {
    meditationStatus.value = SectionStatus.loading;
    await _loadMeditation();
  }

  Future<void> _loadProfile() async {
    try {
      if (_authRepository.currentUser == null) {
        profile.value = null;
        profileStatus.value = SectionStatus.ready;
        return;
      }
      profile.value = await _profileRepository.getCurrentUserProfile();
      profileStatus.value = SectionStatus.ready;
    } catch (_) {
      // The header and the check-in card can do without it.
      if (profile.value == null) {
        profileStatus.value = SectionStatus.failed;
      }
    }
  }

  Future<void> _loadMoods() async {
    try {
      final List<MoodModel> moods = await _moodRepository.getRecentWindow(
        now: _clock(),
      );
      moodHistory.assignAll(moods);
      moodStatus.value = SectionStatus.ready;
      _updateSuggestion();
      unawaited(_showBubbleIfDue());
    } catch (_) {
      if (moodStatus.value != SectionStatus.ready) {
        moodStatus.value = SectionStatus.failed;
      }
      unawaited(_showBubbleIfDue());
    }
  }

  Future<void> _loadMeditation() async {
    try {
      await _meditationRepository.loadContent();
      final List<MeditationLogEntry> logs = await _meditationRepository
          .getRecentLogs(now: _clock());
      meditationLogs.assignAll(logs);
      guidedPracticeCount.value = _meditationRepository.sessions
          .where((MeditationSession session) => !session.isBreathing)
          .length;
      meditationStatus.value = SectionStatus.ready;
      _updateSuggestion();
    } catch (_) {
      if (meditationStatus.value != SectionStatus.ready) {
        meditationStatus.value = SectionStatus.failed;
      }
    }
  }

  Future<void> _loadProgramme() async {
    final WellbeingProgrammeController? programme = _programme;
    if (programme == null) {
      return;
    }
    try {
      programmeStatus.value = await programme.loadStatus();
    } catch (_) {
      // What is on screen stays; users not in a hospital see the mood card.
    } finally {
      _programmeLoading = false;
      unawaited(_showBubbleIfDue());
    }
  }

  void _updateSuggestion() {
    if (meditationStatus.value != SectionStatus.ready) {
      return;
    }
    suggestion.value = MeditationSuggester.suggest(
      sessions: _meditationRepository.sessions,
      now: _clock(),
      completedCounts: MeditationStats.completedCounts(meditationLogs),
      latestMoodToday: _latestMoodToday,
    );
  }

  // ---------------------------------------------------------------------------
  // Header.
  // ---------------------------------------------------------------------------

  DateTime get now => _clock();

  DayPart get dayPart => DayPart.of(_clock());

  String get greetingLine => dayPart.greeting;

  /// The first name, or "there" when none is known.
  String get firstName {
    final String fromProfile = profile.value?.firstName.trim() ?? '';
    if (fromProfile.isNotEmpty && fromProfile != 'User') {
      return fromProfile;
    }
    final String fromAuth =
        _authRepository.currentUser?.displayName?.trim() ?? '';
    if (fromAuth.isNotEmpty) {
      return fromAuth.split(RegExp(r'\s+')).first;
    }
    return 'there';
  }

  String get initials {
    final String name = profile.value?.name.trim() ?? '';
    if (name.isNotEmpty && name != 'User') {
      return HomeText.initials(name);
    }
    return HomeText.initials(_authRepository.currentUser?.displayName);
  }

  String get imageUrl {
    final String fromProfile = profile.value?.imageUrl.trim() ?? '';
    if (fromProfile.isNotEmpty) {
      return fromProfile;
    }
    return _authRepository.currentUser?.photoURL?.trim() ?? '';
  }

  bool get hasUnreadNotifications =>
      unreadNotifications.value > 0 || (_reminders?.hasReadyNow ?? false);

  /// The bell: "Today".
  void openToday() => unawaited(open(AppRoutes.today));

  // ---------------------------------------------------------------------------
  // Mood card and stats.
  // ---------------------------------------------------------------------------

  /// The newest mood logged today, if any.
  MoodModel? get _latestMoodToday {
    final DateTime today = _clock();
    for (final MoodModel mood in moodHistory) {
      if (MoodStats.isSameDay(mood.date, today)) {
        return mood;
      }
    }
    return null;
  }

  /// Whether a mood was logged today. Null until the moods have loaded (or
  /// when they could not be).
  bool? get moodLoggedToday {
    if (moodStatus.value != SectionStatus.ready) {
      return null;
    }
    return _latestMoodToday != null;
  }

  MoodCardContent get moodCard {
    return MoodCardContent.of(
      moodToday: _latestMoodToday?.mood,
      reminderPreference: profile.value?.reminderPreference ?? '',
      now: _clock(),
    );
  }

  int get moodStreak => MoodStats.streak(
    moodHistory.map((MoodModel mood) => mood.date),
    now: _clock(),
  );

  WeekWord get weekWord => WeekMood.of(moodHistory, _clock());

  int get calmMinutes =>
      MeditationStats.minutesThisWeek(meditationLogs, now: _clock());

  String get suggestionHeading => HomeText.suggestionHeading(_clock());

  // ---------------------------------------------------------------------------
  // Today's check-ins (users in a hospital).
  // ---------------------------------------------------------------------------

  /// Mood plus every check-in due today, or null for someone not in a
  /// hospital (they keep the original mood card).
  List<ScheduleRow>? get todayCheckIns {
    final ProgrammeStatus? status = programmeStatus.value;
    if (status == null) {
      return null;
    }
    return ProgrammeSchedule.today(
      config: status.config,
      joinedAt: status.membership.joinedAt,
      lastDone: status.lastDone,
      lastMood: moodHistory.isEmpty ? null : moodHistory.first.date,
      now: _clock(),
    );
  }

  /// The second line under a row: "Logged at 19:40 · Calm", "4 questions ·
  /// due today".
  String checkInSubtitle(ScheduleRow row) {
    if (row.isMood) {
      final MoodModel? mood = _latestMoodToday;
      if (row.done && mood != null) {
        final String time =
            '${mood.date.hour.toString().padLeft(2, '0')}:'
            '${mood.date.minute.toString().padLeft(2, '0')}';
        return mood.mood.trim().isEmpty
            ? 'Logged at $time'
            : 'Logged at $time · ${mood.mood.trim()}';
      }
      return 'How are you feeling?';
    }
    if (row.done) {
      return 'Done today';
    }
    final Map<String, int> counts =
        programmeStatus.value?.questionCounts ?? const <String, int>{};
    int questions = 0;
    for (final String id in row.assessmentIds) {
      questions += counts[id] ?? 0;
    }
    return questions > 0 ? '$questions questions · due today' : 'Due today';
  }

  /// "Start": the mood logging flow, or that check-in directly.
  void startCheckIn(ScheduleRow row) {
    final String? id = row.startId;
    if (id == null) {
      logMood();
    } else {
      unawaited(open('${AppRoutes.assessments}/$id'));
    }
  }

  // ---------------------------------------------------------------------------
  // Explore.
  // ---------------------------------------------------------------------------

  static const Map<ExploreId, String> _exploreRoutes = <ExploreId, String>{
    ExploreId.mood: AppRoutes.moodTracking,
    ExploreId.journal: AppRoutes.journal,
    ExploreId.meditation: AppRoutes.meditation,
    ExploreId.aiChat: AppRoutes.aiChat,
    ExploreId.checkIns: AppRoutes.assessments,
    ExploreId.reports: AppRoutes.reports,
    ExploreId.takeABreak: AppRoutes.games,
    ExploreId.emotionCheck: AppRoutes.emotionCheck,
  };

  /// Whether the meditation module is built, so the suggestion card is shown.
  bool get meditationAvailable => _routeExists(AppRoutes.meditation);

  List<ExploreTile> get exploreTiles {
    return ExploreTiles.build(
      routeExists: _routeExists,
      routes: _exploreRoutes,
      moodLoggedToday: moodLoggedToday,
      practiceCount: guidedPracticeCount.value,
    );
  }

  // ---------------------------------------------------------------------------
  // Going to other screens.
  // ---------------------------------------------------------------------------

  /// Opens a screen, and brings the dashboard up to date when the user
  /// returns.
  Future<void> open(String route, {Object? arguments}) async {
    await Get.toNamed<dynamic>(route, arguments: arguments);
    unawaited(refreshQuiet());
  }

  void openTile(ExploreTile tile) {
    if (tile.isLive) {
      unawaited(open(tile.route));
    }
  }

  void logMood() => unawaited(open(AppRoutes.moodLog));

  /// The photo opens the same Edit profile screen as Settings.
  void openProfile() => unawaited(open(AppRoutes.settingsProfile));

  void openSupport() => unawaited(open(AppRoutes.support));

  void openSuggestion() {
    final MeditationSuggestion? current = suggestion.value;
    if (current != null) {
      unawaited(
        open(AppRoutes.meditationDetails, arguments: current.session.id),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // The first check-in.
  // ---------------------------------------------------------------------------

  /// Whether Home offers "Finish your check-in": the user has not finished or
  /// dismissed it yet. People who signed up before the check-in existed have
  /// no status, so they never see it.
  bool get showCheckInCard =>
      profile.value?.checkInStatus == ProfileOptions.checkInPending;

  /// Updates the card when the check-in state changes elsewhere.
  void setCheckInStatus(String status) {
    final UserProfile? current = profile.value;
    if (current == null) {
      return;
    }
    profile.value = UserProfile(
      uid: current.uid,
      name: current.name,
      email: current.email,
      imageUrl: current.imageUrl,
      bio: current.bio,
      age: current.age,
      gender: current.gender,
      role: current.role,
      shiftPattern: current.shiftPattern,
      yearsInHealthcare: current.yearsInHealthcare,
      department: current.department,
      reminderPreference: current.reminderPreference,
      goals: current.goals,
      checkInStatus: status,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt,
    );
  }

  void openCheckIn() => unawaited(open(AppRoutes.checkInIntro));

  /// The cross on the card: the check-in is left for good.
  Future<void> dismissCheckIn() async {
    setCheckInStatus(ProfileOptions.checkInDismissed);
    try {
      await _profileRepository.updateCheckInStatus(
        ProfileOptions.checkInDismissed,
      );
    } on Object {
      setCheckInStatus(ProfileOptions.checkInPending);
      showMindMateSnackBar(
        'Could not dismiss this',
        'Please try again in a moment.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // The entrance: the name, the sun or moon, and the speech bubble.
  // ---------------------------------------------------------------------------

  /// Called by the screen when it first appears. Returns whether to play the
  /// entrance animations: only the first time in an app launch, and never
  /// with reduce-motion on. The bubble follows the same once-per-launch rule;
  /// with reduce-motion on it appears as soon as its line is known.
  bool startIntro({required bool reduceMotion}) {
    final bool first = HomeIntro.claim();
    animateIntro = first && !reduceMotion;
    if (first) {
      _firstOpenToday = _recordOpen();
      _bubbleTimer?.cancel();
      _bubbleTimer = Timer(reduceMotion ? Duration.zero : bubbleDelay, () {
        _bubbleDue = true;
        unawaited(_showBubbleIfDue());
      });
    }
    return animateIntro;
  }

  /// Notes that the app was opened today, and says whether it was the first
  /// time today.
  Future<bool> _recordOpen() async {
    final DateTime now = _clock();
    final String today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    try {
      final String? last = await _homeRepository.lastOpenDay();
      await _homeRepository.setLastOpenDay(today);
      return last != today;
    } catch (_) {
      return false;
    }
  }

  Future<void> _showBubbleIfDue() async {
    if (!_bubbleDue || _bubbleDone) {
      return;
    }
    // Wait for the moods, so "no mood today" is never guessed, and for the
    // hospital's check-ins.
    if (moodStatus.value == SectionStatus.loading || _programmeLoading) {
      return;
    }
    _bubbleDone = true;
    final bool firstOpen = await (_firstOpenToday ?? Future<bool>.value(false));
    final List<ScheduleRow>? checkIns = todayCheckIns;
    final String? checkInsLeft = checkIns == null
        ? null
        : ProgrammeSchedule.bubble(checkIns);
    bubbleText.value =
        checkInsLeft ??
        HomeBubble.pick(
          streak: moodStreak,
          moodLoggedToday: moodLoggedToday,
          dayPart: dayPart,
          firstOpenToday: firstOpen,
        );
  }

  @override
  void onClose() {
    _bubbleTimer?.cancel();
    super.onClose();
  }
}
