import 'dart:async';

import 'package:get/get.dart';

import '../../Data/repositories/wellbeing_programme_repository.dart';
import '../../Models/hospital_programme.dart';
import '../../Models/programme_schedule.dart';
import '../app/app_routes.dart';
import '../app/post_auth_routing.dart';

/// Tells the programme that a mood, check-in or journal entry was saved.
/// Given to the repositories as their `onSaved`; does nothing when the
/// programme is not set up (tests, or before sign-in).
void notifyWellbeingProgramme() {
  if (Get.isRegistered<WellbeingProgrammeController>()) {
    Get.find<WellbeingProgrammeController>().dataSaved();
  }
}

/// The hospital programme for the signed-in user: their hospital, asking
/// the server to evaluate in the background, and showing "Someone will
/// reach out" once per alert.
///
/// Every call here runs in the background: it never blocks the user and
/// never shows an error. Nothing is logged.
class WellbeingProgrammeController extends GetxService {
  WellbeingProgrammeController(
    this._repository, {
    DateTime Function()? clock,
    this.retryDelay = const Duration(minutes: 2),
    void Function(WellbeingAlert alert)? showAlert,
    bool Function()? canShowAlert,
  }) : _clock = clock ?? DateTime.now,
       _showAlert = showAlert ?? _openAlertScreen,
       _canShowAlert = canShowAlert ?? _appIsPastSetup;

  final WellbeingProgrammeRepository _repository;
  final DateTime Function() _clock;
  final void Function(WellbeingAlert alert) _showAlert;
  final bool Function() _canShowAlert;

  /// How long to wait before the one retry of a failed evaluation.
  final Duration retryDelay;

  /// Alerts older than this are history, never shown as new.
  static const Duration alertWindow = Duration(days: 14);

  /// The user's hospital, or null when they are not in one (or before it
  /// has loaded).
  final Rxn<HospitalMembership> membership = Rxn<HospitalMembership>();

  Future<HospitalMembership?>? _membershipLoad;
  Timer? _retry;
  bool _showing = false;

  bool get inProgramme => membership.value != null;

  /// Loads the hospital once per sign-in (again with [force]).
  Future<HospitalMembership?> loadMembership({bool force = false}) {
    if (force || _membershipLoad == null) {
      _membershipLoad = _fetchMembership();
    }
    return _membershipLoad!;
  }

  Future<HospitalMembership?> _fetchMembership() async {
    try {
      final HospitalMembership? found = await _repository.getMembership();
      membership.value = found;
      return found;
    } catch (_) {
      // Offline: try again next time it is needed.
      _membershipLoad = null;
      return membership.value;
    }
  }

  /// After joining: the hospital is known without another read.
  void joined(HospitalMembership value) {
    membership.value = value;
    _membershipLoad = Future<HospitalMembership?>.value(value);
  }

  /// The schedule's inputs, or null when the user is not in a hospital.
  Future<ProgrammeStatus?> loadStatus() async {
    final HospitalMembership? member = await loadMembership();
    if (member == null) {
      return null;
    }
    final ProgrammeConfig? config = await _repository.getConfig();
    if (config == null) {
      return null;
    }
    return ProgrammeStatus(
      membership: member,
      config: config,
      lastDone: await _repository.getLastDone(),
      questionCounts: await _repository.getQuestionCounts(),
    );
  }

  // ---------------------------------------------------------------------------
  // Asking the server to evaluate.
  // ---------------------------------------------------------------------------

  /// After a mood, check-in or journal entry is saved.
  void dataSaved() => unawaited(_evaluate());

  /// When Home opens: the once-a-day evaluation, then any alert not shown
  /// yet.
  Future<void> homeOpened() async {
    final HospitalMembership? member = await loadMembership();
    if (member == null) {
      return;
    }
    final String today = _dayKey(_clock());
    String? last;
    try {
      last = await _repository.lastEvaluatedDay();
    } catch (_) {
      last = null;
    }
    if (last != today) {
      await _evaluate(onSuccess: () => _repository.setLastEvaluatedDay(today));
    }
    await showPendingAlert();
  }

  Future<void> _evaluate({
    bool isRetry = false,
    Future<void> Function()? onSuccess,
  }) async {
    final HospitalMembership? member = await loadMembership();
    if (member == null) {
      return;
    }
    try {
      final EvaluateOutcome outcome = await _repository.evaluate();
      await onSuccess?.call();
      if (outcome.sent) {
        await showPendingAlert();
      }
    } catch (_) {
      // Offline or the server is busy: one more try a little later.
      if (!isRetry) {
        _retry?.cancel();
        _retry = Timer(
          retryDelay,
          () => unawaited(_evaluate(isRetry: true, onSuccess: onSuccess)),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // "Someone will reach out".
  // ---------------------------------------------------------------------------

  /// Shows the newest alert from the last two weeks that this phone has not
  /// shown yet, if the app is past the sign-in and setup screens.
  Future<void> showPendingAlert() async {
    if (_showing || !_canShowAlert()) {
      return;
    }
    _showing = true;
    try {
      final DateTime since = _clock().subtract(alertWindow);
      final List<WellbeingAlert> alerts = await _repository.getAlerts();
      final Set<String> seen = await _repository.seenAlertIds();
      final Iterable<WellbeingAlert> fresh = alerts.where(
        (WellbeingAlert a) => !seen.contains(a.id) && a.sentAt.isAfter(since),
      );
      if (fresh.isEmpty) {
        return;
      }
      // Older unseen ones are covered by the newest: mark them all.
      for (final WellbeingAlert a in fresh) {
        await _repository.markAlertSeen(a.id);
      }
      _showAlert(fresh.first);
    } catch (_) {
      // Shown next time instead.
    } finally {
      _showing = false;
    }
  }

  static void _openAlertScreen(WellbeingAlert alert) {
    Get.toNamed<void>(AppRoutes.wellbeingAlert, arguments: alert);
  }

  /// Not over the splash, sign-in, setup or the alert itself.
  static bool _appIsPastSetup() {
    final String route = Get.currentRoute;
    return !PostAuthRouting.openRoutes.contains(route) &&
        !_setupRoutes.contains(route);
  }

  static const Set<String> _setupRoutes = <String>{
    AppRoutes.joinHospital,
    AppRoutes.createProfile,
    AppRoutes.profileWork,
    AppRoutes.checkInIntro,
    AppRoutes.checkInQuestion,
    AppRoutes.checkInDone,
    AppRoutes.wellbeingAlert,
  };

  /// Forgets the signed-in user (sign out, account deleted).
  void reset() {
    _retry?.cancel();
    _retry = null;
    _membershipLoad = null;
    membership.value = null;
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  void onClose() {
    _retry?.cancel();
    super.onClose();
  }
}
