import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Models/home_dashboard.dart';
import 'package:mindmate/Models/meditation_log_entry.dart';
import 'package:mindmate/Models/mood_model.dart';
import 'package:mindmate/Models/user_profile.dart';
import 'package:mindmate/viewmodels/home_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/auth_app.dart';
import 'helpers/home_fakes.dart';
import 'helpers/meditation_fakes.dart';
import 'helpers/profile_fakes.dart';

/// Thursday 8 October 2026, 20:00: an evening.
final DateTime evening = DateTime(2026, 10, 8, 20);
final DateTime afternoon = DateTime(2026, 10, 8, 14);

DateTime _day(DateTime now, int daysAgo, [int hour = 12]) =>
    DateTime(now.year, now.month, now.day - daysAgo, hour);

UserProfile _profile({String name = 'Ayesha Khan', String reminder = ''}) {
  return UserProfile(
    uid: 'uid-1',
    name: name,
    email: 'ayesha@example.com',
    imageUrl: '',
    bio: '',
    age: 30,
    gender: 'Female',
    reminderPreference: reminder,
    checkInStatus: 'pending',
  );
}

HomeFakes _fakes({UserProfile? profile}) {
  return HomeFakes(
    auth: FakeAuthService(),
    profiles: FakeProfileService(profile: profile ?? _profile()),
  );
}

Future<HomeViewModel> _loaded(
  HomeFakes fakes, {
  DateTime? now,
  bool Function(String route)? routeExists,
}) async {
  final HomeViewModel vm = Get.put<HomeViewModel>(
    buildHome(
      fakes: fakes,
      clock: () => now ?? evening,
      routeExists: routeExists,
    ),
  );
  await vm.loadAll();
  return vm;
}

/// Lets loads, timers and the saved-preference reads finish.
Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    HomeIntro.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    Get.reset();
    HomeIntro.reset();
  });

  group('Loading', () {
    test(
      'every section loads, with the numbers from the other modules',
      () async {
        final HomeFakes fakes = _fakes();
        fakes.moods.history = <MoodModel>[
          moodAt(_day(evening, 0), 'Calm'),
          moodAt(_day(evening, 1), 'Happy'),
          moodAt(_day(evening, 2), 'Okay'),
        ];
        fakes.logs.history = <MeditationLogEntry>[
          logEntry(_day(evening, 0), seconds: 600),
          logEntry(_day(evening, 2), seconds: 180),
          logEntry(_day(evening, 8), seconds: 6000),
        ];

        final HomeViewModel vm = await _loaded(fakes);

        expect(vm.profileStatus.value, SectionStatus.ready);
        expect(vm.moodStatus.value, SectionStatus.ready);
        expect(vm.meditationStatus.value, SectionStatus.ready);
        expect(vm.moodStreak, 3);
        expect(vm.weekWord, WeekWord.good);
        expect(vm.calmMinutes, 13);
        expect(vm.guidedPracticeCount.value, 12);
        expect(vm.suggestion.value, isNotNull);
        expect(vm.suggestionHeading, 'Suggested for tonight');
        expect(vm.moodCard.title, 'Today you felt calm.');
        expect(vm.moodCard.buttonLabel, 'Log again');
      },
    );

    test('before loading, the sections are loading', () {
      final HomeViewModel vm = buildHome(fakes: _fakes());

      expect(vm.profileStatus.value, SectionStatus.loading);
      expect(vm.moodStatus.value, SectionStatus.loading);
      expect(vm.meditationStatus.value, SectionStatus.loading);
      expect(vm.moodLoggedToday, isNull);
    });

    test('a failed mood load does not blank the other sections', () async {
      final HomeFakes fakes = _fakes();
      fakes.moods.failLoading = true;

      final HomeViewModel vm = await _loaded(fakes);

      expect(vm.moodStatus.value, SectionStatus.failed);
      expect(vm.meditationStatus.value, SectionStatus.ready);
      expect(vm.profileStatus.value, SectionStatus.ready);
      expect(vm.guidedPracticeCount.value, 12);
      expect(vm.suggestion.value, isNotNull);
      expect(vm.firstName, 'Ayesha');
    });

    test(
      'a failed meditation load does not blank the other sections',
      () async {
        final HomeFakes fakes = _fakes();
        fakes.moods.history = <MoodModel>[moodAt(_day(evening, 0), 'Happy')];
        fakes.logs.failLoading = true;

        final HomeViewModel vm = await _loaded(fakes);

        expect(vm.meditationStatus.value, SectionStatus.failed);
        expect(vm.moodStatus.value, SectionStatus.ready);
        expect(vm.moodCard.title, 'Today you felt happy.');
      },
    );

    test('a failed profile load does not blank the other sections', () async {
      final HomeFakes fakes = HomeFakes(
        auth: FakeAuthService(),
        profiles: _ThrowingProfileService(),
      );
      fakes.moods.history = <MoodModel>[moodAt(_day(evening, 0), 'Happy')];

      final HomeViewModel vm = await _loaded(fakes);

      expect(vm.profileStatus.value, SectionStatus.failed);
      expect(vm.moodStatus.value, SectionStatus.ready);
      expect(vm.meditationStatus.value, SectionStatus.ready);
      expect(vm.firstName, 'there');
    });

    test('retrying a failed section loads it', () async {
      final HomeFakes fakes = _fakes();
      fakes.moods.failLoading = true;
      final HomeViewModel vm = await _loaded(fakes);
      expect(vm.moodStatus.value, SectionStatus.failed);

      fakes.moods.failLoading = false;
      fakes.moods.history = <MoodModel>[moodAt(_day(evening, 0), 'Calm')];
      final Future<void> retrying = vm.retryMood();
      expect(vm.moodStatus.value, SectionStatus.loading);
      await retrying;

      expect(vm.moodStatus.value, SectionStatus.ready);
      expect(vm.moodStreak, 1);
    });

    test(
      'with no mood loaded the suggestion still comes from the time of day',
      () async {
        final HomeFakes fakes = _fakes();
        fakes.moods.failLoading = true;

        final HomeViewModel vm = await _loaded(
          fakes,
          now: DateTime(2026, 10, 8, 22),
        );

        expect(vm.suggestion.value?.session.id, 'sleep_wind_down');
      },
    );

    test(
      'a hard mood changes the suggestion, as in the meditation module',
      () async {
        final HomeFakes fakes = _fakes();
        fakes.moods.history = <MoodModel>[moodAt(_day(evening, 0), 'Anxious')];

        final HomeViewModel vm = await _loaded(fakes);

        expect(vm.suggestion.value?.session.id, 'senses_54321');
        expect(vm.suggestion.value?.reason, 'You logged Anxious today');
      },
    );
  });

  group('Refreshing', () {
    test(
      'coming back brings the numbers up to date with no skeleton',
      () async {
        final HomeFakes fakes = _fakes();
        final HomeViewModel vm = await _loaded(fakes);
        expect(vm.moodCard.loggedToday, isFalse);

        final List<SectionStatus> seen = <SectionStatus>[];
        final Worker worker = ever<SectionStatus>(vm.moodStatus, seen.add);
        fakes.moods.history = <MoodModel>[moodAt(_day(evening, 0), 'Tired')];
        await vm.refreshQuiet();
        worker.dispose();

        expect(vm.moodCard.title, 'Today you felt tired.');
        expect(seen, everyElement(SectionStatus.ready));
      },
    );

    test('a failed refresh keeps what is on screen', () async {
      final HomeFakes fakes = _fakes();
      fakes.moods.history = <MoodModel>[moodAt(_day(evening, 0), 'Happy')];
      final HomeViewModel vm = await _loaded(fakes);

      fakes.moods.failLoading = true;
      await vm.refreshQuiet();

      expect(vm.moodStatus.value, SectionStatus.ready);
      expect(vm.moodCard.title, 'Today you felt happy.');
    });

    test('pull to refresh reloads every section', () async {
      final HomeFakes fakes = _fakes();
      final HomeViewModel vm = await _loaded(fakes);
      final int before = fakes.moods.loads;

      await vm.refreshAll();

      expect(fakes.moods.loads, greaterThan(before));
      expect(vm.profileStatus.value, SectionStatus.ready);
    });
  });

  group('The header', () {
    test('first name and initials come from the profile', () async {
      final HomeViewModel vm = await _loaded(_fakes());

      expect(vm.firstName, 'Ayesha');
      expect(vm.initials, 'AK');
    });

    test('with no name, it says there and shows a U', () async {
      final HomeViewModel vm = await _loaded(
        _fakes(profile: _profile(name: '')),
      );

      expect(vm.firstName, 'there');
      expect(vm.initials, 'U');
    });

    test('the greeting follows the clock', () async {
      final HomeViewModel vm = await _loaded(
        _fakes(),
        now: DateTime(2026, 10, 8, 9),
      );
      expect(vm.greetingLine, 'Good morning,');

      final HomeViewModel later = buildHome(
        fakes: _fakes(),
        clock: () => DateTime(2026, 10, 8, 13),
      );
      expect(later.greetingLine, 'Good afternoon,');
    });

    test('no notification source means no dot', () async {
      final HomeViewModel vm = await _loaded(_fakes());

      expect(vm.hasUnreadNotifications, isFalse);
      vm.unreadNotifications.value = 2;
      expect(vm.hasUnreadNotifications, isTrue);
    });
  });

  group('The mood card', () {
    test('after-shift reminder asks about the shift after 14:00', () async {
      final HomeFakes fakes = _fakes(
        profile: _profile(reminder: 'after_shift'),
      );

      final HomeViewModel late = await _loaded(fakes, now: evening);
      expect(late.moodCard.title, 'How are you feeling after your shift?');

      Get.reset();
      final HomeViewModel early = await _loaded(
        fakes,
        now: DateTime(2026, 10, 8, 10),
      );
      expect(early.moodCard.title, 'How are you feeling today?');
    });

    test('only today\'s moods count as "today"', () async {
      final HomeFakes fakes = _fakes();
      fakes.moods.history = <MoodModel>[moodAt(_day(evening, 1), 'Happy')];

      final HomeViewModel vm = await _loaded(fakes);

      expect(vm.moodLoggedToday, isFalse);
      expect(vm.moodCard.title, 'How are you feeling today?');
      // Yesterday only: the streak is still alive.
      expect(vm.moodStreak, 1);
    });

    test('the newest mood of today is the one named', () async {
      final HomeFakes fakes = _fakes();
      fakes.moods.history = <MoodModel>[
        moodAt(DateTime(2026, 10, 8, 18), 'Stressed'),
        moodAt(DateTime(2026, 10, 8, 9), 'Happy'),
      ];

      final HomeViewModel vm = await _loaded(fakes);

      expect(vm.moodCard.title, 'Today you felt stressed.');
    });
  });

  group('Explore', () {
    test('the mood line waits for the moods, then follows them', () async {
      final HomeFakes fakes = _fakes();
      final HomeViewModel vm = buildHome(fakes: fakes, clock: () => evening);
      ExploreTile mood() =>
          vm.exploreTiles.firstWhere((ExploreTile t) => t.id == ExploreId.mood);
      expect(mood().line, 'Track how you feel');

      Get.put<HomeViewModel>(vm);
      await vm.loadAll();
      expect(mood().line, 'Not logged yet');

      fakes.moods.history = <MoodModel>[moodAt(_day(evening, 0), 'Happy')];
      await vm.refreshQuiet();
      expect(mood().line, 'Logged today');
    });

    test('the meditation line counts the guided practices', () async {
      final HomeViewModel vm = await _loaded(_fakes());

      final ExploreTile tile = vm.exploreTiles.firstWhere(
        (ExploreTile t) => t.id == ExploreId.meditation,
      );
      expect(tile.line, '12 guided practices');
    });

    test('modules without a screen are Coming soon', () async {
      final HomeViewModel vm = await _loaded(
        _fakes(),
        routeExists: (String route) =>
            route != '/reports' && route != '/emotion-check',
      );

      final Map<ExploreId, ExploreTile> byId = <ExploreId, ExploreTile>{
        for (final ExploreTile t in vm.exploreTiles) t.id: t,
      };
      expect(byId[ExploreId.reports]!.isLive, isFalse);
      expect(byId[ExploreId.reports]!.line, 'Coming soon');
      expect(byId[ExploreId.emotionCheck]!.isLive, isFalse);
      expect(byId[ExploreId.journal]!.isLive, isTrue);
      expect(byId[ExploreId.takeABreak]!.isLive, isTrue);
    });

    test(
      'the suggestion card is hidden when meditation is not built',
      () async {
        final HomeViewModel vm = await _loaded(
          _fakes(),
          routeExists: (String route) => route != '/meditation',
        );

        expect(vm.meditationAvailable, isFalse);
      },
    );
  });

  group('The speech bubble', () {
    testWidgets('pops in about 3 seconds after the page appears', (
      WidgetTester tester,
    ) async {
      final HomeViewModel vm = Get.put<HomeViewModel>(
        buildHome(fakes: _fakes(), clock: () => evening),
      );
      await tester.pump();
      final bool animate = vm.startIntro(reduceMotion: false);

      expect(animate, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(vm.bubbleText.value, isNull);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(vm.bubbleText.value, 'Long shift? Take a minute');
    });

    testWidgets('with reduce-motion there is no animation and no wait', (
      WidgetTester tester,
    ) async {
      final HomeViewModel vm = Get.put<HomeViewModel>(
        buildHome(fakes: _fakes(), clock: () => evening),
      );
      await tester.pump();

      final bool animate = vm.startIntro(reduceMotion: true);
      await settle(tester);

      expect(animate, isFalse);
      expect(vm.bubbleText.value, 'Long shift? Take a minute');
    });

    testWidgets('a streak that grew today wins', (WidgetTester tester) async {
      final HomeFakes fakes = _fakes();
      fakes.moods.history = <MoodModel>[
        moodAt(_day(evening, 0), 'Calm'),
        moodAt(_day(evening, 1), 'Calm'),
        moodAt(_day(evening, 2), 'Calm'),
      ];
      final HomeViewModel vm = Get.put<HomeViewModel>(
        buildHome(fakes: fakes, clock: () => evening),
      );
      await tester.pump();

      vm.startIntro(reduceMotion: true);
      await settle(tester);

      expect(vm.bubbleText.value, '3 days in a row');
    });

    testWidgets('the first open of the day says good to see you', (
      WidgetTester tester,
    ) async {
      final HomeViewModel vm = Get.put<HomeViewModel>(
        buildHome(fakes: _fakes(), clock: () => afternoon),
      );
      await tester.pump();

      vm.startIntro(reduceMotion: true);
      await settle(tester);

      expect(vm.bubbleText.value, 'Good to see you');
    });

    testWidgets('a second launch on the same day has no bubble', (
      WidgetTester tester,
    ) async {
      final HomeViewModel first = Get.put<HomeViewModel>(
        buildHome(fakes: _fakes(), clock: () => afternoon),
      );
      await tester.pump();
      first.startIntro(reduceMotion: true);
      await settle(tester);
      expect(first.bubbleText.value, 'Good to see you');

      // The app is launched again later the same day.
      Get.reset();
      HomeIntro.reset();
      final HomeViewModel second = Get.put<HomeViewModel>(
        buildHome(fakes: _fakes(), clock: () => afternoon),
      );
      await tester.pump();
      second.startIntro(reduceMotion: true);
      await settle(tester);

      expect(second.bubbleText.value, isNull);
    });

    testWidgets('coming back to the Home tab does not play it again', (
      WidgetTester tester,
    ) async {
      final HomeViewModel vm = Get.put<HomeViewModel>(
        buildHome(fakes: _fakes(), clock: () => evening),
      );
      await tester.pump();
      expect(vm.startIntro(reduceMotion: false), isTrue);

      // The Home page is built again in the same launch.
      expect(vm.startIntro(reduceMotion: false), isFalse);
      expect(vm.animateIntro, isFalse);
      // Let the bubble's timer from the first call run out.
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('it waits for the moods rather than guessing', (
      WidgetTester tester,
    ) async {
      final HomeFakes fakes = _fakes();
      fakes.moods.gate = Completer<void>();
      final HomeViewModel vm = Get.put<HomeViewModel>(
        buildHome(fakes: fakes, clock: () => evening),
      );
      await tester.pump();

      vm.startIntro(reduceMotion: false);
      await tester.pump(const Duration(seconds: 4));
      expect(vm.bubbleText.value, isNull);

      fakes.moods.gate!.complete();
      await settle(tester);
      expect(vm.bubbleText.value, 'Long shift? Take a minute');
    });

    testWidgets('no moods loaded means no "no mood today" line', (
      WidgetTester tester,
    ) async {
      final HomeFakes fakes = _fakes();
      fakes.moods.failLoading = true;
      final HomeViewModel vm = Get.put<HomeViewModel>(
        buildHome(fakes: fakes, clock: () => evening),
      );
      await tester.pump();

      vm.startIntro(reduceMotion: true);
      await settle(tester);

      // It is the first open of the day, so that line is all that is left.
      expect(vm.bubbleText.value, 'Good to see you');
    });
  });
}

class _ThrowingProfileService extends FakeProfileService {
  @override
  Future<UserProfile> getCurrentUserProfile() async {
    throw StateError('offline');
  }
}
