import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Models/meditation_audio.dart';
import 'package:mindmate/Models/meditation_log_entry.dart';
import 'package:mindmate/Models/mood_model.dart';
import 'package:mindmate/services/meditation_voice_service.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/meditation/meditation_player_viewmodel.dart';
import 'package:mindmate/ui/meditation/meditation_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/meditation_app.dart';
import 'helpers/meditation_fakes.dart';

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

Future<void> seconds(WidgetTester tester, int count) async {
  for (int i = 0; i < count; i += 1) {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// Plays until "Well done" is on screen.
Future<void> playToTheEnd(WidgetTester tester) async {
  for (
    int i = 0;
    i < 200 && find.text('Well done').evaluate().isEmpty;
    i += 1
  ) {
    await tester.pump(const Duration(seconds: 1));
  }
  await go(tester);
}

Future<MeditationTestApp> openLibrary(
  WidgetTester tester, {
  bool voiceOn = false,
  MeditationTestApp? app,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'meditation_voice_enabled': voiceOn,
  });
  // Tall enough that the whole library list is on screen.
  tester.view.physicalSize = const Size(1170, 4500);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  ignoreOverflowErrors();

  final MeditationTestApp testApp = app ?? MeditationTestApp();
  await tester.pumpWidget(testApp.build());
  await tester.pump();
  Get.toNamed(AppRoutes.meditation);
  await go(tester);
  await tester.pump();
  return testApp;
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('A whole practice', () {
    testWidgets('from the library to "Well done" and back', (
      WidgetTester tester,
    ) async {
      final MeditationTestApp app = await openLibrary(tester);
      expect(find.text('Meditation'), findsOneWidget);
      expect(find.text('SUGGESTED FOR YOU'), findsOneWidget);

      // Library -> details.
      await tester.tap(find.text('Mindful hand-washing'));
      await go(tester);
      expect(find.text('Begin'), findsOneWidget);
      expect(find.text('BETWEEN PATIENTS'), findsOneWidget);
      expect(find.text('1 min'), findsOneWidget);
      expect(find.text('GOOD FOR'), findsOneWidget);
      expect(find.text('WHERE IT COMES FROM'), findsOneWidget);
      expect(
        find.text(
          'Keep your eyes open if you prefer. You can stop at any time.',
        ),
        findsOneWidget,
        reason: 'a practice without a note of its own shows the usual one',
      );

      // Details -> check-in.
      await tester.tap(find.text('Begin'));
      await go(tester);
      expect(find.text('Before you begin'), findsOneWidget);
      expect(find.text('How do you feel right now?'), findsOneWidget);
      expect(find.text('Voice guidance'), findsOneWidget);
      await tester.tap(find.text('Low'));
      await tester.pump();

      // Check-in -> player.
      await tester.tap(find.text('Start practice'));
      await go(tester);
      expect(find.text('STEP 1 OF 5'), findsOneWidget);
      expect(find.text('1:00'), findsOneWidget);
      expect(
        find.text('As the water runs, notice its temperature on your hands.'),
        findsOneWidget,
      );
      expect(app.keepAwake.enabled, isTrue);

      await seconds(tester, 3);
      expect(find.text('0:57'), findsOneWidget);

      // Pause stops the clock; play carries on.
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(find.byTooltip('Play'), findsOneWidget);
      expect(app.keepAwake.enabled, isFalse);
      await seconds(tester, 10);
      expect(find.text('0:57'), findsOneWidget);

      await tester.tap(find.byTooltip('Play'));
      await tester.pump();
      expect(app.keepAwake.enabled, isTrue);

      // Next step jumps to the start of the next one.
      await tester.tap(find.byTooltip('Next step'));
      await tester.pump();
      expect(find.text('STEP 2 OF 5'), findsOneWidget);
      expect(find.text('0:50'), findsOneWidget);
      expect(
        find.text(
          'Feel the soap. Notice the movement of your fingers, '
          'palms, and wrists.',
        ),
        findsOneWidget,
      );

      // Play to the end.
      await playToTheEnd(tester);
      expect(find.text('Well done'), findsOneWidget);
      expect(find.text('Mindful hand-washing · 1 min'), findsOneWidget);
      expect(app.keepAwake.enabled, isFalse);

      // The practice was saved as soon as it finished.
      expect(app.logService.saved, hasLength(1));
      final MeditationLogEntry saved = app.logService.saved.single;
      expect(saved.sessionId, 'mindful_hand_washing');
      expect(saved.completed, isTrue);
      expect(saved.feelBefore, 2);
      expect(saved.feelAfter, isNull);
      expect(find.text('Before: Low'), findsNothing);

      // How the user feels now.
      await tester.tap(find.text('Good'));
      await tester.pump();
      expect(find.text('Before: Low'), findsOneWidget);
      expect(find.text('Now: Good'), findsOneWidget);
      expect(app.logService.feelAfterUpdates, <String, int>{saved.id: 4});
      expect(find.textContaining('this week'), findsOneWidget);
      expect(find.text('1 day streak'), findsOneWidget);

      // Done goes back to the library, with this practice counted.
      await tester.tap(find.text('Done'));
      await go(tester);
      expect(find.text('Meditation'), findsOneWidget);
      expect(find.text('Well done'), findsNothing);
      expect(find.text('session'), findsOneWidget);
      expect(Get.isRegistered<MeditationPlayerViewModel>(), isFalse);
    });

    testWidgets('can skip the check-in', (WidgetTester tester) async {
      final MeditationTestApp app = await openLibrary(tester);

      await tester.tap(find.text('Mindful hand-washing'));
      await go(tester);
      await tester.tap(find.text('Begin'));
      await go(tester);
      await tester.tap(find.text('Skip the check-in'));
      await go(tester);
      expect(find.text('STEP 1 OF 5'), findsOneWidget);

      await playToTheEnd(tester);
      expect(app.logService.saved.single.feelBefore, isNull);

      await tester.tap(find.text('Good'));
      await tester.pump();
      expect(
        find.textContaining('Before:'),
        findsNothing,
        reason: 'no before-and-after line without a before',
      );
      expect(app.logService.feelAfterUpdates.values.single, 4);
    });

    testWidgets('"Log this in Mood" opens the mood flow', (
      WidgetTester tester,
    ) async {
      await openLibrary(tester);
      await tester.tap(find.text('Mindful hand-washing'));
      await go(tester);
      await tester.tap(find.text('Begin'));
      await go(tester);
      await tester.tap(find.text('Skip the check-in'));
      await go(tester);
      await playToTheEnd(tester);

      await tester.tap(find.text('Log this in Mood'));
      await go(tester);
      expect(find.text('MOOD LOG'), findsOneWidget);
      expect(find.text('Well done'), findsNothing);
    });

    testWidgets('the system back button leaves "Well done"', (
      WidgetTester tester,
    ) async {
      await openLibrary(tester);
      await tester.tap(find.text('Mindful hand-washing'));
      await go(tester);
      await tester.tap(find.text('Begin'));
      await go(tester);
      await tester.tap(find.text('Skip the check-in'));
      await go(tester);
      await playToTheEnd(tester);

      await tester.binding.handlePopRoute();
      await go(tester);
      expect(find.text('Meditation'), findsOneWidget);
      expect(find.text('Well done'), findsNothing);
    });
  });

  group('Ending early', () {
    Future<MeditationTestApp> startPractice(WidgetTester tester) async {
      final MeditationTestApp app = await openLibrary(tester);
      await tester.tap(find.text('Mindful hand-washing'));
      await go(tester);
      await tester.tap(find.text('Begin'));
      await go(tester);
      await tester.tap(find.text('Low'));
      await tester.pump();
      await tester.tap(find.text('Start practice'));
      await go(tester);
      return app;
    }

    testWidgets('asks first, and Keep going carries on', (
      WidgetTester tester,
    ) async {
      final MeditationTestApp app = await startPractice(tester);
      await seconds(tester, 5);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await go(tester);
      expect(find.text('End this practice?'), findsOneWidget);
      expect(find.byTooltip('Play'), findsOneWidget, reason: 'it is paused');

      await tester.tap(find.text('Keep going'));
      await go(tester);
      expect(find.text('End this practice?'), findsNothing);
      expect(find.byTooltip('Pause'), findsOneWidget, reason: 'playing again');
      expect(find.text('STEP 1 OF 5'), findsOneWidget);
      expect(app.logService.saved, isEmpty);
    });

    testWidgets('End saves the practice as not completed', (
      WidgetTester tester,
    ) async {
      final MeditationTestApp app = await startPractice(tester);
      await seconds(tester, 5);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await go(tester);
      await tester.tap(find.text('End'));
      await go(tester);

      expect(find.text('Meditation'), findsOneWidget);
      expect(find.text('Well done'), findsNothing);
      expect(app.logService.saved, hasLength(1));
      final MeditationLogEntry saved = app.logService.saved.single;
      expect(saved.completed, isFalse);
      expect(saved.secondsPractised, 5);
      expect(saved.feelBefore, 2);
      expect(app.keepAwake.enabled, isFalse);
      expect(find.text('session'), findsOneWidget);
    });

    testWidgets('the system back button asks first', (
      WidgetTester tester,
    ) async {
      final MeditationTestApp app = await startPractice(tester);
      await seconds(tester, 2);

      await tester.binding.handlePopRoute();
      await go(tester);
      expect(find.text('End this practice?'), findsOneWidget);
      expect(find.text('STEP 1 OF 5'), findsOneWidget, reason: 'still here');

      await tester.tap(find.text('Keep going'));
      await go(tester);
      expect(app.logService.saved, isEmpty);
    });
  });

  group('Voice', () {
    testWidgets('the check-in switch is remembered and starts the voice', (
      WidgetTester tester,
    ) async {
      final MeditationTestApp app = await openLibrary(tester);

      await tester.tap(find.text('Mindful hand-washing'));
      await go(tester);
      await tester.tap(find.text('Begin'));
      await go(tester);

      final Switch voiceSwitch = tester.widget<Switch>(find.byType(Switch));
      expect(voiceSwitch.value, isFalse, reason: 'it was saved as off');
      await tester.tap(find.byType(Switch));
      await tester.pump();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('meditation_voice_enabled'), isTrue);

      await tester.tap(find.text('Start practice'));
      await go(tester);
      expect(app.voice.spoken, <String>[
        'As the water runs, notice its temperature on your hands.',
      ]);
      expect(find.byTooltip('Turn voice off'), findsOneWidget);

      await tester.tap(find.byTooltip('Turn voice off'));
      await tester.pump();
      expect(app.voice.isSpeaking, isFalse);
      expect(find.byTooltip('Turn voice on'), findsOneWidget);
    });

    testWidgets('a failing voice does not stop the practice', (
      WidgetTester tester,
    ) async {
      final MeditationTestApp app = await openLibrary(tester, voiceOn: true);
      await tester.tap(find.text('Mindful hand-washing'));
      await go(tester);
      await tester.tap(find.text('Begin'));
      await go(tester);
      await tester.tap(find.text('Skip the check-in'));
      await go(tester);

      app.voice.finishSpeaking(SpeechOutcome.failed);
      await tester.pump();
      expect(find.byTooltip('Voice is not available'), findsOneWidget);

      await seconds(tester, 10);
      expect(find.text('STEP 2 OF 5'), findsOneWidget);
      expect(find.byTooltip('Pause'), findsOneWidget);
    });
  });

  group('Suggested for you', () {
    testWidgets('opens the practice, with its own note', (
      WidgetTester tester,
    ) async {
      final MeditationTestApp app = MeditationTestApp(
        moodService: FakeMoodService()
          ..todayMood = MoodModel(
            mood: 'Stressed',
            valence: -1,
            intensity: 'Strong',
            note: '',
            date: DateTime.now(),
          ),
      );
      await openLibrary(tester, app: app);

      expect(find.text('SUGGESTED FOR YOU'), findsOneWidget);
      expect(find.textContaining('You logged Stressed today'), findsOneWidget);

      await tester.tap(find.text('SUGGESTED FOR YOU'));
      await go(tester);
      expect(find.text('AFTER A HARD MOMENT'), findsOneWidget);
      expect(
        find.text(
          'If this brings up more than you expected, stop and talk to '
          'someone you trust.',
        ),
        findsOneWidget,
      );
    });
  });

  group('Breathing practices', () {
    testWidgets('keep working as a timer', (WidgetTester tester) async {
      final MeditationTestApp app = await openLibrary(tester);
      Get.find<MeditationViewModel>().selectGroup('breathing');
      await tester.pump();
      expect(find.text('Gentle Reset'), findsOneWidget);
      expect(
        find.text('Mindful hand-washing'),
        findsNothing,
        reason: 'only the breathing practices are listed',
      );

      await tester.tap(find.text('Gentle Reset'));
      await go(tester);
      expect(find.text('BREATHING'), findsOneWidget);
      expect(find.text('5 min'), findsOneWidget);
      expect(find.text('Breathing timer'), findsOneWidget);
      expect(find.text('GOOD FOR'), findsNothing);
      expect(find.text('WHERE IT COMES FROM'), findsNothing);

      await tester.tap(find.text('Begin'));
      await go(tester);
      expect(find.text('Voice guidance'), findsNothing);

      await tester.tap(find.text('Skip the check-in'));
      await go(tester);
      expect(find.text('5:00'), findsOneWidget);
      expect(
        find.text(
          'A soft pause to release tension and settle into the moment.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('BREATHE'), findsOneWidget);
      expect(find.textContaining('STEP'), findsNothing);
      expect(find.byTooltip('Next step'), findsNothing);
      expect(find.byTooltip('Turn voice off'), findsNothing);

      await seconds(tester, 3);
      expect(find.text('4:57'), findsOneWidget);
      expect(app.voice.spoken, isEmpty, reason: 'nothing is read out');

      await tester.tap(find.byIcon(Icons.close_rounded));
      await go(tester);
      await tester.tap(find.text('End'));
      await go(tester);
      expect(find.text('Meditation'), findsOneWidget);
      expect(app.logService.saved.single.sessionId, 'breathing_gentle_reset');
      expect(app.logService.saved.single.secondsPractised, 3);
    });
  });

  group('Going back', () {
    testWidgets('the back buttons return one screen at a time', (
      WidgetTester tester,
    ) async {
      await openLibrary(tester);

      await tester.tap(find.text('Mindful hand-washing'));
      await go(tester);
      await tester.tap(find.text('Begin'));
      await go(tester);
      expect(find.text('Before you begin'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await go(tester);
      expect(find.text('Begin'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await go(tester);
      expect(find.text('Meditation'), findsOneWidget);
      expect(Get.isRegistered<MeditationPlayerViewModel>(), isFalse);
    });

    testWidgets('a practice can be opened again after leaving it', (
      WidgetTester tester,
    ) async {
      await openLibrary(tester);

      await tester.tap(find.text('Mindful hand-washing'));
      await go(tester);
      await tester.tap(find.byTooltip('Back'));
      await go(tester);

      await tester.tap(find.text('STOP'));
      await go(tester);
      expect(find.text('WHEN OVERWHELMED'), findsOneWidget);
      expect(find.text('2 min'), findsOneWidget);
    });
  });

  group('Calm voice and background sound', () {
    testWidgets('details show "Calm voice"; the sound sheet plays and saves', (
      WidgetTester tester,
    ) async {
      final MeditationTestApp app = await openLibrary(tester);
      await tester.tap(find.text('Mindful hand-washing'));
      await go(tester);
      expect(find.text('Calm voice'), findsOneWidget);
      expect(find.text('Soft rain'), findsNothing, reason: 'Off by default');

      await tester.tap(find.text('Begin'));
      await go(tester);
      await tester.tap(find.text('Start practice'));
      await go(tester);

      await tester.tap(find.byTooltip('Background sound'));
      await go(tester);
      expect(find.text('Background sound'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('Warm tones'), findsOneWidget);

      await tester.tap(find.text('Soft rain'));
      await go(tester, 200);
      expect(app.voice.ambientChoices.last, AmbientChoice.softRain);
      // Saved as one field in the user's settings.
      expect(
        app.settingsService.updates.last,
        isA<MapEntry<String, Object?>>()
            .having(
              (MapEntry<String, Object?> e) => e.key,
              'key',
              'meditationSound',
            )
            .having(
              (MapEntry<String, Object?> e) => e.value,
              'value',
              'soft_rain',
            ),
      );

      // The slider changes the volume.
      await tester.drag(find.byType(Slider), const Offset(-60, 0));
      await go(tester, 200);
      expect(app.voice.volumes, isNotEmpty);
    });
  });
}
