import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/Models/meditation_models.dart';
import 'package:mindmate/Models/meditation_player_engine.dart';

/// Three steps of 10, 20 and 30 seconds: 60 seconds in all.
MeditationPlayerEngine _engine() {
  return MeditationPlayerEngine(const <MeditationStep>[
    MeditationStep(phase: 'settle', seconds: 10, text: 'one'),
    MeditationStep(phase: 'practice', seconds: 20, text: 'two'),
    MeditationStep(phase: 'close', seconds: 30, text: 'three'),
  ]);
}

PlayerTick _tickTimes(
  MeditationPlayerEngine engine,
  int times, {
  bool holdForSpeech = false,
}) {
  PlayerTick last = PlayerTick.none;
  for (int i = 0; i < times; i += 1) {
    last = engine.tick(holdForSpeech: holdForSpeech);
  }
  return last;
}

void main() {
  group('Start', () {
    test('begins on step 1 with the whole length left, not playing', () {
      final MeditationPlayerEngine engine = _engine();
      expect(engine.stepIndex, 0);
      expect(engine.stepCount, 3);
      expect(engine.totalSeconds, 60);
      expect(engine.secondsLeft, 60);
      expect(engine.stepProgress, 0);
      expect(engine.isPlaying, isFalse);
      expect(engine.isEnded, isFalse);
    });

    test('does nothing until it is played', () {
      final MeditationPlayerEngine engine = _engine();
      expect(engine.tick(), PlayerTick.none);
      expect(engine.secondsLeft, 60);
      expect(engine.secondsPractised, 0);
    });

    test('needs at least one step', () {
      expect(
        () => MeditationPlayerEngine(const <MeditationStep>[]),
        throwsArgumentError,
      );
    });
  });

  group('Steps and time left', () {
    test('counts down the whole practice, one second a tick', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 4);
      expect(engine.secondsLeft, 56);
      expect(engine.secondsIntoStep, 4);
      expect(engine.stepProgress, closeTo(0.4, 1e-9));
      expect(engine.secondsPractised, 4);
    });

    test('moves to the next step exactly when a step ends', () {
      final MeditationPlayerEngine engine = _engine()..play();
      expect(_tickTimes(engine, 9), PlayerTick.none);
      expect(engine.stepIndex, 0);

      expect(engine.tick(), PlayerTick.stepChanged); // 10th second
      expect(engine.stepIndex, 1);
      expect(engine.secondsIntoStep, 0);
      expect(engine.secondsLeft, 50);
    });

    test('finishes after the last step and reports completed', () {
      final MeditationPlayerEngine engine = _engine()..play();
      expect(_tickTimes(engine, 59), isNot(PlayerTick.finished));
      expect(engine.isEnded, isFalse);

      expect(engine.tick(), PlayerTick.finished); // 60th second
      expect(engine.isFinished, isTrue);
      expect(engine.completed, isTrue);
      expect(engine.isPlaying, isFalse);
      expect(engine.secondsLeft, 0);
      expect(engine.secondsPractised, 60);
      expect(engine.stepProgress, 1);

      expect(engine.tick(), PlayerTick.none);
      expect(engine.secondsPractised, 60);
    });

    test('plays a real practice in exactly its length', () {
      final MeditationContent content = MeditationContent.fromJson(
        File('assets/meditation/meditation_sessions.json').readAsStringSync(),
      );
      for (final MeditationSession session in content.sessions) {
        final MeditationPlayerEngine engine = MeditationPlayerEngine(
          session.steps,
        )..play();
        int ticks = 0;
        int stepsSeen = 1;
        while (!engine.isEnded) {
          final PlayerTick result = engine.tick();
          ticks += 1;
          if (result == PlayerTick.stepChanged) {
            stepsSeen += 1;
          }
          expect(ticks, lessThanOrEqualTo(session.totalSeconds));
        }
        expect(ticks, session.totalSeconds, reason: session.id);
        expect(stepsSeen, session.steps.length, reason: session.id);
        expect(engine.completed, isTrue, reason: session.id);
      }
    });
  });

  group('Pause', () {
    test('stops the clock and resumes on the same step', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 14); // 4 seconds into step 2

      engine.pause();
      expect(engine.isPlaying, isFalse);
      _tickTimes(engine, 30);
      expect(engine.stepIndex, 1);
      expect(engine.secondsIntoStep, 4);
      expect(engine.secondsLeft, 46);
      expect(engine.secondsPractised, 14);

      engine.play();
      _tickTimes(engine, 6);
      expect(engine.stepIndex, 1);
      expect(engine.secondsIntoStep, 10);
      expect(engine.secondsPractised, 20);
    });
  });

  group('Next and previous', () {
    test('next jumps to the start of the next step and fixes the time', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 4);

      expect(engine.next(), isTrue);
      expect(engine.stepIndex, 1);
      expect(engine.secondsIntoStep, 0);
      expect(engine.secondsLeft, 50);

      expect(engine.next(), isTrue);
      expect(engine.stepIndex, 2);
      expect(engine.secondsLeft, 30);
    });

    test('next does nothing on the last step', () {
      final MeditationPlayerEngine engine = _engine()..play();
      engine.next();
      engine.next();
      _tickTimes(engine, 5);

      expect(engine.isLastStep, isTrue);
      expect(engine.next(), isFalse);
      expect(engine.stepIndex, 2);
      expect(engine.secondsIntoStep, 5);
    });

    test('previous jumps to the start of the previous step', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 15); // 5 seconds into step 2
      expect(engine.stepIndex, 1);

      expect(engine.previous(), isTrue);
      expect(engine.stepIndex, 0);
      expect(engine.secondsIntoStep, 0);
      expect(engine.secondsLeft, 60);
    });

    test('previous on the first step starts it again', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 6);

      expect(engine.previous(), isTrue);
      expect(engine.stepIndex, 0);
      expect(engine.secondsIntoStep, 0);
      expect(engine.secondsLeft, 60);
    });

    test('jumping does not change the time practised', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 7);
      engine.next();
      engine.previous();
      engine.next();
      expect(engine.secondsPractised, 7);
    });

    test('jumping works while paused and stays paused', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 3);
      engine.pause();

      engine.next();
      expect(engine.stepIndex, 1);
      expect(engine.isPlaying, isFalse);
      expect(engine.secondsLeft, 50);
    });
  });

  group('Ending early', () {
    test('is not completed and keeps the time practised', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 25);

      engine.endEarly();
      expect(engine.isEnded, isTrue);
      expect(engine.completed, isFalse);
      expect(engine.isFinished, isFalse);
      expect(engine.isPlaying, isFalse);
      expect(engine.secondsPractised, 25);
    });

    test('stops the clock and cannot be played again', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 5);
      engine.endEarly();

      expect(engine.tick(), PlayerTick.none);
      engine.play();
      expect(engine.isPlaying, isFalse);
      expect(engine.next(), isFalse);
      expect(engine.secondsPractised, 5);
    });

    test('does not undo a finished practice', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 60);
      engine.endEarly();
      expect(engine.completed, isTrue);
    });

    test('excludes the time spent paused', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 8);
      engine.pause();
      _tickTimes(engine, 100);
      engine.play();
      _tickTimes(engine, 2);
      engine.endEarly();
      expect(engine.secondsPractised, 10);
    });
  });

  group('Waiting for the voice', () {
    test('stays on the step when the voice is still speaking', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 9);

      expect(engine.tick(holdForSpeech: true), PlayerTick.none); // 10th
      expect(engine.isStepTimeUp, isTrue);
      expect(engine.stepIndex, 0);
      expect(engine.secondsLeft, 50);

      expect(_tickTimes(engine, 3, holdForSpeech: true), PlayerTick.none);
      expect(engine.stepIndex, 0);
    });

    test('moves on at the next tick once the voice is done', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 10, holdForSpeech: true);
      expect(engine.stepIndex, 0);

      expect(engine.tick(), PlayerTick.stepChanged);
      expect(engine.stepIndex, 1);
      expect(engine.secondsIntoStep, 0);
    });

    test('moves on straight away when the voice finishes', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 12, holdForSpeech: true);
      expect(engine.isStepTimeUp, isTrue);

      expect(engine.advanceIfStepTimeUp(), PlayerTick.stepChanged);
      expect(engine.stepIndex, 1);
      expect(engine.isStepTimeUp, isFalse);
    });

    test('does not move on early if the step is still running', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 4);
      expect(engine.advanceIfStepTimeUp(), PlayerTick.none);
      expect(engine.stepIndex, 0);
    });

    test('never waits for more than the limit', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 10, holdForSpeech: true); // time is up now

      final int limit = MeditationPlayerEngine.maxSpeechHoldSeconds;
      expect(
        _tickTimes(engine, limit - 1, holdForSpeech: true),
        PlayerTick.none,
      );
      expect(engine.stepIndex, 0);

      expect(engine.tick(holdForSpeech: true), PlayerTick.stepChanged);
      expect(engine.stepIndex, 1);
    });

    test('counts the waiting seconds as time practised', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 13, holdForSpeech: true);
      expect(engine.secondsPractised, 13);
    });

    test('holds the end of the last step too, then finishes', () {
      final MeditationPlayerEngine engine = _engine()..play();
      engine.next();
      engine.next();
      _tickTimes(engine, 30, holdForSpeech: true);
      expect(engine.isEnded, isFalse);
      expect(engine.isStepTimeUp, isTrue);

      expect(engine.advanceIfStepTimeUp(), PlayerTick.finished);
      expect(engine.completed, isTrue);
    });

    test('a jump clears the wait', () {
      final MeditationPlayerEngine engine = _engine()..play();
      _tickTimes(engine, 10, holdForSpeech: true);
      engine.next();
      expect(engine.isStepTimeUp, isFalse);
      expect(_tickTimes(engine, 5, holdForSpeech: true), PlayerTick.none);
      expect(engine.stepIndex, 1);
      expect(engine.secondsIntoStep, 5);
    });
  });
}
