import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Data/repositories/account_repository.dart';
import 'package:mindmate/Data/repositories/auth_repository.dart';
import 'package:mindmate/Data/repositories/mood_repository.dart';
import 'package:mindmate/Data/repositories/settings_repository.dart';
import 'package:mindmate/services/account_deletion_service.dart';
import 'package:mindmate/Models/mood_model.dart';
import 'package:mindmate/Models/programme_schedule.dart';
import 'package:mindmate/Models/reminder_plan.dart';
import 'package:mindmate/Models/today_items.dart';
import 'package:mindmate/Models/user_settings.dart';
import 'package:mindmate/services/mood_firestore_service.dart';
import 'package:mindmate/services/reminder_scheduler.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/reminders/reminder_controller.dart';
import 'package:mindmate/ui/reminders/today_view.dart';
import 'package:mindmate/ui/reminders/today_viewmodel.dart';
import 'package:mindmate/ui/settings/delete_account_viewmodel.dart';
import 'package:mindmate/ui/settings/reminders_view.dart';
import 'package:mindmate/ui/settings/settings_viewmodel.dart';
import 'package:mindmate/ui/settings/widgets/reminders_widgets.dart';
import 'package:mindmate/ui/shared/app_theme_data.dart';
import 'package:mindmate/ui/shared/mindmate_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/auth_app.dart';
import 'helpers/home_fakes.dart';
import 'helpers/programme_fakes.dart';
import 'helpers/reminder_fakes.dart';
import 'helpers/settings_fakes.dart';

/// Thursday 29 October 2026, 18:00.
final DateTime evening = DateTime(2026, 10, 29, 18);

class _SavingMoodService extends MoodFirestoreService {
  @override
  Future<MoodModel> saveMood(MoodModel mood) async => mood;
}

/// Deleting always works; the reminders are what is tested.
class _DeletingAccount extends AccountRepository {
  _DeletingAccount()
    : super(
        data: FakeAccountData(),
        auth: AuthRepository(
          FakeAuthService(),
          emailCodes: FakeEmailCodeService(),
        ),
        settings: SettingsRepository(FakeSettingsService()),
      );

  @override
  bool get isGoogleOnly => false;

  @override
  Future<void> reauthenticateWithPassword(String password) async {}

  @override
  Future<void> deleteAccount({void Function(DeletionStep)? onStep}) async {}
}

void main() {
  late FakeScheduler scheduler;
  late FakeReminderRepository repo;
  late List<String> routes;
  late bool canNavigate;

  ReminderController put({UserSettings? settings}) {
    scheduler = FakeScheduler();
    repo = FakeReminderRepository(settings: settings);
    routes = <String>[];
    canNavigate = true;
    return Get.put<ReminderController>(
      ReminderController(
        repo,
        scheduler,
        clock: () => evening,
        debounce: Duration.zero,
        observeLifecycle: false,
        navigate: (String route, {Object? arguments}) =>
            routes.add(arguments == null ? route : '$route ($arguments)'),
        canNavigate: () => canNavigate,
      ),
      permanent: true,
    );
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  setUp(() {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() => Get.reset());

  group('Rebuilding the plan', () {
    test('a mood save cancels and schedules again, skipping today', () async {
      put(settings: settingsWith(mood: '20:00'));
      await settle();
      expect(scheduler.scheduled.first.at, DateTime(2026, 10, 29, 20));

      scheduler.calls.clear();
      repo.moodDoneToday = true;
      final MoodRepository moods = MoodRepository(
        _SavingMoodService(),
        onSaved: notifyDataSaved,
      );
      await moods.saveMood(moodAt(DateTime(2026, 10, 29, 17), 'Calm'));
      await settle();

      expect(scheduler.calls, <String>['cancelAll', 'schedule']);
      expect(scheduler.scheduled.first.at, DateTime(2026, 10, 30, 20));
      expect(scheduler.scheduled.first.title, 'How are you feeling tonight?');
    });

    test('nothing is planned before sign-in', () async {
      put();
      repo.signedInValue = false;
      scheduler.calls.clear();
      await Get.find<ReminderController>().rebuildNow();
      expect(scheduler.calls, isEmpty);
    });

    test('"Hide reminder text" reaches every reminder', () async {
      put(
        settings: settingsWith(mood: '20:00', journal: '09:00', hide: true),
      );
      await settle();
      expect(scheduler.scheduled, isNotEmpty);
      for (final ScheduledReminder r in scheduler.scheduled) {
        expect(r.title, 'MindMate');
        expect(r.body, 'You have a gentle reminder.');
        expect(r.hidden, isTrue);
      }
    });

    test('each reminder leaves the screen when the next is due', () async {
      put(
        settings: settingsWith(mood: '20:00', journal: '22:00'),
      );
      await settle();
      expect(scheduler.scheduled[0].replacedAfter, const Duration(hours: 2));
      expect(scheduler.scheduled.last.replacedAfter, isNull);
      expect(
        scheduler.scheduled.map((ScheduledReminder r) => r.id).toSet(),
        hasLength(scheduler.scheduled.length),
      );
    });

    test('the test reminder shows at once', () async {
      final ReminderController c = put(settings: settingsWith(hide: false));
      await settle();
      await c.sendTest();
      expect(scheduler.shown.single.title, 'This is a test reminder');
      expect(scheduler.shown.single.payload, ReminderTargets.reminders);
    });
  });

  group('Sign out and delete account cancel everything', () {
    test('sign out', () async {
      put(settings: settingsWith(mood: '20:00'));
      await settle();
      scheduler.calls.clear();

      final SettingsViewModel settings = SettingsViewModel(
        AuthRepository(FakeAuthService(), emailCodes: FakeEmailCodeService()),
        cleanupDelay: Duration.zero,
        goToWelcome: () {},
      );
      await settings.logout();
      await settle();

      expect(scheduler.calls, contains('cancelAll'));
      expect(scheduler.scheduled, isEmpty);
    });

    test('delete account', () async {
      put(settings: settingsWith(mood: '20:00'));
      await settle();
      scheduler.calls.clear();

      final DeleteAccountViewModel vm = Get.put<DeleteAccountViewModel>(
        DeleteAccountViewModel(_DeletingAccount(), goToWelcome: () {}),
      );
      vm.password.text = 'secret';
      await vm.deleteAccount();
      await settle();

      expect(scheduler.calls, contains('cancelAll'));
      expect(scheduler.scheduled, isEmpty);
    });
  });

  group('Taps', () {
    test('each kind opens its screen', () {
      expect(ReminderController.routeFor('mood'), AppRoutes.moodLog);
      expect(ReminderController.routeFor('journal'), AppRoutes.journalNew);
      expect(ReminderController.routeFor('practice'), AppRoutes.meditation);
      expect(ReminderController.routeFor('checkin:phq4'), '/assessments/phq4');
      expect(ReminderController.routeFor('today'), AppRoutes.today);
      expect(ReminderController.routeFor('hub'), AppRoutes.assessments);
      expect(
        ReminderController.routeFor('reminders'),
        AppRoutes.settingsReminders,
      );
    });

    test('opens at once when the app is ready', () async {
      final ReminderController c = put();
      await settle();
      c.handleTap('mood');
      expect(routes, <String>[AppRoutes.moodLog]);
    });

    test('waits for Home while the app is starting', () async {
      final ReminderController c = put();
      await settle();
      canNavigate = false;
      c.handleTap('checkin:who5');
      expect(routes, isEmpty);

      repo.pageShown = true;
      await c.homeOpened();
      expect(routes, <String>['/assessments/who5']);
    });

    test('a reminder that started the app opens on Home', () async {
      scheduler = FakeScheduler();
      final ReminderController c = put();
      scheduler.launch = 'journal';
      await settle();
      // The launch reminder was read during start-up of this controller's
      // own scheduler; replay it as the plugin would.
      c.handleTap(scheduler.launch);
      expect(routes.last, AppRoutes.journalNew);
    });
  });

  group('The "Gentle reminders" page', () {
    test('opens once over Home for existing users', () async {
      final ReminderController c = put();
      await settle();
      await c.homeOpened();
      expect(routes, <String>[
        '${AppRoutes.remindersPermission} (${ReminderController.fromHome})',
      ]);

      await c.markPermissionPageShown();
      await c.homeOpened();
      expect(routes, hasLength(1));
    });

    test('permission: enabled, not asked yet, blocked', () async {
      final ReminderController c = put();
      await settle();
      expect(c.permission.value, ReminderPermission.enabled);

      scheduler.enabled = false;
      await c.refreshPermission();
      expect(c.permission.value, ReminderPermission.notAsked);

      scheduler.grant = false;
      expect(await c.requestPermission(), isFalse);
      expect(c.permission.value, ReminderPermission.blocked);
      expect(repo.asked, isTrue);
    });
  });

  group('Today', () {
    test('ready now, later today and done, from the same data', () {
      final TodaySections s = TodayBuilder.build(
        inputs: ReminderInputs(
          settings: settingsWith(
            mood: '20:00',
            journal: '21:30',
            practice: '07:30',
          ).reminders,
          now: DateTime(2026, 10, 29, 20),
          practiceDoneToday: true,
          programme: fileProgramme(),
          joinedAt: DateTime(2026, 10, 1),
        ),
        programmeRows: const <ScheduleRow>[
          ScheduleRow.mood(done: false),
          ScheduleRow(
            label: '3-day check',
            assessmentIds: <String>['phq4'],
            done: false,
          ),
        ],
        questionCounts: const <String, int>{'phq4': 4},
        practiceDoneLine: 'Leaving work at work · 8 min',
      );

      expect(s.ready.map((TodayItem i) => '${i.title}: ${i.line}'), <String>[
        'Mood check-in: About 10 seconds',
        '3-day check: 4 questions · about 30 seconds',
      ]);
      expect(s.later.single.title, 'Journal prompt');
      expect(s.later.single.time, '21:30');
      expect(s.done.single.line, 'Leaving work at work · 8 min');
      expect(s.nothingWaiting, isFalse);
    });

    test('nothing waiting', () {
      final TodaySections s = TodayBuilder.build(
        inputs: ReminderInputs(
          settings: settingsWith(moodOn: false).reminders,
          now: DateTime(2026, 10, 29, 20),
        ),
      );
      expect(s.nothingWaiting, isTrue);
    });

    test('the bell dot shows only when something is ready now', () async {
      final ReminderController c = put(settings: settingsWith(mood: '07:00'));
      await c.rebuildNow();
      expect(c.hasReadyNow, isTrue, reason: 'mood time has passed');

      final HomeFakes fakes = HomeFakes(auth: FakeAuthService());
      final home = buildHome(fakes: fakes, clock: () => evening);
      expect(home.hasUnreadNotifications, isFalse, reason: 'no reminders');

      repo.moodDoneToday = true;
      await c.rebuildNow();
      expect(c.hasReadyNow, isFalse);
    });
  });

  testWidgets('the Today page shows its sections', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ReminderController c = put(
      settings: settingsWith(mood: '07:00', journal: '21:30'),
    );
    Get.put<TodayViewModel>(TodayViewModel(c, clock: () => evening));
    await tester.pumpWidget(
      GetMaterialApp(
        theme: MindMateThemeData.build(MindMateColors.light),
        home: const TodayView(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Thursday 29 October'), findsOneWidget);
    expect(find.text('READY NOW'), findsOneWidget);
    expect(find.text('Mood check-in'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('LATER TODAY'), findsOneWidget);
    expect(find.text('21:30'), findsOneWidget);
    expect(find.text('Change times in Settings · Reminders'), findsOneWidget);
  });

  group('The Reminders page', () {
    Future<void> pump(WidgetTester tester, ReminderController reminders) async {
      tester.view.physicalSize = const Size(1170, 4200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final SettingsRepository settings = SettingsRepository(
        FakeSettingsService(),
      );
      // Quiet hours 23:00 to 07:00, and a journal reminder at 23:30.
      await settings.load();
      await settings.setReminderOn('journal', true);
      await settings.setReminderTime('journal', '23:30');
      await settings.setQuietHoursOn(true);
      Get.put<SettingsViewModel>(
        SettingsViewModel(
          AuthRepository(FakeAuthService(), emailCodes: FakeEmailCodeService()),
          settings: settings,
          reminders: reminders,
        ),
      );
      await tester.pumpWidget(
        GetMaterialApp(
          theme: MindMateThemeData.build(MindMateColors.light),
          home: const RemindersView(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('the next reminder, the quiet-hours note and the test row', (
      WidgetTester tester,
    ) async {
      final ReminderController c = put(settings: settingsWith(mood: '20:00'));
      await tester.runAsync(c.rebuildNow);
      await pump(tester, c);

      expect(find.text('NEXT REMINDER'), findsOneWidget);
      expect(find.text('Today 20:00 · Mood check-in'), findsOneWidget);
      expect(find.text(QuietHoursNote.text), findsOneWidget);
      expect(find.text('Send a test reminder'), findsOneWidget);

      await tester.tap(find.text('Send a test reminder'));
      await tester.runAsync(settle);
      expect(scheduler.shown, hasLength(1));
    });

    testWidgets('blocked: "Notifications are off" and the rows faded', (
      WidgetTester tester,
    ) async {
      final ReminderController c = put();
      scheduler.enabled = false;
      repo.asked = true;
      await tester.runAsync(c.refreshPermission);
      await pump(tester, c);

      expect(find.text('Notifications are off'), findsOneWidget);
      expect(find.text('NEXT REMINDER'), findsNothing);
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(
                of: find.text('Mood check-in'),
                matching: find.byType(Opacity),
              ),
            )
            .opacity,
        0.5,
      );

      await tester.tap(find.text('Open phone settings'));
      await tester.runAsync(settle);
      expect(scheduler.calls, contains('openSettings'));
    });

    testWidgets('never asked: "Reminders are not turned on yet"', (
      WidgetTester tester,
    ) async {
      final ReminderController c = put();
      scheduler.enabled = false;
      await tester.runAsync(c.refreshPermission);
      await pump(tester, c);

      expect(find.text('Reminders are not turned on yet'), findsOneWidget);
      await tester.tap(find.text('Turn on reminders'));
      await tester.runAsync(settle);
      // The rebuild that follows a yes.
      await tester.pump(const Duration(milliseconds: 1));
      expect(scheduler.calls, contains('request'));
    });
  });
}
