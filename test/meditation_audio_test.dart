import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/Data/repositories/meditation_repository.dart';
import 'package:mindmate/Data/repositories/settings_repository.dart';
import 'package:mindmate/Models/meditation_audio.dart';
import 'package:mindmate/Models/meditation_models.dart';
import 'package:mindmate/Models/meditation_player_engine.dart';
import 'package:mindmate/services/meditation_voice_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/meditation_fakes.dart';
import 'helpers/settings_fakes.dart';

/// A log service that knows who is signed in, for per-user preferences.
class UserLogService extends FakeLogService {
  String? uid = 'user-1';

  @override
  String? currentUidOrNull() => uid;
}

const List<VoiceClip> clips = <VoiceClip>[
  VoiceClip(index: 0, file: 'x_00.mp3', text: 'Settle in.', durationMs: 4000),
  VoiceClip(index: 1, file: 'x_01.mp3', text: 'Breathe.', durationMs: 31000),
];

void main() {
  group('Recorded clip or backup voice', () {
    test('a matching index and text uses the clip', () {
      expect(MeditationAudioRules.clipFor(clips, 0, 'Settle in.'), clips[0]);
    });

    test('a missing entry uses the backup voice', () {
      expect(MeditationAudioRules.clipFor(clips, 2, 'Anything.'), isNull);
    });

    test('changed text never plays the stale clip', () {
      expect(MeditationAudioRules.clipFor(clips, 0, 'Settle in now.'), isNull);
      expect(MeditationAudioRules.clipFor(clips, 0, 'settle in.'), isNull);
    });

    test('every real clip matches its step (indexes count from 0)', () {
      final VoiceManifest manifest = VoiceManifest.fromJson(
        File('assets/meditation/voice/voice_manifest.json').readAsStringSync(),
      );
      final MeditationContent content = MeditationContent.fromJson(
        fileContentLoader(),
      );
      int matched = 0;
      for (final MeditationSession s in content.sessions) {
        for (int i = 0; i < s.steps.length; i += 1) {
          final VoiceClip? clip = MeditationAudioRules.clipFor(
            manifest.clipsFor(s.id),
            i,
            s.steps[i].text,
          );
          expect(clip, isNotNull, reason: '${s.id} step $i');
          expect(File(clip!.assetPath).existsSync(), isTrue);
          matched += 1;
        }
      }
      expect(manifest.sessions, hasLength(12));
      expect(matched, 132);
    });
  });

  group('Step length', () {
    test('a step keeps its time when the clip fits', () {
      expect(MeditationAudioRules.stepSeconds(20, clips[0]), 20);
      expect(MeditationAudioRules.stepSeconds(20, null), 20);
    });

    test('a long clip lengthens the step to clip + 1.5 s', () {
      // 31 s + 1.5 s = 32.5 s, rounded up.
      expect(MeditationAudioRules.stepSeconds(25, clips[1]), 33);
    });

    test('the engine counts down the longer length', () {
      const List<MeditationStep> steps = <MeditationStep>[
        MeditationStep(phase: 'settle', seconds: 3, text: 'a'),
        MeditationStep(phase: 'close', seconds: 3, text: 'b'),
      ];
      final MeditationPlayerEngine engine = MeditationPlayerEngine(
        steps,
        stepSeconds: <int>[5, 3],
      );
      expect(engine.totalSeconds, 8);
      expect(engine.secondsLeft, 8);
      engine.play();
      for (int i = 0; i < 4; i += 1) {
        expect(engine.tick(), PlayerTick.none);
      }
      expect(engine.stepProgress, closeTo(0.8, 0.001));
      expect(engine.tick(), PlayerTick.stepChanged);
    });
  });

  group('Backup voice', () {
    test('splits a step into sentences', () {
      expect(
        MeditationAudioRules.sentences(
          'Step one. Notice what is here! What thoughts are passing through? '
          'Just name them',
        ),
        <String>[
          'Step one.',
          'Notice what is here!',
          'What thoughts are passing through?',
          'Just name them',
        ],
      );
      expect(MeditationAudioRules.sentences('  '), isEmpty);
      expect(MeditationAudioRules.sentences('Wait...'), <String>['Wait...']);
    });

    test('picks a high-quality English voice, en-GB first', () {
      expect(
        FlutterTtsVoiceService.pickVoice(<Map<String, String>>[
          <String, String>{'name': 'en-us-x-sfg-network', 'locale': 'en-US'},
          <String, String>{'name': 'en-gb-x-gbd-network', 'locale': 'en-GB'},
          <String, String>{'name': 'fr-fr-network', 'locale': 'fr-FR'},
        ])?['locale'],
        'en-GB',
      );
      expect(
        FlutterTtsVoiceService.pickVoice(<Map<String, String>>[
          <String, String>{'name': 'Samantha (Enhanced)', 'locale': 'en_US'},
        ])?['name'],
        'Samantha (Enhanced)',
      );
      expect(
        FlutterTtsVoiceService.pickVoice(<Map<String, String>>[
          <String, String>{'name': 'en-us-x-local', 'locale': 'en-US'},
        ]),
        isNull,
        reason: 'keep the default voice',
      );
    });
  });

  group('Background sound', () {
    test('ducking lowers to 60% while the voice speaks', () {
      expect(
        MeditationAudioRules.ambientTarget(0.25, voiceSpeaking: true),
        closeTo(0.15, 0.0001),
      );
      expect(
        MeditationAudioRules.ambientTarget(0.25, voiceSpeaking: false),
        0.25,
      );
      expect(MeditationAudioRules.duckDown, const Duration(milliseconds: 400));
      expect(MeditationAudioRules.duckUp, const Duration(milliseconds: 800));
      expect(MeditationAudioRules.clampVolume(0.9), 0.6);
    });

    test(
      'the choice and volume are kept in the settings of each user',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final FakeSettingsService service = FakeSettingsService(uid: 'user-1');
        final MeditationRepository repo = MeditationRepository(
          fileContentService(),
          UserLogService(),
          settings: SettingsRepository(service),
        );

        expect(await repo.getAmbient(), AmbientChoice.off, reason: 'default');
        expect(await repo.getAmbientVolume(), 0.25);

        await repo.setAmbient(AmbientChoice.softRain);
        await repo.setAmbientVolume(0.4);
        expect(await repo.getAmbient(), AmbientChoice.softRain);
        expect(await repo.getAmbientVolume(), closeTo(0.4, 0.0001));
        expect(
          service.updates.map((MapEntry<String, Object?> e) => e.key),
          containsAll(<String>['meditationSound', 'meditationSoundVolume']),
        );

        service.uid = 'user-2';
        expect(await repo.getAmbient(), AmbientChoice.off);
        expect(await repo.getAmbientVolume(), 0.25);

        service.uid = 'user-1';
        expect(await repo.getAmbient(), AmbientChoice.softRain);
      },
    );
  });
}
