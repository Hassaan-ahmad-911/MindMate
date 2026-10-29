import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/Models/breathing_sessions.dart';
import 'package:mindmate/Models/meditation_models.dart';

MeditationContent _loadFile() {
  final String source = File(
    'assets/meditation/meditation_sessions.json',
  ).readAsStringSync();
  return MeditationContent.fromJson(source);
}

void main() {
  group('Content file', () {
    final MeditationContent content = _loadFile();

    test('has 7 groups and 12 practices', () {
      expect(content.groups, hasLength(7));
      expect(content.sessions, hasLength(12));
    });

    test('every practice has steps that add up to its minutes', () {
      for (final MeditationSession session in content.sessions) {
        expect(
          session.totalSeconds,
          session.minutes * 60,
          reason: '${session.id}: steps add up to ${session.totalSeconds}s',
        );
        expect(session.lengthMinutes, session.minutes, reason: session.id);
      }
    });

    test('the length shown comes from the steps, not the minutes field', () {
      const MeditationSession session = MeditationSession(
        id: 'x',
        title: 'X',
        groupId: 'g',
        technique: '',
        basedOn: '',
        minutes: 99,
        posture: '',
        goodFor: '',
        about: '',
        safetyNote: '',
        steps: <MeditationStep>[
          MeditationStep(phase: 'practice', seconds: 90, text: 'a'),
          MeditationStep(phase: 'practice', seconds: 90, text: 'b'),
        ],
      );
      expect(session.totalSeconds, 180);
      expect(session.lengthLabel, '3 min');
    });

    test('ids are unique and every practice belongs to a known group', () {
      final Set<String> groupIds = content.groups
          .map((MeditationGroup group) => group.id)
          .toSet();
      expect(groupIds, hasLength(content.groups.length));

      final Set<String> sessionIds = content.sessions
          .map((MeditationSession session) => session.id)
          .toSet();
      expect(sessionIds, hasLength(content.sessions.length));

      for (final MeditationSession session in content.sessions) {
        expect(groupIds, contains(session.groupId), reason: session.id);
      }
    });

    test('every step has text, a positive length and a known phase', () {
      const Set<String> phases = <String>{'settle', 'practice', 'close'};
      for (final MeditationSession session in content.sessions) {
        for (final MeditationStep step in session.steps) {
          expect(step.text.trim(), isNotEmpty, reason: session.id);
          expect(step.seconds, greaterThan(0), reason: session.id);
          expect(phases, contains(step.phase), reason: session.id);
        }
      }
    });

    test('keeps the wording of a practice exactly', () {
      final MeditationSession pause = content.sessions.firstWhere(
        (MeditationSession session) => session.id == 'three_step_pause',
      );
      expect(pause.title, 'The 3-step pause');
      expect(pause.technique, 'Breathing space');
      expect(pause.steps, hasLength(6));
      expect(
        pause.steps[3].text,
        'Step two. Bring your attention to your breathing. Follow each '
        'breath in, and each breath out, all the way through.',
      );
      expect(pause.safetyNote, isEmpty);
    });

    test('rejects a file that is not valid', () {
      expect(
        () => MeditationContent.fromJson('not json'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => MeditationContent.fromJson('{"groups": [], "sessions": 1}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => MeditationContent.fromJson(
          '{"groups": [], "sessions": [{"id": "a", "title": "A", '
          '"group": "g", "steps": []}]}',
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Breathing practices', () {
    test('are the 10 original practices, one timed step each', () {
      expect(BreathingLibrary.sessions, hasLength(10));
      expect(
        BreathingLibrary.sessions
            .map((MeditationSession session) => session.title)
            .toList(),
        <String>[
          'Gentle Reset',
          'Quiet Night',
          'Let It Ease',
          'Focused Flow',
          'Safe Grounding',
          'Soft Release',
          'Restful Drift',
          'Calm the Pressure',
          'Clear Attention',
          'Soft Breathing',
        ],
      );
      expect(
        BreathingLibrary.sessions
            .map((MeditationSession session) => session.minutes)
            .toList(),
        <int>[5, 10, 7, 8, 6, 12, 15, 9, 10, 8],
      );
      for (final MeditationSession session in BreathingLibrary.sessions) {
        expect(session.isBreathing, isTrue, reason: session.id);
        expect(session.hasVoice, isFalse, reason: session.id);
        expect(session.groupId, MeditationGroup.breathingId);
        expect(session.steps, hasLength(1), reason: session.id);
        expect(session.totalSeconds, session.minutes * 60);
      }
    });

    test('have unique ids that do not clash with the content file', () {
      final MeditationContent content = _loadFile();
      final List<String> ids = <String>[
        ...content.sessions.map((MeditationSession s) => s.id),
        ...BreathingLibrary.sessions.map((MeditationSession s) => s.id),
      ];
      expect(ids.toSet(), hasLength(ids.length));
    });
  });
}
