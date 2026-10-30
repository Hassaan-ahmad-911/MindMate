import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../Data/repositories/reminder_repository.dart';
import '../../Models/reminder_plan.dart';
import '../../Models/today_items.dart';
import '../../services/reminder_scheduler.dart';
import '../app/app_routes.dart';
import '../app/post_auth_routing.dart';
import '../programme/wellbeing_programme_controller.dart';

/// Asks for the reminders to be planned again (after a save or a settings
/// change). Does nothing when the reminders are not set up (tests).
void notifyRemindersChanged() {
  if (Get.isRegistered<ReminderController>()) {
    Get.find<ReminderController>().rebuild();
  }
}

/// After a mood, journal, practice or check-in is saved: the hospital
/// programme evaluates and the reminders are planned again.
void notifyDataSaved() {
  notifyWellbeingProgramme();
  notifyRemindersChanged();
}

/// The gentle reminders: decides when the 14-day plan is rebuilt, hands it
/// to the [ReminderScheduler], and opens the right screen when one is
/// tapped. Rebuilds run in the background and never show an error.
class ReminderController extends GetxService with WidgetsBindingObserver {
  ReminderController(
    this._repository,
    this._scheduler, {
    DateTime Function()? clock,
    this.debounce = const Duration(milliseconds: 600),
    void Function(String route, {Object? arguments})? navigate,
    bool Function()? canNavigate,
    this.observeLifecycle = true,
  }) : _clock = clock ?? DateTime.now,
       _navigate = navigate ?? _toNamed,
       _canNavigate = canNavigate ?? _appIsPastSetup;

  final ReminderRepository _repository;
  final ReminderScheduler _scheduler;
  final DateTime Function() _clock;
  final void Function(String route, {Object? arguments}) _navigate;
  final bool Function() _canNavigate;

  /// Several saves in a row cause one rebuild.
  final Duration debounce;
  final bool observeLifecycle;

  /// The test reminder's id (the plan uses 1 to 60).
  static const int testId = 900;

  final Rx<ReminderPlan> plan = ReminderPlan.empty.obs;
  final Rx<TodaySections> today = TodaySections.empty.obs;

  /// Null until the phone has been asked.
  final Rxn<ReminderPermission> permission = Rxn<ReminderPermission>();

  ReminderSnapshot? _snapshot;
  Timer? _timer;
  Future<void>? _running;
  bool _again = false;
  String? _pendingTap;

  /// "Ready now" is not empty: the gold dot on the Home bell.
  bool get hasReadyNow => today.value.ready.isNotEmpty;

  bool get inProgramme => _snapshot?.inputs.inProgramme ?? false;

  @override
  void onInit() {
    super.onInit();
    if (observeLifecycle) {
      WidgetsBinding.instance.addObserver(this);
    }
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      await _scheduler.init(onTap: handleTap);
      _pendingTap ??= await _scheduler.launchPayload();
    } catch (_) {
      // No notifications on this platform.
    }
    await refreshPermission();
    rebuild();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Also picks up a new time zone, which the scheduler re-reads.
      unawaited(refreshPermission());
      rebuild();
    }
  }

  // ---------------------------------------------------------------------------
  // Planning.
  // ---------------------------------------------------------------------------

  /// Plans again shortly (debounced).
  void rebuild() {
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(rebuildNow()));
  }

  /// Cancels every pending reminder and schedules the next 14 days again.
  Future<void> rebuildNow() async {
    _timer?.cancel();
    final Future<void>? running = _running;
    if (running != null) {
      _again = true;
      await running;
      return;
    }
    _running = _rebuild();
    try {
      await _running;
    } finally {
      _running = null;
    }
    if (_again) {
      _again = false;
      await rebuildNow();
    }
  }

  Future<void> _rebuild() async {
    if (!_repository.signedIn) {
      return;
    }
    try {
      final DateTime now = _clock();
      final ReminderSnapshot snap = await _repository.load(now);
      if (!_repository.signedIn) {
        return; // Signed out meanwhile.
      }
      _snapshot = snap;
      final ReminderPlan next = ReminderPlanner.plan(snap.inputs);
      plan.value = next;
      today.value = TodayBuilder.build(
        inputs: snap.inputs,
        programmeRows: snap.programmeRows,
        checkInsDue: snap.checkInsDue,
        questionCounts: snap.questionCounts,
        moodLoggedAt: snap.moodLoggedAt,
        practiceDoneLine: snap.practiceDoneLine,
      );
      await _scheduler.replaceAll(scheduled(next, hidden: snap.hideText));
    } catch (_) {
      // Tried again on the next save, resume or app start.
    }
  }

  /// The plan as notifications: worded (or hidden), numbered 1 to 60, each
  /// taken off the screen when the next one is due.
  static List<ScheduledReminder> scheduled(
    ReminderPlan plan, {
    required bool hidden,
  }) {
    final List<PlannedReminder> list = plan.notifications;
    return <ScheduledReminder>[
      for (int i = 0; i < list.length; i += 1)
        _toScheduled(
          list[i],
          id: i + 1,
          hidden: hidden,
          replacedAfter: i + 1 < list.length
              ? list[i + 1].at.difference(list[i].at)
              : null,
        ),
    ];
  }

  static ScheduledReminder _toScheduled(
    PlannedReminder r, {
    required int id,
    required bool hidden,
    Duration? replacedAfter,
  }) {
    final ({String title, String body}) text = ReminderWording.of(
      r,
      hidden: hidden,
    );
    return ScheduledReminder(
      id: id,
      at: r.at,
      title: text.title,
      body: text.body,
      payload: r.payload,
      hidden: hidden,
      replacedAfter: replacedAfter,
    );
  }

  /// "Today 20:00 · Mood check-in", or null when nothing is planned.
  String? get nextLine {
    final PlannedReminder? next = plan.value.next;
    return next == null ? null : ReminderWording.nextLine(next, _clock());
  }

  /// Sign out and delete account: every reminder goes.
  Future<void> signedOut() async {
    _timer?.cancel();
    _snapshot = null;
    _pendingTap = null;
    plan.value = ReminderPlan.empty;
    today.value = TodaySections.empty;
    try {
      await _scheduler.cancelAll();
    } catch (_) {
      // Nothing scheduled on this platform.
    }
  }

  // ---------------------------------------------------------------------------
  // Permission.
  // ---------------------------------------------------------------------------

  Future<void> refreshPermission() async {
    try {
      final bool? enabled = await _scheduler.notificationsEnabled();
      if (enabled ?? true) {
        permission.value = ReminderPermission.enabled;
        return;
      }
      permission.value = await _repository.permissionAsked()
          ? ReminderPermission.blocked
          : ReminderPermission.notAsked;
    } catch (_) {
      permission.value = ReminderPermission.enabled;
    }
  }

  /// Asks the phone once; true when allowed.
  Future<bool> requestPermission() async {
    bool granted = false;
    try {
      await _repository.setPermissionAsked();
      granted = await _scheduler.requestPermission();
    } catch (_) {
      granted = false;
    }
    await refreshPermission();
    if (granted) {
      rebuild();
    }
    return granted;
  }

  Future<void> openPhoneSettings() async {
    try {
      await _scheduler.openSettings();
    } catch (_) {
      // Not available on this platform.
    }
  }

  Future<bool> permissionPageShown() async {
    try {
      return await _repository.permissionPageShown();
    } catch (_) {
      return true;
    }
  }

  Future<void> markPermissionPageShown() async {
    try {
      await _repository.setPermissionPageShown();
    } catch (_) {}
  }

  /// "Send a test reminder": one at once, following "Hide reminder text".
  Future<void> sendTest() async {
    bool hidden = _snapshot?.hideText ?? false;
    if (_snapshot == null && _repository.signedIn) {
      try {
        hidden = (await _repository.load(_clock())).hideText;
      } catch (_) {}
    }
    try {
      await _scheduler.showNow(
        _toScheduled(
          PlannedReminder(at: _clock(), kind: ReminderKind.test),
          id: testId,
          hidden: hidden,
        ),
      );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Taps.
  // ---------------------------------------------------------------------------

  /// A tapped reminder: opens its screen, or waits for Home when the app is
  /// still starting or signing in.
  void handleTap(String? payload) {
    if (payload == null) {
      return;
    }
    if (_canNavigate()) {
      open(payload);
    } else {
      _pendingTap = payload;
    }
  }

  /// When Home opens: plans again, then opens a reminder tapped before the
  /// app was ready, or (once) the "Gentle reminders" page.
  Future<void> homeOpened() async {
    rebuild();
    final String? pending = _pendingTap;
    _pendingTap = null;
    if (pending != null) {
      open(pending);
      return;
    }
    if (!await permissionPageShown()) {
      _navigate(AppRoutes.remindersPermission, arguments: fromHome);
    }
  }

  /// The argument when the page is opened over Home.
  static const String fromHome = 'fromHome';

  void open(String payload) => _navigate(routeFor(payload));

  /// The screen each reminder opens.
  static String routeFor(String payload) {
    if (payload.startsWith(ReminderTargets.checkInPrefix)) {
      return '${AppRoutes.assessments}/'
          '${payload.substring(ReminderTargets.checkInPrefix.length)}';
    }
    return switch (payload) {
      ReminderTargets.mood => AppRoutes.moodLog,
      ReminderTargets.journal => AppRoutes.journalNew,
      ReminderTargets.practice => AppRoutes.meditation,
      ReminderTargets.hub => AppRoutes.assessments,
      ReminderTargets.reminders => AppRoutes.settingsReminders,
      _ => AppRoutes.today,
    };
  }

  static void _toNamed(String route, {Object? arguments}) {
    Get.toNamed<void>(route, arguments: arguments);
  }

  static bool _appIsPastSetup() {
    final String route = Get.currentRoute;
    return !PostAuthRouting.openRoutes.contains(route) &&
        !<String>{
          AppRoutes.joinHospital,
          AppRoutes.createProfile,
          AppRoutes.profileWork,
          AppRoutes.checkInIntro,
          AppRoutes.checkInQuestion,
          AppRoutes.checkInDone,
          AppRoutes.remindersPermission,
        }.contains(route);
  }

  @override
  void onClose() {
    _timer?.cancel();
    if (observeLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.onClose();
  }
}
