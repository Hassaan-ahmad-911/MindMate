import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/Models/mood_catalog.dart';
import 'package:mindmate/Models/mood_model.dart';
import 'package:mindmate/Models/mood_stats.dart';

MoodModel _entry(
  String mood,
  DateTime date, {
  List<String> factors = const <String>[],
}) {
  return MoodModel(
    mood: mood,
    valence: MoodCatalog.valenceFor(mood),
    intensity: 'Mild',
    factors: factors,
    note: '',
    date: date,
  );
}

void main() {
  final DateTime now = DateTime(2026, 10, 6, 20);

  group('Day score', () {
    test('is the average valence of the day', () {
      final Map<DateTime, double> scores = MoodStats.dayScores(<MoodModel>[
        _entry('Happy', DateTime(2026, 10, 6, 8)), // +2
        _entry('Stressed', DateTime(2026, 10, 6, 21)), // -1
        _entry('Sad', DateTime(2026, 10, 5, 9)), // -2
      ]);
      expect(scores[DateTime(2026, 10, 6)], 0.5);
      expect(scores[DateTime(2026, 10, 5)], -2);
      expect(scores, hasLength(2));
    });

    test('ignores intensity', () {
      final MoodModel strongHappy = MoodModel(
        mood: 'Happy',
        valence: 2,
        intensity: 'Strong',
        note: '',
        date: now,
      );
      final MoodModel strongAngry = MoodModel(
        mood: 'Angry',
        valence: -2,
        intensity: 'Strong',
        note: '',
        date: now,
      );
      expect(MoodStats.averageValence(<MoodModel>[strongHappy]), 2);
      expect(MoodStats.averageValence(<MoodModel>[strongAngry]), -2);
    });
  });

  group('Day group', () {
    test('above 0.5 is good, below -0.5 is hard, otherwise in between', () {
      expect(MoodStats.groupForDayScore(0.51), MoodGroup.good);
      expect(MoodStats.groupForDayScore(0.5), MoodGroup.between);
      expect(MoodStats.groupForDayScore(0), MoodGroup.between);
      expect(MoodStats.groupForDayScore(-0.5), MoodGroup.between);
      expect(MoodStats.groupForDayScore(-0.51), MoodGroup.hard);
    });
  });

  group('Good day', () {
    test('is a day score above 0', () {
      expect(MoodStats.isGoodDay(0.1), isTrue);
      expect(MoodStats.isGoodDay(0), isFalse);
      expect(MoodStats.isGoodDay(-1), isFalse);
    });
  });

  group('Streak', () {
    test('counts days in a row ending today', () {
      final List<DateTime> dates = <DateTime>[
        DateTime(2026, 10, 6, 8),
        DateTime(2026, 10, 6, 21),
        DateTime(2026, 10, 5, 9),
        DateTime(2026, 10, 4, 9),
        DateTime(2026, 10, 2, 9), // gap on the 3rd
      ];
      expect(MoodStats.streak(dates, now: now), 3);
    });

    test('ends yesterday when nothing is logged today yet', () {
      final List<DateTime> dates = <DateTime>[
        DateTime(2026, 10, 5, 9),
        DateTime(2026, 10, 4, 9),
      ];
      expect(MoodStats.streak(dates, now: now), 2);
    });

    test('is 0 when the last entry is older than yesterday', () {
      expect(MoodStats.streak(<DateTime>[DateTime(2026, 10, 4)], now: now), 0);
      expect(MoodStats.streak(<DateTime>[], now: now), 0);
    });

    test('crosses month boundaries', () {
      final List<DateTime> dates = <DateTime>[
        DateTime(2026, 10, 1),
        DateTime(2026, 9, 30),
        DateTime(2026, 9, 29),
      ];
      expect(MoodStats.streak(dates, now: DateTime(2026, 10, 1, 12)), 3);
    });
  });

  group('Home score', () {
    test('maps -2..2 onto 0..10', () {
      expect(MoodStats.scoreOutOfTen(-2), 0);
      expect(MoodStats.scoreOutOfTen(0), 5);
      expect(MoodStats.scoreOutOfTen(1), 7.5);
      expect(MoodStats.scoreOutOfTen(2), 10);
    });
  });

  group('Pattern sentence', () {
    final DateTime day = DateTime(2026, 10, 5);

    test('shows when a factor is in 2+ hard entries and 60%+ of them', () {
      final String? sentence = MoodStats.patternSentence(<MoodModel>[
        _entry('Stressed', day, factors: <String>['Night shift', 'Workload']),
        _entry('Anxious', day, factors: <String>['Night shift']),
        _entry('Sad', day, factors: <String>['Family']),
        _entry('Happy', day, factors: <String>['Night shift']),
      ], periodPhrase: 'this week');
      expect(
        sentence,
        '2 of your 3 harder entries this week mentioned night shift.',
      );
    });

    test('is hidden below 60% of hard entries', () {
      final String? sentence = MoodStats.patternSentence(<MoodModel>[
        _entry('Stressed', day, factors: <String>['Workload']),
        _entry('Anxious', day, factors: <String>['Workload']),
        _entry('Sad', day),
        _entry('Angry', day),
      ], periodPhrase: 'this week');
      expect(sentence, isNull); // 2 of 4 = 50%
    });

    test('is hidden when the factor appears in only 1 hard entry', () {
      final String? sentence = MoodStats.patternSentence(<MoodModel>[
        _entry('Stressed', day, factors: <String>['Workload']),
        _entry('Happy', day, factors: <String>['Workload']),
      ], periodPhrase: 'this week');
      expect(sentence, isNull);
    });

    test('ignores factors on good and in-between entries', () {
      final String? sentence = MoodStats.patternSentence(<MoodModel>[
        _entry('Tired', day, factors: <String>['Sleep']),
        _entry('Okay', day, factors: <String>['Sleep']),
        _entry('Calm', day, factors: <String>['Sleep']),
      ], periodPhrase: 'this month');
      expect(sentence, isNull);
    });
  });

  group('Top moods and factors', () {
    final DateTime day = DateTime(2026, 10, 5);

    test('sorts by count, ties in catalog order', () {
      final List<MapEntry<String, int>> moods = MoodStats.topMoods(<MoodModel>[
        _entry('Tired', day),
        _entry('Calm', day),
        _entry('Calm', day),
        _entry('Happy', day),
      ]);
      expect(moods.map((MapEntry<String, int> e) => e.key).toList(), <String>[
        'Calm',
        'Happy',
        'Tired',
      ]);
      expect(moods.first.value, 2);
    });

    test('limits factors to the top 4', () {
      final List<MapEntry<String, int>> factors = MoodStats.topFactors(
        <MoodModel>[
          _entry(
            'Calm',
            day,
            factors: <String>[
              'Workload',
              'Night shift',
              'Patients',
              'Team',
              'Sleep',
            ],
          ),
        ],
      );
      expect(factors, hasLength(4));
    });
  });

  group('Daily points', () {
    test('has one point per day with null for empty days', () {
      final List<MoodDayPoint> points = MoodStats.dailyPoints(
        <MoodModel>[
          _entry('Calm', DateTime(2026, 10, 6, 8)),
          _entry('Sad', DateTime(2026, 10, 4, 8)),
        ],
        lastDay: now,
        days: 3,
      );
      expect(points.map((MoodDayPoint p) => p.score).toList(), <double?>[
        -2,
        null,
        1,
      ]);
      expect(points.last.latestMood, 'Calm');
    });
  });
}
