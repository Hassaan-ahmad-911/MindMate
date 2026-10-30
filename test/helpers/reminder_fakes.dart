import 'package:mindmate/Data/repositories/reminder_repository.dart';
import 'package:mindmate/Models/reminder_plan.dart';
import 'package:mindmate/Models/user_settings.dart';
import 'package:mindmate/services/reminder_scheduler.dart';

/// Records what would reach the notification plugin.
class FakeScheduler implements ReminderScheduler {
  final List<String> calls = <String>[];
  List<ScheduledReminder> scheduled = <ScheduledReminder>[];
  final List<ScheduledReminder> shown = <ScheduledReminder>[];
  bool? enabled = true;
  bool grant = true;
  String? launch;
  void Function(String? payload)? onTap;

  @override
  Future<void> init({required void Function(String? payload) onTap}) async {
    calls.add('init');
    this.onTap = onTap;
  }

  @override
  Future<String?> launchPayload() async => launch;

  @override
  Future<void> replaceAll(List<ScheduledReminder> reminders) async {
    calls.add('cancelAll');
    calls.add('schedule');
    scheduled = reminders;
  }

  @override
  Future<void> cancelAll() async {
    calls.add('cancelAll');
    scheduled = <ScheduledReminder>[];
  }

  @override
  Future<void> showNow(ScheduledReminder reminder) async {
    calls.add('show');
    shown.add(reminder);
  }

  @override
  Future<bool?> notificationsEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async {
    calls.add('request');
    enabled = grant;
    return grant;
  }

  @override
  Future<void> openSettings() async => calls.add('openSettings');
}

/// Answers with [snapshot] (built from [settings] and the flags below).
class FakeReminderRepository implements ReminderRepository {
  FakeReminderRepository({UserSettings? settings})
    : settings = settings ?? UserSettings.defaults();

  UserSettings settings;
  bool signedInValue = true;
  bool moodDoneToday = false;
  bool asked = false;
  bool pageShown = false;
  int loads = 0;

  @override
  bool get signedIn => signedInValue;

  @override
  Future<bool> permissionAsked() async => asked;

  @override
  Future<void> setPermissionAsked() async => asked = true;

  @override
  Future<bool> permissionPageShown() async => pageShown;

  @override
  Future<void> setPermissionPageShown() async => pageShown = true;

  @override
  Future<ReminderSnapshot> load(DateTime now) async {
    loads += 1;
    return ReminderSnapshot(
      inputs: ReminderInputs(
        settings: settings.reminders,
        now: now,
        moodDoneToday: moodDoneToday,
      ),
      hideText: settings.hideReminderText,
    );
  }
}

/// Default settings with the mood reminder at [mood] and quiet hours from
/// [quietFrom] to [quietTo] when given.
UserSettings settingsWith({
  String mood = '20:00',
  bool moodOn = true,
  String? journal,
  String? practice,
  bool checkInsDue = false,
  List<int> days = ReminderSettings.allDays,
  String? quietFrom,
  String? quietTo,
  bool hide = false,
}) {
  final UserSettings base = UserSettings.defaults();
  return base.copyWith(
    hideReminderText: hide,
    reminders: base.reminders.copyWith(
      mood: ReminderSlot(on: moodOn, time: mood),
      journal: ReminderSlot(on: journal != null, time: journal ?? '21:00'),
      practice: ReminderSlot(on: practice != null, time: practice ?? '07:30'),
      checkinsDue: ReminderSlot(on: checkInsDue),
      days: days,
      quietHours: QuietHours(
        on: quietFrom != null,
        start: quietFrom ?? '23:00',
        end: quietTo ?? '07:00',
      ),
    ),
  );
}
