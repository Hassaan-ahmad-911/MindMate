import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Models/meditation_log_entry.dart';
import 'package:mindmate/services/meditation_voice_service.dart';
import 'package:mindmate/ui/meditation/meditation_player_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/meditation_fakes.dart';

/// Like [testWidgets], but closes the ViewModel at the end, as leaving the
/// screen does. Otherwise its one-second timer would still be running.
void vmTest(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (WidgetTester tester) async {
    try {
      await body(tester);
    } finally {
      Get.delete<MeditationPlayerViewModel>();
      await tester.pump();
    }
  });
}

void main() {
  late FakeAudioService voice;
  late FakeKeepAwake keepAwake;
  late FakeLogService logService;
  late MeditationPlayerViewModel vm;

  Future<void> start(
    WidgetTester tester, {
    bool voiceOn = true,
    int? feelBefore,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'meditation_voice_enabled': voiceOn,
    });
    voice = FakeAudioService();
    keepAwake = FakeKeepAwake();
    logService = FakeLogService();
    vm = Get.put<MeditationPlayerViewModel>(
      MeditationPlayerViewModel(
        repository: buildRepository(logService),
        audio: voice,
        keepAwake: keepAwake,
        source: tinySession,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(vm.session.value, isNotNull);
    if (feelBefore != null) {
      vm.setFeelBefore(feelBefore);
    }
    vm.startPractice();
    await tester.pump();
  }

  Future<void> seconds(WidgetTester tester, int count) async {
    for (int i = 0; i < count; i += 1) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  group('Starting', () {
    vmTest('starts playing, keeps the screen on and reads step 1', (
      WidgetTester tester,
    ) async {
      await start(tester);

      expect(vm.isPlaying.value, isTrue);
      expect(keepAwake.enabled, isTrue);
      expect(voice.spoken, <String>['one']);
      expect(vm.secondsLeft.value, 9);
      expect(vm.timeLeftLabel, '0:09');
    });

    vmTest('does not speak when voice guidance is off', (
      WidgetTester tester,
    ) async {
      await start(tester, voiceOn: false);

      expect(vm.voiceEnabled.value, isFalse);
      expect(voice.spoken, isEmpty);
      await seconds(tester, 3);
      expect(vm.stepIndex.value, 1);
      expect(voice.spoken, isEmpty);
    });

    vmTest('remembers the voice switch', (WidgetTester tester) async {
      await start(tester);
      vm.setVoiceGuidance(false);
      await tester.pump();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('meditation_voice_enabled'), isFalse);
    });

    test('formats the time left', () {
      expect(MeditationPlayerViewModel.formatTimeLeft(75), '1:15');
      expect(MeditationPlayerViewModel.formatTimeLeft(5), '0:05');
      expect(MeditationPlayerViewModel.formatTimeLeft(600), '10:00');
      expect(MeditationPlayerViewModel.formatTimeLeft(-3), '0:00');
    });
  });

  group('Voice and step timing', () {
    vmTest('reads the next step when a step ends', (WidgetTester tester) async {
      await start(tester);
      voice.finishSpeaking();
      await tester.pump();

      await seconds(tester, 3);
      expect(vm.stepIndex.value, 1);
      expect(voice.spoken, <String>['one', 'two']);
    });

    vmTest('waits for the voice when a step ends before it is done', (
      WidgetTester tester,
    ) async {
      await start(tester);
      // The voice keeps going past the 3 seconds.
      await seconds(tester, 5);
      expect(vm.stepIndex.value, 0);
      expect(voice.spoken, <String>['one']);

      voice.finishSpeaking();
      await tester.pump();

      // It moves on at once, without waiting for the next tick.
      expect(vm.stepIndex.value, 1);
      expect(voice.spoken, <String>['one', 'two']);
    });

    vmTest('never waits for a voice that does not finish', (
      WidgetTester tester,
    ) async {
      await start(tester);
      await seconds(tester, 3 + MeditationPlayerEngineHoldLimit.seconds);
      expect(vm.stepIndex.value, 1);
    });

    vmTest('carries on silently when the voice fails', (
      WidgetTester tester,
    ) async {
      await start(tester);
      voice.finishSpeaking(SpeechOutcome.failed);
      await tester.pump();

      expect(vm.voiceAvailable.value, isFalse);
      expect(vm.isPlaying.value, isTrue);

      await seconds(tester, 3);
      expect(vm.stepIndex.value, 1);
      expect(voice.spoken, <String>['one'], reason: 'no more attempts');
    });

    vmTest('does not speak when the voice failed on a later step', (
      WidgetTester tester,
    ) async {
      await start(tester);
      voice.finishSpeaking();
      await tester.pump();
      await seconds(tester, 3);
      voice.finishSpeaking(SpeechOutcome.failed);
      await tester.pump();

      await seconds(tester, 3);
      expect(vm.stepIndex.value, 2);
      expect(voice.spoken, <String>['one', 'two']);
    });
  });

  group('Pause and resume', () {
    vmTest('pauses the clock, the sound and the awake screen', (
      WidgetTester tester,
    ) async {
      await start(tester);
      await seconds(tester, 1);

      vm.togglePlayPause();
      await tester.pump();
      expect(vm.isPlaying.value, isFalse);
      expect(voice.pauses, 1);
      expect(voice.paused, isTrue);
      expect(keepAwake.enabled, isFalse);

      await seconds(tester, 10);
      expect(vm.secondsLeft.value, 8);
      expect(vm.stepIndex.value, 0);
    });

    vmTest('resume continues the clip where it paused', (
      WidgetTester tester,
    ) async {
      await start(tester);
      await seconds(tester, 1);

      vm.pause();
      vm.resume();
      await tester.pump();

      expect(vm.isPlaying.value, isTrue);
      expect(vm.stepIndex.value, 0);
      expect(keepAwake.enabled, isTrue);
      expect(voice.resumes, 1);
      expect(voice.paused, isFalse);
      expect(voice.spoken, <String>['one'], reason: 'not started again');
      expect(voice.isSpeaking, isTrue);
    });

    vmTest('a step changed while paused starts from its beginning', (
      WidgetTester tester,
    ) async {
      await start(tester);
      vm.pause();
      vm.next();
      await tester.pump();
      expect(voice.isSpeaking, isFalse, reason: 'the old clip stopped');

      vm.resume();
      await tester.pump();
      expect(voice.spoken, <String>['one', 'two']);
    });

    vmTest('a phone call pauses and does not resume by itself', (
      WidgetTester tester,
    ) async {
      await start(tester);
      voice.interruptController.add(null);
      await tester.pump();
      expect(vm.isPlaying.value, isFalse);
      await seconds(tester, 5);
      expect(vm.isPlaying.value, isFalse);
    });

    vmTest('does not say a step again if it had already finished', (
      WidgetTester tester,
    ) async {
      await start(tester);
      voice.finishSpeaking();
      await tester.pump();
      await seconds(tester, 1);

      vm.pause();
      vm.resume();
      await tester.pump();

      expect(voice.spoken, <String>['one']);
      expect(vm.stepIndex.value, 0);
    });

    vmTest('pauses when the app goes to the background', (
      WidgetTester tester,
    ) async {
      await start(tester);
      vm.didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(vm.isPlaying.value, isFalse);
      expect(keepAwake.enabled, isFalse);

      vm.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(vm.isPlaying.value, isFalse, reason: 'the user presses play');
    });

    vmTest('pausing for the end question, then keeping going', (
      WidgetTester tester,
    ) async {
      await start(tester);
      vm.pauseForDialog();
      expect(vm.isPlaying.value, isFalse);
      vm.resumeAfterDialog();
      expect(vm.isPlaying.value, isTrue);
    });

    vmTest('stays paused after the end question if it was paused', (
      WidgetTester tester,
    ) async {
      await start(tester);
      vm.pause();
      vm.pauseForDialog();
      vm.resumeAfterDialog();
      expect(vm.isPlaying.value, isFalse);
    });
  });

  group('Next and previous', () {
    vmTest('jump to the start of a step and read it', (
      WidgetTester tester,
    ) async {
      await start(tester);
      await seconds(tester, 1);

      vm.next();
      await tester.pump();
      expect(vm.stepIndex.value, 1);
      expect(vm.secondsLeft.value, 6);
      expect(voice.spoken, <String>['one', 'two']);

      vm.previous();
      await tester.pump();
      expect(vm.stepIndex.value, 0);
      expect(vm.secondsLeft.value, 9);
      expect(voice.spoken, <String>['one', 'two', 'one']);
    });

    vmTest('next does nothing on the last step', (WidgetTester tester) async {
      await start(tester);
      vm.next();
      vm.next();
      await tester.pump();
      expect(vm.isLastStep, isTrue);

      vm.next();
      expect(vm.stepIndex.value, 2);
    });

    vmTest('while paused they wait to read the new step', (
      WidgetTester tester,
    ) async {
      await start(tester);
      vm.pause();

      vm.next();
      expect(vm.stepIndex.value, 1);
      expect(voice.spoken, <String>['one']);

      vm.resume();
      await tester.pump();
      expect(voice.spoken, <String>['one', 'two']);
    });
  });

  group('Voice button', () {
    vmTest('turns the voice off and on for this practice', (
      WidgetTester tester,
    ) async {
      await start(tester);

      vm.toggleVoice();
      expect(vm.voiceEnabled.value, isFalse);
      expect(voice.isSpeaking, isFalse);

      vm.pause();
      vm.resume();
      await tester.pump();
      expect(voice.spoken, <String>['one'], reason: 'off means silent');

      vm.toggleVoice();
      await tester.pump();
      expect(vm.voiceEnabled.value, isTrue);
      expect(voice.spoken, <String>['one', 'one']);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool('meditation_voice_enabled'),
        isTrue,
        reason: 'the player button does not change the saved choice',
      );
    });
  });

  group('Finishing', () {
    vmTest('saves a finished practice and releases the screen', (
      WidgetTester tester,
    ) async {
      await start(tester, feelBefore: 2);
      for (int step = 0; step < 3; step += 1) {
        voice.finishSpeaking();
        await tester.pump();
        await seconds(tester, 3);
      }

      expect(vm.isPlaying.value, isFalse);
      expect(keepAwake.enabled, isFalse);
      expect(logService.saved, hasLength(1));

      final MeditationLogEntry entry = logService.saved.single;
      expect(entry.id, 'log-1');
      expect(entry.sessionId, 'test_practice');
      expect(entry.title, 'Test practice');
      expect(entry.completed, isTrue);
      expect(entry.secondsPractised, 9);
      expect(entry.feelBefore, 2);
      expect(entry.feelAfter, isNull);
      expect(entry.endedAt.isBefore(entry.startedAt), isFalse);
    });

    vmTest('records how the user feels afterwards', (
      WidgetTester tester,
    ) async {
      await start(tester, feelBefore: 2);
      for (int step = 0; step < 3; step += 1) {
        voice.finishSpeaking();
        await tester.pump();
        await seconds(tester, 3);
      }

      vm.setFeelAfter(4);
      await tester.pump();
      expect(vm.feelAfter.value, 4);
      expect(logService.feelAfterUpdates, <String, int>{'log-1': 4});
    });

    vmTest('counts this practice in the week numbers', (
      WidgetTester tester,
    ) async {
      await start(tester);
      for (int step = 0; step < 3; step += 1) {
        voice.finishSpeaking();
        await tester.pump();
        await seconds(tester, 3);
      }

      expect(vm.streak.value, 1);
      expect(vm.weekMinutes.value, 0, reason: '9 seconds is under a minute');
    });
  });

  group('Ending early', () {
    vmTest('saves it as not completed', (WidgetTester tester) async {
      await start(tester, feelBefore: 3);
      await seconds(tester, 4);

      vm.endEarly();
      await tester.pump();

      expect(logService.saved, hasLength(1));
      final MeditationLogEntry entry = logService.saved.single;
      expect(entry.completed, isFalse);
      expect(entry.secondsPractised, 4);
      expect(entry.feelBefore, 3);
      expect(keepAwake.enabled, isFalse);
      expect(vm.isPlaying.value, isFalse);
      expect(voice.isSpeaking, isFalse);

      await seconds(tester, 10);
      expect(logService.saved, hasLength(1), reason: 'the clock has stopped');
    });

    vmTest('does not save when nothing was practised', (
      WidgetTester tester,
    ) async {
      await start(tester);
      vm.endEarly();
      await tester.pump();
      expect(logService.saved, isEmpty);
    });

    vmTest('does not count the time spent paused', (WidgetTester tester) async {
      await start(tester);
      await seconds(tester, 2);
      vm.pause();
      await seconds(tester, 30);
      vm.resume();
      await seconds(tester, 1);

      vm.endEarly();
      expect(logService.saved.single.secondsPractised, 3);
    });
  });

  group('Closing the screen', () {
    vmTest('releases the sound, the clock and the awake screen', (
      WidgetTester tester,
    ) async {
      await start(tester);

      Get.delete<MeditationPlayerViewModel>();
      await tester.pump();

      expect(voice.disposed, 1);
      expect(voice.isSpeaking, isFalse);
      expect(keepAwake.enabled, isFalse);
      await seconds(tester, 5); // would throw if the timer were still running
    });
  });
}

/// The longest the player waits for the voice (see the engine).
class MeditationPlayerEngineHoldLimit {
  static const int seconds = 20;
}
