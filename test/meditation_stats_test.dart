import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/Models/breathing_sessions.dart';
import 'package:mindmate/Models/meditation_log_entry.dart';
import 'package:mindmate/Models/meditation_models.dart';
import 'package:mindmate/Models/meditation_stats.dart';
import 'package:mindmate/Models/meditation_suggester.dart';
import 'package:mindmate/Models/mood_catalog.dart';
import 'package:mindmate/Models/mood_model.dart';

MeditationLogEntry _log(
  DateTime endedAt, {
  int seconds = 180,
  bool completed = true,
  String sessionId = 'arriving',
}) {
  return MeditationLogEntry(
    id: 'log-${endedAt.microsecondsSinceEpoch}-$sessionId',
    sessionId: sessionId,
    title: sessionId,
    startedAt: endedAt.subtract(Duration(seconds: seconds)),
    endedAt: endedAt,
    secondsPractised: seconds,
    completed: completed,
  );
}

MeditationSession _session(String id, {String group = 'anytime'}) {
  return MeditationSession(
    id: id,
    title: id,
    groupId: group,
    technique: '',
    basedOn: '',
    minutes: 1,
    posture: '',
    goodFor: '',
    about: '',
    safetyNote: '',
    steps: const <MeditationStep>[
      MeditationStep(phase: 'practice', seconds: 60, text: 'x'),
    ],
  );
}

MoodModel _mood(String name, {String intensity = 'Moderate'}) {
  return MoodModel(
    mood: name,
    valence: MoodCatalog.valenceFor(name),
    intensity: intensity,
    note: '',
    date: DateTime(2026, 10, 7, 9),
  );
}

void main() {
  final DateTime now = DateTime(2026, 10, 7, 14, 30);

  group('Minutes this week', () {
    test('adds up the seconds and rounds down to whole minutes', () {
      final List<MeditationLogEntry> logs = <MeditationLogEntry>[
        _log(DateTime(2026, 10, 7, 9), seconds: 100),
        _log(DateTime(2026, 10, 6, 9), seconds: 100),
        _log(DateTime(2026, 10, 5, 9), seconds: 100),
      ];
      // 300 seconds in all = 5 minutes.
      expect(MeditationStats.minutesThisWeek(logs, now: now), 5);

      logs.add(_log(DateTime(2026, 10, 4, 9), seconds: 59));
      // 359 seconds = 5 minutes, not 6.
      expect(MeditationStats.minutesThisWeek(logs, now: now), 5);
    });

    test('counts only the last 7 days', () {
      final List<MeditationLogEntry> logs = <MeditationLogEntry>[
        _log(DateTime(2026, 10, 1, 0, 0, 1), seconds: 120), // 6 days ago
        _log(DateTime(2026, 9, 30, 23, 59), seconds: 600), // 7 days ago
        _log(DateTime(2026, 9, 1, 9), seconds: 600),
      ];
      expect(MeditationStats.minutesThisWeek(logs, now: now), 2);
    });

    test('includes practices that were ended early', () {
      final List<MeditationLogEntry> logs = <MeditationLogEntry>[
        _log(DateTime(2026, 10, 7, 9), seconds: 90, completed: false),
      ];
      expect(MeditationStats.minutesThisWeek(logs, now: now), 1);
    });

    test('is 0 with no practices', () {
      expect(
        MeditationStats.minutesThisWeek(<MeditationLogEntry>[], now: now),
        0,
      );
    });
  });

  group('Sessions this week', () {
    test('counts every practice in the last 7 days', () {
      final List<MeditationLogEntry> logs = <MeditationLogEntry>[
        _log(DateTime(2026, 10, 7, 9)),
        _log(DateTime(2026, 10, 7, 12), completed: false),
        _log(DateTime(2026, 10, 3, 9)),
        _log(DateTime(2026, 9, 29, 9)),
      ];
      expect(MeditationStats.sessionsThisWeek(logs, now: now), 3);
    });
  });

  group('Streak', () {
    test('counts days in a row ending today', () {
      final List<MeditationLogEntry> logs = <MeditationLogEntry>[
        _log(DateTime(2026, 10, 7, 8)),
        _log(DateTime(2026, 10, 7, 20)),
        _log(DateTime(2026, 10, 6, 8)),
        _log(DateTime(2026, 10, 5, 8)),
        _log(DateTime(2026, 10, 3, 8)), // gap on the 4th
      ];
      expect(MeditationStats.streak(logs, now: now), 3);
    });

    test('ends yesterday when nothing is done yet today', () {
      final List<MeditationLogEntry> logs = <MeditationLogEntry>[
        _log(DateTime(2026, 10, 6, 8)),
        _log(DateTime(2026, 10, 5, 8)),
      ];
      expect(MeditationStats.streak(logs, now: now), 2);
    });

    test('is 0 if the last practice was before yesterday', () {
      final List<MeditationLogEntry> logs = <MeditationLogEntry>[
        _log(DateTime(2026, 10, 5, 8)),
      ];
      expect(MeditationStats.streak(logs, now: now), 0);
      expect(MeditationStats.streak(<MeditationLogEntry>[], now: now), 0);
    });

    test('counts a practice that was ended early', () {
      final List<MeditationLogEntry> logs = <MeditationLogEntry>[
        _log(DateTime(2026, 10, 7, 8), completed: false),
      ];
      expect(MeditationStats.streak(logs, now: now), 1);
    });
  });

  group('Finished counts', () {
    test('counts only practices that were finished', () {
      final Map<String, int> counts =
          MeditationStats.completedCounts(<MeditationLogEntry>[
            _log(DateTime(2026, 10, 7), sessionId: 'a'),
            _log(DateTime(2026, 10, 6), sessionId: 'a'),
            _log(DateTime(2026, 10, 5), sessionId: 'a', completed: false),
            _log(DateTime(2026, 10, 4), sessionId: 'b', completed: false),
          ]);
      expect(counts, <String, int>{'a': 2});
    });
  });

  group('Suggested for you', () {
    final List<MeditationSession> sessions = <MeditationSession>[
      _session('arriving', group: 'before_shift'),
      _session(MeditationSuggester.threeStepPauseId, group: 'on_shift'),
      _session(MeditationSuggester.sensesId, group: 'overwhelmed'),
      _session(MeditationSuggester.selfCompassionId, group: 'after_event'),
      _session(MeditationSuggester.sleepWindDownId, group: 'sleep'),
      _session('calm_place'),
      ...BreathingLibrary.sessions,
    ];
    final DateTime day = DateTime(2026, 10, 7, 14);

    MeditationSuggestion? suggest({
      MoodModel? mood,
      DateTime? at,
      Map<String, int> counts = const <String, int>{},
      List<MeditationSession>? from,
    }) {
      return MeditationSuggester.suggest(
        sessions: from ?? sessions,
        now: at ?? day,
        latestMoodToday: mood,
        completedCounts: counts,
      );
    }

    test('rule 1: a hard mood at Strong gives the self-compassion break', () {
      final MeditationSuggestion? result = suggest(
        mood: _mood('Stressed', intensity: 'Strong'),
      );
      expect(result?.session.id, MeditationSuggester.selfCompassionId);
      expect(result?.reason, 'You logged Stressed today');
    });

    test('rule 1 applies to every hard mood', () {
      for (final MoodDefinition mood in MoodCatalog.inGroup(MoodGroup.hard)) {
        expect(
          suggest(mood: _mood(mood.name, intensity: 'Strong'))?.session.id,
          MeditationSuggester.selfCompassionId,
          reason: mood.name,
        );
      }
    });

    test('rule 2: a hard mood at Mild or Moderate gives 5-4-3-2-1', () {
      for (final String intensity in <String>['Mild', 'Moderate']) {
        final MeditationSuggestion? result = suggest(
          mood: _mood('Anxious', intensity: intensity),
        );
        expect(result?.session.id, MeditationSuggester.sensesId);
        expect(result?.reason, 'You logged Anxious today');
      }
    });

    test('rule 3: Tired or Restless gives the 3-step pause', () {
      for (final String name in <String>['Tired', 'Restless']) {
        final MeditationSuggestion? result = suggest(
          mood: _mood(name, intensity: 'Strong'),
        );
        expect(result?.session.id, MeditationSuggester.threeStepPauseId);
        expect(result?.reason, 'You logged $name today');
      }
    });

    test('rule 4: between 21:00 and 05:00 gives the sleep wind-down', () {
      for (final DateTime at in <DateTime>[
        DateTime(2026, 10, 7, 21, 0),
        DateTime(2026, 10, 7, 23, 59),
        DateTime(2026, 10, 7, 0, 0),
        DateTime(2026, 10, 7, 4, 59),
      ]) {
        final MeditationSuggestion? result = suggest(at: at);
        expect(
          result?.session.id,
          MeditationSuggester.sleepWindDownId,
          reason: '$at',
        );
        expect(result?.reason, 'Winding down');
      }
    });

    test('rule 4 does not apply outside those hours', () {
      for (final DateTime at in <DateTime>[
        DateTime(2026, 10, 7, 5, 0),
        DateTime(2026, 10, 7, 12, 0),
        DateTime(2026, 10, 7, 20, 59),
      ]) {
        expect(
          suggest(at: at)?.session.id,
          isNot(MeditationSuggester.sleepWindDownId),
          reason: '$at',
        );
      }
    });

    test('the mood rules come before the night rule', () {
      final DateTime night = DateTime(2026, 10, 7, 23, 0);
      expect(
        suggest(
          mood: _mood('Sad', intensity: 'Strong'),
          at: night,
        )?.session.id,
        MeditationSuggester.selfCompassionId,
      );
      expect(
        suggest(mood: _mood('Tired'), at: night)?.session.id,
        MeditationSuggester.threeStepPauseId,
      );
    });

    test('a good or in-between mood falls through to the next rules', () {
      final DateTime night = DateTime(2026, 10, 7, 22, 0);
      expect(
        suggest(mood: _mood('Happy'), at: night)?.session.id,
        MeditationSuggester.sleepWindDownId,
      );
      expect(
        suggest(mood: _mood('Okay'))?.reason,
        MeditationSuggester.somethingNewReason,
      );
    });

    test('rule 5: the practice finished least often', () {
      final MeditationSuggestion? result = suggest(
        counts: <String, int>{
          'arriving': 3,
          MeditationSuggester.threeStepPauseId: 2,
          MeditationSuggester.sensesId: 1,
          MeditationSuggester.selfCompassionId: 4,
          MeditationSuggester.sleepWindDownId: 2,
          // calm_place has never been finished.
        },
      );
      expect(result?.session.id, 'calm_place');
      expect(result?.reason, 'Something new');
    });

    test('rule 5: ties go to the first practice in the file', () {
      expect(suggest()?.session.id, 'arriving');
      expect(
        suggest(counts: <String, int>{'arriving': 1})?.session.id,
        MeditationSuggester.threeStepPauseId,
      );
    });

    test('never suggests a breathing practice', () {
      final MeditationSuggestion? result = suggest(
        counts: <String, int>{
          for (final MeditationSession s in sessions.where(
            (MeditationSession s) => !s.isBreathing,
          ))
            s.id: 5,
        },
      );
      expect(result?.session.isBreathing, isFalse);

      expect(
        suggest(from: BreathingLibrary.sessions),
        isNull,
        reason: 'only breathing practices exist',
      );
    });

    test('skips a rule whose practice is not in the content', () {
      final List<MeditationSession> withoutSenses = sessions
          .where((MeditationSession s) => s.id != MeditationSuggester.sensesId)
          .toList();
      final MeditationSuggestion? result = suggest(
        mood: _mood('Angry'),
        from: withoutSenses,
      );
      expect(result?.reason, MeditationSuggester.somethingNewReason);

      final MeditationSuggestion? strong = suggest(
        mood: _mood('Angry', intensity: 'Strong'),
        from: sessions
            .where(
              (MeditationSession s) =>
                  s.id != MeditationSuggester.selfCompassionId,
            )
            .toList(),
      );
      // Rule 1 is skipped, so rule 2 still applies.
      expect(strong?.session.id, MeditationSuggester.sensesId);
    });
  });
}
