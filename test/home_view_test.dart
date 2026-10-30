import 'dart:async';
import 'dart:ui' show AccessibilityFeatures, Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Data/repositories/auth_repository.dart';
import 'package:mindmate/Data/repositories/home_repository.dart';
import 'package:mindmate/Data/repositories/meditation_repository.dart';
import 'package:mindmate/Data/repositories/mood_repository.dart';
import 'package:mindmate/Data/repositories/profile_repository.dart';
import 'package:mindmate/Models/home_dashboard.dart';
import 'package:mindmate/Models/mood_model.dart';
import 'package:mindmate/Models/user_profile.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/home/home_view.dart';
import 'package:mindmate/ui/home/widgets/home_mood_card.dart';
import 'package:mindmate/ui/home/widgets/home_skeleton.dart';
import 'package:mindmate/ui/main_navigation/main_navigation_binding.dart';
import 'package:mindmate/ui/shared/custom_bottom_nav_bar.dart';
import 'package:mindmate/ui/shared/mindmate_theme.dart';
import 'package:mindmate/viewmodels/home_viewmodel.dart';
import 'package:mindmate/viewmodels/main_navigation_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/auth_app.dart';
import 'helpers/home_fakes.dart';
import 'helpers/meditation_fakes.dart';
import 'helpers/profile_fakes.dart';

/// The text in these tests is wider than the real font, which can overflow a
/// row. Overflow is not what these tests are about, so it is left out.
void ignoreOverflowErrors() {
  final FlutterExceptionHandler? original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (!details.exceptionAsString().contains('overflowed')) {
      original?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = original);
}

final DateTime evening = DateTime(2026, 10, 8, 20);

Future<void> go(WidgetTester tester, [int milliseconds = 600]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: milliseconds));
}

UserProfile _profile({String status = ''}) => UserProfile(
  uid: 'uid-1',
  name: 'Ayesha Khan',
  email: 'ayesha@example.com',
  imageUrl: '',
  bio: '',
  age: 30,
  gender: 'Female',
  checkInStatus: status,
);

class HomeSetup {
  HomeSetup({HomeFakes? fakes, UserProfile? profile})
    : fakes =
          fakes ??
          HomeFakes(
            auth: FakeAuthService(),
            profiles: FakeProfileService(profile: profile ?? _profile()),
          );

  final HomeFakes fakes;
  late HomeViewModel vm;
}

/// The real dashboard, wired to fakes, with a placeholder for every other
/// screen.
Future<HomeSetup> open(
  WidgetTester tester, {
  HomeSetup? setup,
  DateTime? now,
  bool Function(String route)? routeExists,
}) async {
  tester.view.physicalSize = const Size(1170, 4800);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  ignoreOverflowErrors();

  final HomeSetup s = setup ?? HomeSetup();
  s.vm = buildHome(
    fakes: s.fakes,
    clock: () => now ?? evening,
    routeExists: routeExists,
  );

  GetPage<dynamic> placeholder(String route) => GetPage<dynamic>(
    name: route,
    page: () => Scaffold(body: Center(child: Text('PAGE $route'))),
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
          binding: BindingsBuilder(() {
            Get.put<HomeViewModel>(s.vm);
          }),
        ),
        for (final String route in <String>[
          AppRoutes.moodLog,
          AppRoutes.moodTracking,
          AppRoutes.journal,
          AppRoutes.meditation,
          AppRoutes.meditationDetails,
          AppRoutes.aiChat,
          AppRoutes.assessments,
          AppRoutes.games,
          AppRoutes.support,
          AppRoutes.settingsProfile,
          AppRoutes.checkInIntro,
          AppRoutes.reports,
          AppRoutes.emotionCheck,
          AppRoutes.today,
        ])
          placeholder(route),
      ],
    ),
  );
  await go(tester, 1500);
  return s;
}

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

  group('The dashboard', () {
    testWidgets(
      'shows the header, the mood card, the numbers and the sections',
      (WidgetTester tester) async {
        final HomeFakes fakes = HomeFakes(
          auth: FakeAuthService(),
          profiles: FakeProfileService(profile: _profile()),
        );
        fakes.moods.history = <MoodModel>[
          moodAt(DateTime(2026, 10, 8, 9), 'Calm'),
          moodAt(DateTime(2026, 10, 7, 9), 'Happy'),
        ];
        await open(tester, setup: HomeSetup(fakes: fakes));

        expect(find.text('Good evening,'), findsOneWidget);
        expect(find.text('AK'), findsOneWidget);
        expect(find.text('Today you felt calm.'), findsOneWidget);
        expect(find.text('Log again'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('day streak'), findsOneWidget);
        expect(find.text('calm minutes'), findsOneWidget);
        expect(find.text('Good'), findsOneWidget);
        expect(find.text('week so far'), findsOneWidget);
        expect(find.text('SUGGESTED FOR TONIGHT'), findsOneWidget);
        expect(find.text('Explore'), findsOneWidget);
        for (final String title in <String>[
          'Mood',
          'Journal',
          'Meditation',
          'AI chat',
          'Check-ins',
          'Reports',
          'Take a break',
          'Emotion check',
        ]) {
          expect(find.text(title), findsOneWidget, reason: title);
        }
        expect(find.text('Logged today'), findsOneWidget);
        expect(find.text('12 guided practices'), findsOneWidget);
        expect(find.text('Need to talk to someone now?'), findsOneWidget);
        expect(find.text('Support and helplines'), findsOneWidget);
      },
    );

    testWidgets('the old x/10 mood number is gone', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(find.textContaining('/10'), findsNothing);
      expect(find.textContaining('--'), findsNothing);
    });

    testWidgets('with nothing logged the card asks, and the week has no data', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(find.text('How are you feeling today?'), findsOneWidget);
      expect(find.text('Log mood'), findsOneWidget);
      expect(find.text('No data'), findsOneWidget);
      expect(find.text('Not logged yet'), findsOneWidget);
    });

    testWidgets('Log mood opens the mood flow from the very first frame', (
      WidgetTester tester,
    ) async {
      final HomeSetup setup = HomeSetup();
      setup.fakes.moods.gate = Completer<void>();
      await open(tester, setup: setup);

      // The moods have not loaded, yet the button works.
      expect(find.byType(SkeletonBar), findsWidgets);
      await tester.tap(find.text('Log mood'));
      await go(tester);

      expect(Get.currentRoute, AppRoutes.moodLog);
      setup.fakes.moods.gate!.complete();
      await tester.pump();
    });

    testWidgets('each section shows a skeleton while it loads', (
      WidgetTester tester,
    ) async {
      final HomeSetup setup = HomeSetup();
      setup.fakes.moods.gate = Completer<void>();
      await open(tester, setup: setup);

      expect(find.byType(SkeletonBar), findsWidgets);
      // The other sections are already there.
      expect(find.text('12 guided practices'), findsOneWidget);
      expect(find.text('SUGGESTED FOR TONIGHT'), findsOneWidget);

      setup.fakes.moods.gate!.complete();
      await go(tester);
      expect(find.text('No data'), findsOneWidget);
    });

    testWidgets('a section that fails says so and can be retried', (
      WidgetTester tester,
    ) async {
      final HomeSetup setup = HomeSetup();
      setup.fakes.moods.failLoading = true;
      await open(tester, setup: setup);

      expect(find.text('Could not load. Tap to retry'), findsNWidgets(2));
      // Everything else is still on screen.
      expect(find.text('Explore'), findsOneWidget);
      expect(find.text('12 guided practices'), findsOneWidget);
      expect(find.text('Log mood'), findsOneWidget);

      setup.fakes.moods.failLoading = false;
      await tester.tap(find.text('Could not load. Tap to retry').first);
      await go(tester);

      expect(find.text('Could not load. Tap to retry'), findsNothing);
      expect(find.text('day streak'), findsOneWidget);
    });

    testWidgets('a failed meditation section shows a retry card', (
      WidgetTester tester,
    ) async {
      final HomeSetup setup = HomeSetup();
      setup.fakes.logs.failLoading = true;
      await open(tester, setup: setup);

      expect(find.text('Could not load. Tap to retry'), findsNWidgets(2));
      expect(find.text('SUGGESTED FOR TONIGHT'), findsNothing);

      setup.fakes.logs.failLoading = false;
      await tester.tap(find.text('Could not load. Tap to retry').first);
      await go(tester);
      expect(find.text('SUGGESTED FOR TONIGHT'), findsOneWidget);
    });

    testWidgets('the suggestion card opens the practice', (
      WidgetTester tester,
    ) async {
      await open(tester);

      await tester.tap(find.text('SUGGESTED FOR TONIGHT'));
      await go(tester);

      expect(Get.currentRoute, AppRoutes.meditationDetails);
    });

    testWidgets('the suggestion card is hidden when meditation is not built', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        routeExists: (String route) => route != AppRoutes.meditation,
      );

      expect(find.text('SUGGESTED FOR TONIGHT'), findsNothing);
      expect(find.text('Coming soon'), findsWidgets);
    });

    testWidgets('the heading is "for you" before 18:00', (
      WidgetTester tester,
    ) async {
      await open(tester, now: DateTime(2026, 10, 8, 14));

      expect(find.text('SUGGESTED FOR YOU'), findsOneWidget);
      expect(find.text('Good afternoon,'), findsOneWidget);
    });

    testWidgets('"Finish your check-in" shows only while it is pending', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        setup: HomeSetup(profile: _profile(status: 'pending')),
      );

      expect(find.text('Finish your check-in'), findsOneWidget);

      await tester.tap(find.byTooltip('Dismiss'));
      await go(tester);
      expect(find.text('Finish your check-in'), findsNothing);
    });

    testWidgets('no check-in card for people who never had one', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(find.text('Finish your check-in'), findsNothing);
    });
  });

  group('Explore', () {
    testWidgets('a live tile opens its screen', (WidgetTester tester) async {
      await open(tester);

      await tester.tap(find.text('Journal'));
      await go(tester);

      expect(Get.currentRoute, AppRoutes.journal);
    });

    testWidgets('each live tile goes where the table says', (
      WidgetTester tester,
    ) async {
      const Map<String, String> expected = <String, String>{
        'Mood': AppRoutes.moodTracking,
        'Meditation': AppRoutes.meditation,
        'AI chat': AppRoutes.aiChat,
        'Check-ins': AppRoutes.assessments,
        'Take a break': AppRoutes.games,
      };
      await open(tester);

      for (final MapEntry<String, String> entry in expected.entries) {
        await tester.tap(find.text(entry.key));
        await go(tester);
        expect(Get.currentRoute, entry.value, reason: entry.key);
        Get.back<void>();
        await go(tester);
      }
    });

    testWidgets(
      'a tile with no module is faded, says Coming soon, does nothing',
      (WidgetTester tester) async {
        await open(
          tester,
          routeExists: (String route) =>
              route != AppRoutes.reports && route != AppRoutes.emotionCheck,
        );

        expect(find.text('Coming soon'), findsNWidgets(2));
        expect(find.text('Your week and month'), findsNothing);
        expect(find.text('With your camera'), findsNothing);

        await tester.tap(find.text('Reports'));
        await go(tester);
        await tester.tap(find.text('Emotion check'));
        await go(tester);

        expect(Get.currentRoute, AppRoutes.home);
        // And no message about it.
        expect(find.textContaining('module will be connected'), findsNothing);
        expect(find.byType(SnackBar), findsNothing);
      },
    );

    testWidgets('a Coming soon tile is read out as not available', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await open(
        tester,
        routeExists: (String route) => route != AppRoutes.reports,
      );

      final SemanticsNode soon = tester.getSemantics(
        find.bySemanticsLabel('Reports, Coming soon'),
      );
      expect(soon.flagsCollection.isEnabled, Tristate.isFalse);
      final SemanticsNode live = tester.getSemantics(
        find.bySemanticsLabel('Journal, Write it out'),
      );
      expect(live.flagsCollection.isEnabled, Tristate.isTrue);
      semantics.dispose();
    });

    testWidgets('the support card opens the support page', (
      WidgetTester tester,
    ) async {
      await open(tester);

      await tester.tap(find.text('Need to talk to someone now?'));
      await go(tester);

      expect(Get.currentRoute, AppRoutes.support);
    });

    testWidgets('the photo opens the profile', (WidgetTester tester) async {
      await open(tester);

      await tester.tap(find.text('AK'));
      await go(tester);

      expect(Get.currentRoute, AppRoutes.settingsProfile);
    });

    testWidgets('the bell has no dot until something is unread', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final HomeSetup setup = await open(tester);
      expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
      expect(find.bySemanticsLabel('Notifications, new'), findsNothing);

      setup.vm.unreadNotifications.value = 1;
      await tester.pump();
      expect(find.bySemanticsLabel('Notifications, new'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the bell opens Today', (WidgetTester tester) async {
      await open(tester);

      await tester.tap(find.byIcon(Icons.notifications_none_rounded));
      await go(tester);

      expect(find.text('PAGE ${AppRoutes.today}'), findsOneWidget);
    });
  });

  group('Coming back', () {
    testWidgets('the mood card is up to date when you return', (
      WidgetTester tester,
    ) async {
      final HomeSetup setup = await open(tester);
      expect(find.text('How are you feeling today?'), findsOneWidget);

      await tester.tap(find.text('Log mood'));
      await go(tester);
      expect(Get.currentRoute, AppRoutes.moodLog);

      // A mood is saved on the other screen.
      setup.fakes.moods.history = <MoodModel>[
        moodAt(DateTime(2026, 10, 8, 19), 'Happy'),
      ];
      Get.back<void>();
      await go(tester, 1000);

      expect(find.text('Today you felt happy.'), findsOneWidget);
      expect(find.text('Log again'), findsOneWidget);
      expect(find.text('Logged today'), findsOneWidget);
    });
  });

  group('The entrance', () {
    testWidgets('the name is there when reduce-motion is on', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const _ReducedMotion();
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final SemanticsHandle semantics = tester.ensureSemantics();
      final HomeSetup setup = HomeSetup();
      tester.view.physicalSize = const Size(1170, 4800);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      ignoreOverflowErrors();
      setup.vm = buildHome(fakes: setup.fakes, clock: () => evening);
      Get.put<HomeViewModel>(setup.vm);

      await tester.pumpWidget(const MaterialApp(home: HomeView()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));

      expect(setup.vm.animateIntro, isFalse);
      expect(find.bySemanticsLabel('Ayesha'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      semantics.dispose();
    });

    testWidgets('the entrance plays once, and is not repeated', (
      WidgetTester tester,
    ) async {
      final HomeSetup setup = await open(tester);
      expect(setup.vm.animateIntro, isTrue);

      // The Home page asks again in the same launch (the Home tab is shown
      // again): nothing plays a second time.
      expect(setup.vm.startIntro(reduceMotion: false), isFalse);
      expect(setup.vm.animateIntro, isFalse);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('The mood card by time of day', () {
    Future<void> pumpCard(
      WidgetTester tester,
      DayPart part, {
      String? bubble,
      bool intro = false,
    }) async {
      tester.view.physicalSize = const Size(1170, 1200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      ignoreOverflowErrors();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: HomeMoodCard(
                dayPart: part,
                title: 'How are you feeling today?',
                buttonLabel: 'Log mood',
                onLog: () {},
                isLoadingTitle: false,
                bubble: bubble,
                playIntro: intro,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    for (final DayPart part in DayPart.values) {
      testWidgets('${part.name}: draws, animates and settles', (
        WidgetTester tester,
      ) async {
        await pumpCard(tester, part, intro: true);

        expect(find.text('How are you feeling today?'), findsOneWidget);
        expect(find.text('Log mood'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 6));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the bubble shows its line', (WidgetTester tester) async {
      await pumpCard(tester, DayPart.evening, bubble: '5 days in a row');
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('5 days in a row'), findsOneWidget);
    });

    testWidgets('no bubble when there is no line', (WidgetTester tester) async {
      await pumpCard(tester, DayPart.afternoon);

      expect(find.text('Good to see you'), findsNothing);
    });

    testWidgets('Log mood can be tapped straight away', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      tester.view.physicalSize = const Size(1170, 1200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      ignoreOverflowErrors();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeMoodCard(
              dayPart: DayPart.morning,
              title: 'x',
              buttonLabel: 'Log mood',
              onLog: () => taps += 1,
              isLoadingTitle: true,
              bubble: null,
              playIntro: true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Log mood'));
      await tester.pump(const Duration(seconds: 3));

      expect(taps, 1);
    });

    testWidgets('with reduce-motion nothing keeps moving', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const _ReducedMotion();
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpCard(tester, DayPart.evening, intro: true);

      // With nothing animating, the clock can be run on and no frames are
      // scheduled.
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('The bar at the bottom', () {
    testWidgets('has the five tabs and marks the open one', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final List<int> taps = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CustomBottomNavBar(
              selectedIndex: 2,
              onTabChanged: taps.add,
            ),
          ),
        ),
      );

      for (final String label in <String>[
        'Home',
        'Mood',
        'AI Chat',
        'Journal',
        'Settings',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      await tester.tap(find.text('Settings'));
      await tester.tap(find.text('Home'));
      expect(taps, <int>[4, 0]);

      final SemanticsNode chat = tester.getSemantics(
        find.bySemanticsLabel('AI Chat'),
      );
      expect(chat.flagsCollection.isSelected, Tristate.isTrue);
      final SemanticsNode home = tester.getSemantics(
        find.bySemanticsLabel('Home'),
      );
      expect(home.flagsCollection.isSelected, isNot(Tristate.isTrue));
      semantics.dispose();
    });

    test('opening Home from another tab brings it up to date', () {
      int refreshes = 0;
      final MainNavigationViewModel nav = MainNavigationViewModel(
        onHomeSelected: () => refreshes += 1,
      );

      nav.selectTab(0);
      expect(refreshes, 0);
      nav.selectTab(3);
      nav.selectTab(0);
      expect(refreshes, 1);
      nav.selectTab(0);
      expect(refreshes, 1);
    });
  });

  group('The main navigation binding', () {
    test('registers the tabs\' ViewModels', () {
      final HomeFakes fakes = HomeFakes(auth: FakeAuthService());
      Get.put<AuthRepository>(AuthRepository(fakes.auth));
      Get.put<MoodRepository>(MoodRepository(fakes.moods));
      Get.put<ProfileRepository>(ProfileRepository(fakes.profiles));
      Get.put<MeditationRepository>(buildRepository(fakes.logs));
      Get.put<HomeRepository>(HomeRepository());

      MainNavigationBinding().dependencies();

      expect(Get.isRegistered<MainNavigationViewModel>(), isTrue);
      expect(Get.isRegistered<HomeViewModel>(), isTrue);
    });
  });
}

class _ReducedMotion implements AccessibilityFeatures {
  const _ReducedMotion();

  @override
  bool get accessibleNavigation => false;

  @override
  bool get boldText => false;

  @override
  bool get disableAnimations => true;

  @override
  bool get highContrast => false;

  @override
  bool get invertColors => false;

  @override
  bool get onOffSwitchLabels => false;

  @override
  bool get reduceMotion => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}
