import 'dart:async';

import 'package:get/get.dart';

import '../../Data/repositories/account_repository.dart';
import '../../Data/repositories/auth_repository.dart';
import '../../Data/repositories/profile_repository.dart';
import '../../Data/repositories/settings_repository.dart';
import '../../Models/hospital_programme.dart';
import '../../Models/meditation_audio.dart';
import '../../Models/theme_preferences.dart';
import '../../Models/user_profile.dart';
import '../../Models/user_settings.dart';
import '../../services/reminder_scheduler.dart';
import '../../services/theme_controller.dart';
import '../app/app_info.dart';
import '../app/app_routes.dart';
import '../app/user_session.dart';
import '../programme/wellbeing_programme_controller.dart';
import '../reminders/reminder_controller.dart';
import '../shared/app_feedback.dart';

/// Settings: the tab, its sub-screens (Reminders, Theme, Privacy) and the
/// pushed Settings route share this one ViewModel. Every change is saved at
/// once, one field at a time.
class SettingsViewModel extends GetxController {
  SettingsViewModel(
    this._authRepository, {
    SettingsRepository? settings,
    ProfileRepository? profiles,
    AccountRepository? account,
    ThemeController? theme,
    WellbeingProgrammeController? programme,
    ReminderController? reminders,
    this.cleanupDelay = const Duration(milliseconds: 700),
    void Function()? goToWelcome,
  }) : _settingsRepository = settings,
       _profiles = profiles,
       _account = account,
       _theme = theme,
       _programme = programme,
       _reminders = reminders,
       _goToWelcome = goToWelcome ?? _openWelcome;

  final AuthRepository _authRepository;
  final SettingsRepository? _settingsRepository;
  final ProfileRepository? _profiles;
  final AccountRepository? _account;
  final ThemeController? _theme;
  final WellbeingProgrammeController? _programme;
  final ReminderController? _reminders;

  /// How long to wait, after moving to Welcome, before the old screens'
  /// ViewModels are removed, so they are not taken away while their screens
  /// are still on show.
  final Duration cleanupDelay;
  final void Function() _goToWelcome;

  final Rxn<UserProfile> profile = Rxn<UserProfile>();
  final Rxn<UserSettings> settings = Rxn<UserSettings>();
  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;

  /// Signing out is under way.
  final RxBool isLoggingOut = false.obs;

  /// "Download my data" is being built.
  final RxBool isExporting = false.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
    unawaited(_programme?.loadMembership());
  }

  Future<void> load() async {
    isLoading.value = true;
    hasError.value = false;
    try {
      final List<Object?> results = await Future.wait(<Future<Object?>>[
        _profiles?.getCurrentUserProfile() ?? Future<Object?>.value(),
        _settingsRepository?.load() ?? Future<Object?>.value(),
      ]);
      profile.value = results[0] as UserProfile?;
      settings.value = results[1] as UserSettings?;
    } catch (_) {
      hasError.value = true;
    } finally {
      if (!isClosed) {
        isLoading.value = false;
      }
    }
  }

  /// Reloads the profile after Edit profile saved.
  Future<void> refreshProfile() async {
    try {
      profile.value = await _profiles?.getCurrentUserProfile();
    } catch (_) {}
  }

  // What the Settings screen shows.

  /// The user's hospital, or null for someone not in one (no row).
  HospitalMembership? get hospital => _programme?.membership.value;

  // Reminders page: what the phone allows and what comes next.

  /// Null while unknown (or without the reminders, in tests).
  ReminderPermission? get reminderPermission => _reminders?.permission.value;

  bool get remindersBlocked => reminderPermission == ReminderPermission.blocked;

  bool get remindersNotAsked =>
      reminderPermission == ReminderPermission.notAsked;

  /// "Today 20:00 · Mood check-in", or null when nothing is planned.
  String? get nextReminderLine => _reminders?.nextLine;

  /// When the Reminders page opens: the permission may have changed.
  void refreshReminders() {
    final ReminderController? reminders = _reminders;
    if (reminders != null) {
      unawaited(reminders.refreshPermission());
      reminders.rebuild();
    }
  }

  Future<void> turnOnReminders() async {
    await _reminders?.requestPermission();
  }

  Future<void> openPhoneSettings() async {
    await _reminders?.openPhoneSettings();
  }

  /// "Send a test reminder": shown at once; when the phone blocks or was
  /// never asked, the card's own action instead.
  Future<void> sendTestReminder() async {
    if (remindersBlocked) {
      await openPhoneSettings();
    } else if (remindersNotAsked) {
      await turnOnReminders();
    } else {
      await _reminders?.sendTest();
    }
  }

  /// "Nurse · Medical ward", or just the role.
  String get profileLine {
    final UserProfile? p = profile.value;
    if (p == null) {
      return '';
    }
    final String role = p.role.trim();
    final String dept = p.department.trim();
    if (role.isEmpty) {
      return dept;
    }
    return dept.isEmpty ? role : '$role · $dept';
  }

  String get email => _authRepository.currentUser?.email ?? '';

  /// Google-only accounts have no password to change.
  bool get canChangePassword => !_authRepository.isGoogleOnly;

  bool get isGoogleOnly => _authRepository.isGoogleOnly;

  String get version => AppInfo.version;

  bool get hasSettings => _settingsRepository != null;

  bool get hasTheme => _theme != null;

  String get themeLabel => _theme?.mode.value.label ?? 'Match phone';

  String get remindersLabel => settings.value?.remindersSummary ?? '';

  AmbientChoice get sound =>
      AmbientChoice.fromId(settings.value?.meditationSound);

  double get soundVolume =>
      settings.value?.meditationSoundVolume ?? UserSettings.defaultVolume;

  ThemeController? get theme => _theme;

  // Saving. Each change is written at once, then a small "Saved" toast.

  Future<void> _save(
    Future<UserSettings?> Function(SettingsRepository) run,
  ) async {
    final SettingsRepository? repo = _settingsRepository;
    if (repo == null) {
      return;
    }
    try {
      final UserSettings? next = await run(repo);
      if (next != null) {
        settings.value = next;
        showSavedToast();
      }
    } catch (_) {
      showMindMateSnackBar('Not saved', 'Check your connection and try again.');
    }
  }

  /// [kind]: mood, journal, practice or checkinsDue.
  Future<void> setReminderOn(String kind, bool on) =>
      _save((SettingsRepository r) => r.setReminderOn(kind, on));

  Future<void> setReminderTime(String kind, String time) =>
      _save((SettingsRepository r) => r.setReminderTime(kind, time));

  /// False (and nothing saved) when it is the last day left.
  Future<bool> toggleDay(int day) async {
    final UserSettings? s = settings.value;
    if (s != null && s.reminders.toggleDay(day) == null) {
      showMindMateSnackBar(
        'Keep at least one day',
        'Reminders need at least one day.',
      );
      return false;
    }
    await _save((SettingsRepository r) => r.toggleDay(day));
    return true;
  }

  Future<void> setQuietHoursOn(bool on) =>
      _save((SettingsRepository r) => r.setQuietHoursOn(on));

  Future<void> setQuietHoursStart(String time) =>
      _save((SettingsRepository r) => r.setQuietHoursStart(time));

  Future<void> setQuietHoursEnd(String time) =>
      _save((SettingsRepository r) => r.setQuietHoursEnd(time));

  Future<void> setHideReminderText(bool hide) =>
      _save((SettingsRepository r) => r.setHideReminderText(hide));

  /// The same choice the meditation player's "Background sound" sheet makes.
  Future<void> selectSound(AmbientChoice choice) =>
      _save((SettingsRepository r) => r.setMeditationSound(choice.id));

  /// While the slider moves: shown only.
  void previewVolume(double v) {
    final UserSettings? s = settings.value;
    if (s != null) {
      settings.value = s.copyWith(
        meditationSoundVolume: MeditationAudioRules.clampVolume(v),
      );
    }
  }

  Future<void> saveVolume() =>
      _save((SettingsRepository r) => r.setMeditationSoundVolume(soundVolume));

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _theme?.setMode(mode);
  }

  Future<void> setDarkAfterSunset(bool on) async {
    await _theme?.setDarkAfterSunset(on);
  }

  // Data.

  Future<void> downloadMyData() async {
    final AccountRepository? account = _account;
    if (account == null || isExporting.value) {
      return;
    }
    isExporting.value = true;
    try {
      await account.downloadMyData();
    } catch (_) {
      showMindMateSnackBar(
        'Could not make the file',
        'Check your connection and try again.',
      );
    } finally {
      if (!isClosed) {
        isExporting.value = false;
      }
    }
  }

  // Navigation.

  Future<void> openEditProfile() async {
    await Get.toNamed<void>(AppRoutes.settingsProfile);
    await refreshProfile();
  }

  void openHospital() => Get.toNamed<void>(AppRoutes.settingsHospital);

  void openReminders() => Get.toNamed<void>(AppRoutes.settingsReminders);

  void openTheme() => Get.toNamed<void>(AppRoutes.settingsTheme);

  void openPrivacy() => Get.toNamed<void>(AppRoutes.settingsPrivacy);

  void openDeleteAccount() =>
      Get.toNamed<void>(AppRoutes.settingsDeleteAccount);

  void changePassword() {
    Get.toNamed<void>(
      AppRoutes.changePassword,
      arguments: <String, dynamic>{'origin': 'settings'},
    );
  }

  void openSupport() => Get.toNamed<void>(AppRoutes.support);

  /// A page that does not exist yet opens a simple "Coming soon" page.
  void openInfo(String title) =>
      Get.toNamed<void>(AppRoutes.infoPage, arguments: title);

  // Signing out.

  /// Signs out of Firebase and Google, goes to Welcome with no way back to a
  /// signed-in screen, and then removes everything kept in memory for the
  /// person who was signed in. If signing out fails the screen stays and says
  /// so; nothing is removed.
  Future<void> logout() async {
    if (isLoggingOut.value) {
      return;
    }
    isLoggingOut.value = true;
    try {
      await _authRepository.logout();
    } catch (_) {
      isLoggingOut.value = false;
      showMindMateSnackBar(
        'Could not sign out',
        'Please check your connection and try again.',
      );
      return;
    }

    _settingsRepository?.clear();
    _goToWelcome();
    await Future<void>.delayed(cleanupDelay);
    UserSession.clearControllers();
  }

  static void _openWelcome() {
    Get.offAllNamed(AppRoutes.welcome);
  }
}
