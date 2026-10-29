import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Models/home_dashboard.dart';
import 'package:mindmate/Models/hospital_programme.dart';
import 'package:mindmate/Models/mood_model.dart';
import 'package:mindmate/Models/user_profile.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/home/home_view.dart';
import 'package:mindmate/ui/programme/wellbeing_alert_view.dart';
import 'package:mindmate/ui/programme/wellbeing_programme_controller.dart';
import 'package:mindmate/ui/shared/mindmate_theme.dart';
import 'package:mindmate/viewmodels/home_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/auth_app.dart';
import 'helpers/home_fakes.dart';
import 'helpers/profile_fakes.dart';
import 'helpers/programme_fakes.dart';

/// Day 2 after joining, 20:00.
final DateTime evening = DateTime(2026, 10, 2, 20);

const UserProfile _profile = UserProfile(
  uid: 'uid-1',
  name: 'Ayesha Khan',
  email: 'ayesha@example.com',
  imageUrl: '',
  bio: '',
  age: 30,
  gender: 'Female',
);

void ignoreOverflowErrors() {
  final FlutterExceptionHandler? original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (!details.exceptionAsString().contains('overflowed')) {
      original?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = original);
}

Future<void> go(WidgetTester tester, [int milliseconds = 600]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: milliseconds));
}

/// The real Home, with [repo] as the hospital programme (null: no
/// programme at all).
Future<HomeViewModel> openHome(
  WidgetTester tester, {
  FakeProgrammeRepository? repo,
  HomeFakes? fakes,
}) async {
  tester.view.physicalSize = const Size(1170, 4800);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  ignoreOverflowErrors();

  final HomeViewModel vm = buildHome(
    fakes:
        fakes ??
        HomeFakes(
          auth: FakeAuthService(),
          profiles: FakeProfileService(profile: _profile),
        ),
    clock: () => evening,
    programme: repo == null
        ? null
        : WellbeingProgrammeController(
            repo,
            clock: () => evening,
            canShowAlert: () => false,
          ),
  );

  await tester.pumpWidget(
    GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
      ),
      initialRoute: AppRoutes.home,
      getPages: <GetPage<dynamic>>[
        GetPage<dynamic>(
          name: AppRoutes.home,
          page: () => const HomeView(),
          binding: BindingsBuilder(() => Get.put<HomeViewModel>(vm)),
        ),
        GetPage<dynamic>(
          name: '${AppRoutes.assessments}/:id',
          page: () => Scaffold(
            body: Center(child: Text('CHECK-IN ${Get.parameters['id']}')),
          ),
        ),
        GetPage<dynamic>(
          name: AppRoutes.moodLog,
          page: () => const Scaffold(body: Center(child: Text('MOOD LOG'))),
        ),
      ],
    ),
  );
  await go(tester, 1500);
  return vm;
}

/// In City General since 1 October; the 3-day check and Wellbeing were done
/// on day 1, so day 2 has Mood and "Low mood and worry".
FakeProgrammeRepository dayTwo() =>
    FakeProgrammeRepository(
        membership: cityGeneral(joinedAt: DateTime(2026, 10, 1, 9)),
      )
      ..lastDone = <String, DateTime>{
        'phq4': DateTime(2026, 10, 1, 10),
        'who5': DateTime(2026, 10, 1, 9, 30),
      };

void main() {
  setUp(() {
    Get.testMode = true;
    HomeIntro.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    Get.reset();
    HomeIntro.reset();
  });

  group('Home for hospital staff', () {
    testWidgets('the top card shows "{done} of {total}" with a list under it', (
      WidgetTester tester,
    ) async {
      final HomeFakes fakes = HomeFakes(
        auth: FakeAuthService(),
        profiles: FakeProfileService(profile: _profile),
      );
      fakes.moods.history = <MoodModel>[
        moodAt(DateTime(2026, 10, 2, 19, 40), 'Calm'),
      ];
      await openHome(tester, repo: dayTwo(), fakes: fakes);

      expect(find.text("TODAY'S CHECK-INS"), findsOneWidget);
      expect(find.text('1 of 2 done. One check left.'), findsOneWidget);
      expect(find.text('Log mood'), findsNothing);
      expect(find.text('Mood'), findsWidgets);
      expect(find.text('Logged at 19:40 · Calm'), findsOneWidget);
      expect(find.text('Low mood and worry'), findsOneWidget);
      expect(find.text('16 questions · due today'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      // The rest of Home is unchanged.
      expect(find.text('Explore'), findsOneWidget);
    });

    testWidgets('Start opens that check-in directly', (
      WidgetTester tester,
    ) async {
      await openHome(tester, repo: dayTwo());

      // Mood is not logged yet: two Start buttons; the second is the pair.
      expect(find.text('0 of 2 done. 2 checks left.'), findsOneWidget);
      await tester.tap(find.text('Start').last);
      await go(tester);

      expect(find.text('CHECK-IN phq9'), findsOneWidget);
    });

    testWidgets("the mood row's Start opens the mood flow", (
      WidgetTester tester,
    ) async {
      await openHome(tester, repo: dayTwo());

      await tester.tap(find.text('Start').first);
      await go(tester);

      expect(find.text('MOOD LOG'), findsOneWidget);
    });

    testWidgets('the bubble counts what is left', (WidgetTester tester) async {
      final HomeViewModel vm = await openHome(tester, repo: dayTwo());
      await tester.pump(const Duration(seconds: 4));
      await go(tester);

      expect(vm.bubbleText.value, '2 check-ins left today');
    });
  });

  group('Users not in a hospital', () {
    testWidgets('keep the original mood card', (WidgetTester tester) async {
      await openHome(tester, repo: FakeProgrammeRepository());

      expect(find.text("TODAY'S CHECK-INS"), findsNothing);
      expect(find.text('Log mood'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
    });

    testWidgets('and so does Home without the programme', (
      WidgetTester tester,
    ) async {
      await openHome(tester);

      expect(find.text('Log mood'), findsOneWidget);
      expect(find.text("TODAY'S CHECK-INS"), findsNothing);
    });
  });

  group('Someone will reach out', () {
    Future<void> openAlert(WidgetTester tester, WellbeingAlert alert) async {
      tester.view.physicalSize = const Size(1170, 3200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      ignoreOverflowErrors();
      await tester.pumpWidget(
        GetMaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: WellbeingAlertView(alert: alert),
        ),
      );
      await go(tester);
    }

    String allText(WidgetTester tester) => tester
        .widgetList<RichText>(find.byType(RichText))
        .map((RichText t) => t.text.toPlainText())
        .join('\n');

    testWidgets('support: the two-week wording, never any scores', (
      WidgetTester tester,
    ) async {
      await openAlert(
        tester,
        WellbeingAlert(
          id: 'a1',
          sentAt: DateTime(2026, 10, 20),
          urgent: false,
          officerName: 'Dr. Sana Malik',
        ),
      );

      expect(find.text(WellbeingAlertView.title), findsOneWidget);
      final String text = allText(tester);
      expect(
        text,
        contains(
          'Your check-ins over the last two weeks suggest things have been '
          'hard. We have asked Dr. Sana Malik, your wellbeing officer, to get '
          'in touch and support you.',
        ),
      );
      expect(
        text,
        contains('They were not sent your moods, scores, answers or journal.'),
      );
      expect(text, contains('This is for support, not a performance review.'));
      expect(find.text('Need to talk sooner?'), findsOneWidget);
      expect(find.text('Okay'), findsOneWidget);
      expect(find.text('Try a calm practice'), findsOneWidget);
    });

    testWidgets('urgent: "contact you today"', (WidgetTester tester) async {
      await openAlert(
        tester,
        WellbeingAlert(
          id: 'u1',
          sentAt: DateTime(2026, 10, 20),
          urgent: true,
          officerName: 'Dr. Sana Malik',
        ),
      );

      expect(
        allText(tester),
        contains(
          'Your answers suggest you may need support today. We have asked '
          'Dr. Sana Malik to contact you today.',
        ),
      );
    });
  });
}
