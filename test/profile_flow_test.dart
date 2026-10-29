import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Models/user_profile.dart';
import 'package:mindmate/ui/shared/gradient_button.dart';

import 'helpers/profile_fakes.dart';
import 'helpers/setup_app.dart';

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

/// Lets a route change finish.
Future<void> go(WidgetTester tester, [int milliseconds = 600]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: milliseconds));
}

Future<SetupTestApp> open(
  WidgetTester tester, {
  FakeProfileService? service,
}) async {
  // Tall enough that each screen is on show without scrolling.
  tester.view.physicalSize = const Size(1170, 4500);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  ignoreOverflowErrors();

  final SetupTestApp app = SetupTestApp(profileService: service);
  await tester.pumpWidget(app.build());
  await go(tester);
  return app;
}

bool continueEnabled(WidgetTester tester) {
  return tester.widget<GradientButton>(find.byType(GradientButton)).onPressed !=
      null;
}

/// About you -> Your work -> the check-in intro, with a nurse on rotating
/// shifts.
Future<void> completeProfile(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'Ayesha Khan');
  await tester.pump();
  await tester.tap(find.text('Continue'));
  await go(tester);

  await tester.tap(find.text('Nurse'));
  await tester.tap(find.text('Rotating'));
  await tester.pump();
  await tester.tap(find.text('Continue'));
  await go(tester);
}

Future<void> answer(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.tap(find.text('Next'));
  await go(tester, 400);
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('About you', () {
    testWidgets('shows the first of three steps, with no way back', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(find.text('About you'), findsOneWidget);
      expect(find.text('So MindMate knows what to call you.'), findsOneWidget);
      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.text('Photo is optional'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Prefer not to say'), findsOneWidget);
      expect(
        find.byTooltip('Back'),
        findsNothing,
        reason: 'the user cannot go back to the sign-up screen',
      );
    });

    testWidgets('Continue waits for a name', (WidgetTester tester) async {
      await open(tester);
      expect(continueEnabled(tester), isFalse);

      await tester.tap(find.text('Continue'));
      await go(tester);
      expect(find.text('About you'), findsOneWidget, reason: 'still here');

      await tester.enterText(find.byType(TextField).first, 'Ayesha');
      await tester.pump();
      expect(continueEnabled(tester), isTrue);

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.pump();
      expect(continueEnabled(tester), isFalse);
    });

    testWidgets('explains an age that is out of range', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await tester.enterText(find.byType(TextField).first, 'Ayesha');
      await tester.enterText(find.byType(TextField).at(1), '17');
      await tester.pump();

      expect(find.text('Enter an age from 18 to 80.'), findsOneWidget);
      expect(continueEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextField).at(1), '29');
      await tester.pump();
      expect(find.text('Enter an age from 18 to 80.'), findsNothing);
      expect(continueEnabled(tester), isTrue);
    });

    testWidgets('starts from the name of a Google account', (
      WidgetTester tester,
    ) async {
      await open(
        tester,
        service: FakeProfileService(
          signedIn: const UserProfile(
            uid: 'u',
            name: 'Ayesha Khan',
            email: 'a@example.com',
            imageUrl: '',
            bio: '',
            age: null,
            gender: '',
          ),
        ),
      );
      expect(find.text('Ayesha Khan'), findsOneWidget);
      expect(continueEnabled(tester), isTrue);
    });
  });

  group('Your work', () {
    testWidgets('needs a role and shifts, and goes back with answers kept', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await tester.enterText(find.byType(TextField).first, 'Ayesha Khan');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await go(tester);

      expect(find.text('Your work'), findsOneWidget);
      expect(find.text('2 of 3'), findsOneWidget);
      expect(find.text('Doctor'), findsOneWidget);
      expect(find.text('Admin staff'), findsOneWidget);
      expect(find.text('On call'), findsOneWidget);
      expect(find.text('Over 10'), findsOneWidget);
      expect(find.text('Department (optional)'), findsOneWidget);
      expect(continueEnabled(tester), isFalse);

      await tester.tap(find.text('Nurse'));
      await tester.pump();
      expect(continueEnabled(tester), isFalse, reason: 'shifts are missing');

      await tester.tap(find.text('Night'));
      await tester.pump();
      expect(continueEnabled(tester), isTrue);

      await tester.tap(find.byTooltip('Back'));
      await go(tester);
      expect(find.text('About you'), findsOneWidget);
      expect(find.text('Ayesha Khan'), findsOneWidget);
    });

    testWidgets('saves the profile and moves on to the check-in', (
      WidgetTester tester,
    ) async {
      final SetupTestApp app = await open(tester);
      await tester.enterText(find.byType(TextField).first, 'Ayesha Khan');
      await tester.enterText(find.byType(TextField).at(1), '29');
      await tester.tap(find.text('Female'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await go(tester);

      await tester.tap(find.text('Nurse'));
      await tester.tap(find.text('Rotating'));
      await tester.tap(find.text('2 to 5'));
      await tester.enterText(find.byType(TextField), 'Emergency');
      await tester.pump();
      expect(app.profileService.created, isEmpty, reason: 'not saved yet');

      await tester.tap(find.text('Continue'));
      await go(tester);

      expect(app.profileService.created, hasLength(1));
      final UserProfile saved = app.profileService.created.single;
      expect(saved.name, 'Ayesha Khan');
      expect(saved.age, 29);
      expect(saved.gender, 'Female');
      expect(saved.role, 'Nurse');
      expect(saved.shiftPattern, 'rotating');
      expect(saved.yearsInHealthcare, '2_to_5');
      expect(saved.department, 'Emergency');
      expect(find.text('A quick check-in'), findsOneWidget);
    });
  });

  group('The check-in', () {
    testWidgets('has an intro with what to expect', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await completeProfile(tester);

      expect(find.text('A quick check-in'), findsOneWidget);
      expect(find.text('About 2 minutes, 9 questions'), findsOneWidget);
      expect(
        find.text('Private. Never shared with your employer.'),
        findsOneWidget,
      );
      expect(find.text('Skip any question you like'), findsOneWidget);
      expect(
        find.text(
          'This is a self check-in, not a diagnosis or a medical assessment.',
        ),
        findsOneWidget,
      );
      expect(find.text('Begin'), findsOneWidget);
      expect(find.text('Do this later'), findsOneWidget);
    });

    testWidgets('goes through all nine questions to All set', (
      WidgetTester tester,
    ) async {
      final SetupTestApp app = await open(tester);
      await completeProfile(tester);
      await tester.tap(find.text('Begin'));
      await go(tester);

      // 1: what brings you here (pick any).
      expect(find.text('What brings you here?'), findsOneWidget);
      expect(find.text('1 of 9'), findsOneWidget);
      expect(find.text('Choose any that apply.'), findsOneWidget);
      await tester.tap(find.text('Sleep better'));
      await tester.tap(find.text('Manage stress'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await go(tester, 400);

      // 2 to 6: WHO-5.
      expect(find.text('OVER THE LAST TWO WEEKS'), findsOneWidget);
      expect(
        find.text('I have felt cheerful and in good spirits.'),
        findsOneWidget,
      );
      expect(find.text('2 of 9'), findsOneWidget);
      await answer(tester, 'Most of the time');
      expect(find.text('I have felt calm and relaxed.'), findsOneWidget);
      await answer(tester, 'More than half the time');
      expect(find.text('I have felt active and vigorous.'), findsOneWidget);
      await answer(tester, 'More than half the time');
      expect(find.text('I woke up feeling fresh and rested.'), findsOneWidget);
      await answer(tester, 'Less than half the time');
      expect(
        find.text(
          'My daily life has been filled with things that interest me.',
        ),
        findsOneWidget,
      );
      await answer(tester, 'All of the time');

      // 7 to 9.
      expect(find.text('How stressful has work felt lately?'), findsOneWidget);
      await answer(tester, 'Very');
      expect(find.text('How well have you been sleeping?'), findsOneWidget);
      await tester.tap(find.text('Skip this question'));
      await go(tester, 400);
      expect(
        find.text('When would you like a daily reminder?'),
        findsOneWidget,
      );
      expect(find.text('Finish'), findsOneWidget, reason: 'the last question');
      await tester.tap(find.text('After my shift'));
      await tester.pump();
      await tester.tap(find.text('Finish'));
      await go(tester);

      // All set.
      expect(find.text('YOU ARE ALL SET'), findsOneWidget);
      expect(find.text('Welcome, Ayesha'), findsOneWidget);
      expect(
        find.text(
          'Here is where MindMate suggests you start, based on your answers.',
        ),
        findsOneWidget,
      );
      expect(find.text('YOUR FOCUS'), findsOneWidget);
      expect(find.text('Sleep and switching off after shifts'), findsOneWidget);
      expect(find.text('Daily mood check-in'), findsOneWidget);
      expect(find.text('Reminder after your shift, 8:00 pm'), findsOneWidget);
      expect(find.text('Sleep wind-down'), findsOneWidget);
      expect(find.text('Leaving work at work'), findsOneWidget);
      expect(
        find.text('You can change any of this later in Settings.'),
        findsOneWidget,
      );
      expect(find.textContaining('heavy lately'), findsNothing);

      expect(app.profileService.checkIns, hasLength(1));
      expect(app.profileService.checkIns.single.who5Score, 68);
      expect(app.profileService.checkIns.single.sleepQuality, isNull);

      await tester.tap(find.text('Go to home'));
      await go(tester);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('Back keeps the answers, and the first question goes back '
        'to the intro', (WidgetTester tester) async {
      await open(tester);
      await completeProfile(tester);
      await tester.tap(find.text('Begin'));
      await go(tester);

      await tester.tap(find.text('Manage stress'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await go(tester, 400);
      await answer(tester, 'Some of the time');
      expect(find.text('3 of 9'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await go(tester, 400);
      expect(find.text('2 of 9'), findsOneWidget);
      // The answer is still chosen, so Next works straight away.
      await tester.tap(find.text('Next'));
      await go(tester, 400);
      expect(find.text('3 of 9'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await go(tester, 400);
      await tester.tap(find.byTooltip('Back'));
      await go(tester, 400);
      expect(find.text('1 of 9'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await go(tester, 400);
      expect(find.text('2 of 9'), findsOneWidget, reason: 'goal still chosen');

      await tester.tap(find.byTooltip('Back'));
      await go(tester, 400);
      await tester.tap(find.byTooltip('Back'));
      await go(tester, 400);
      expect(find.text('A quick check-in'), findsOneWidget);
    });

    testWidgets('Next waits for an answer, and skipping does not', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await completeProfile(tester);
      await tester.tap(find.text('Begin'));
      await go(tester);

      expect(
        tester.widget<GradientButton>(find.byType(GradientButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Skip this question'));
      await go(tester, 400);
      expect(find.text('2 of 9'), findsOneWidget);
    });

    testWidgets('adds a gentle line when the answers suggest heavy weeks', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await completeProfile(tester);
      await tester.tap(find.text('Begin'));
      await go(tester);

      await tester.tap(find.text('Skip this question'));
      await go(tester, 400);
      for (final String label in <String>[
        'Some of the time',
        'At no time',
        'At no time',
        'Some of the time',
        'At no time',
      ]) {
        await answer(tester, label);
      }
      for (int i = 0; i < 3; i += 1) {
        await tester.tap(find.text('Skip this question'));
        await go(tester, 400);
      }

      expect(
        find.text(
          'It sounds like things have been heavy lately. If it stays this '
          'way, talking to someone you trust or a professional can help.',
        ),
        findsOneWidget,
      );
      expect(find.text('Building a daily check-in habit'), findsOneWidget);
    });

    testWidgets('"Do this later" goes to All set and saves nothing', (
      WidgetTester tester,
    ) async {
      final SetupTestApp app = await open(tester);
      await completeProfile(tester);

      await tester.tap(find.text('Do this later'));
      await go(tester);

      expect(find.text('Welcome, Ayesha'), findsOneWidget);
      expect(find.text('Building a daily check-in habit'), findsOneWidget);
      expect(find.text('The 3-step pause'), findsOneWidget);
      expect(find.text('A calm place'), findsOneWidget);
      expect(find.textContaining('based on your answers'), findsNothing);
      expect(find.textContaining('heavy lately'), findsNothing);
      expect(app.profileService.checkIns, isEmpty);

      await tester.tap(find.text('Go to home'));
      await go(tester);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('a starting point opens its practice', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await completeProfile(tester);
      await tester.tap(find.text('Do this later'));
      await go(tester);

      await tester.tap(find.text('A calm place'));
      await go(tester);
      expect(find.text('PRACTICE DETAILS'), findsOneWidget);
    });

    testWidgets('the system back button on All set goes Home', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await completeProfile(tester);
      await tester.tap(find.text('Do this later'));
      await go(tester);

      await tester.binding.handlePopRoute();
      await go(tester);
      expect(find.text('HOME'), findsOneWidget);
    });
  });
}
