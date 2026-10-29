import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/Models/programme_schedule.dart';

import 'helpers/programme_fakes.dart';

void main() {
  final ProgrammeConfig config = fileProgramme();

  /// Joined on Thursday 1 October 2026 at 9:00.
  final DateTime joined = DateTime(2026, 10, 1, 9);

  List<ScheduleRow> today(
    DateTime now, {
    Map<String, DateTime> lastDone = const <String, DateTime>{},
    DateTime? lastMood,
  }) => ProgrammeSchedule.today(
    config: config,
    joinedAt: joined,
    lastDone: lastDone,
    lastMood: lastMood,
    now: now,
  );

  List<String> labels(List<ScheduleRow> rows) =>
      rows.map((ScheduleRow r) => r.label).toList();

  group('The content file', () {
    test('has the required schedule', () {
      expect(config.moodEveryDays, 1);
      expect(
        <String, int>{
          for (final ProgrammeItem i in config.required)
            i.assessmentId: i.everyDays,
        },
        <String, int>{
          'phq4': 3,
          'who5': 7,
          'phq9': 14,
          'gad7': 14,
          'cbi': 30,
          'pss10': 30,
        },
      );
      expect(config.optional.single.assessmentId, 'workplace');
    });
  });

  group('Due dates', () {
    test('due = the day of the last one + its days, in local dates', () {
      expect(
        ProgrammeSchedule.dueDay(
          id: 'phq4',
          everyDays: 3,
          joinedAt: joined,
          lastDone: DateTime(2026, 10, 5, 23, 50),
        ),
        DateTime(2026, 10, 8),
      );
    });

    test('due today and overdue both show today', () {
      final DateTime now = DateTime(2026, 10, 20, 10);
      final List<ScheduleRow> rows = today(
        now,
        lastDone: <String, DateTime>{
          'phq4': DateTime(2026, 10, 17, 8), // due today
          'who5': DateTime(2026, 10, 2), // overdue
          'phq9': DateTime(2026, 10, 15),
          'gad7': DateTime(2026, 10, 15),
          'cbi': DateTime(2026, 10, 5),
          'pss10': DateTime(2026, 10, 5),
        },
      );
      expect(labels(rows), <String>['Mood', '3-day check', 'Wellbeing']);
      expect(rows.every((ScheduleRow r) => !r.done), isTrue);
    });

    test('a check-in taken early only moves its own date', () {
      final DateTime now = DateTime(2026, 10, 20, 10);
      final List<ScheduleRow> rows = today(
        now,
        lastDone: <String, DateTime>{
          'phq4': DateTime(2026, 10, 19), // taken a day early
          'who5': DateTime(2026, 10, 15),
          'phq9': DateTime(2026, 10, 15),
          'gad7': DateTime(2026, 10, 15),
          'cbi': DateTime(2026, 10, 5),
          'pss10': DateTime(2026, 10, 5),
        },
      );
      expect(labels(rows), <String>['Mood']);
    });

    test('done today shows as done, with Mood', () {
      final DateTime now = DateTime(2026, 10, 20, 18);
      final List<ScheduleRow> rows = today(
        now,
        lastDone: <String, DateTime>{
          'phq4': DateTime(2026, 10, 20, 9),
          'who5': DateTime(2026, 10, 15),
          'phq9': DateTime(2026, 10, 15),
          'gad7': DateTime(2026, 10, 15),
          'cbi': DateTime(2026, 10, 5),
          'pss10': DateTime(2026, 10, 5),
        },
        lastMood: DateTime(2026, 10, 20, 7),
      );
      expect(labels(rows), <String>['Mood', '3-day check']);
      expect(rows.every((ScheduleRow r) => r.done), isTrue);
      expect(
        ProgrammeSchedule.cardLine(rows),
        'All done for today. Thank you.',
      );
      expect(ProgrammeSchedule.bubble(rows), isNull);
    });
  });

  group('Combined rows', () {
    test('PHQ-9 and GAD-7 due together are one row', () {
      final List<ScheduleRow> rows = today(
        DateTime(2026, 10, 2, 12),
        lastDone: <String, DateTime>{
          'phq4': DateTime(2026, 10, 1),
          'who5': DateTime(2026, 10, 1),
        },
      );
      final ScheduleRow pair = rows.firstWhere(
        (ScheduleRow r) => r.label == 'Low mood and worry',
      );
      expect(pair.assessmentIds, <String>['phq9', 'gad7']);
      expect(pair.startId, 'phq9');
    });

    test('once PHQ-9 is done, the pair splits into its own rows', () {
      final List<ScheduleRow> rows = today(
        DateTime(2026, 10, 2, 18),
        lastDone: <String, DateTime>{
          'phq4': DateTime(2026, 10, 1),
          'who5': DateTime(2026, 10, 1),
          'phq9': DateTime(2026, 10, 2, 17),
        },
      );
      expect(labels(rows), <String>['Mood', 'Low mood', 'Worry and anxiety']);
      expect(rows[1].done, isTrue);
      expect(rows[2].done, isFalse);
    });

    test('CBI and PSS-10 due together are "Burnout and stress"', () {
      final List<ScheduleRow> rows = today(
        DateTime(2026, 10, 4, 12),
        lastDone: <String, DateTime>{
          'phq4': DateTime(2026, 10, 3),
          'who5': DateTime(2026, 10, 1),
          'phq9': DateTime(2026, 10, 2),
          'gad7': DateTime(2026, 10, 2),
        },
      );
      expect(labels(rows), <String>['Mood', 'Burnout and stress']);
    });
  });

  group('The first week, spread out', () {
    test('day 1: Mood and the 3-day check (WHO-5 came from setup)', () {
      final List<ScheduleRow> rows = today(
        DateTime(2026, 10, 1, 10),
        // The setup's WHO-5 is a normal Wellbeing result.
        lastDone: <String, DateTime>{'who5': DateTime(2026, 10, 1, 9, 30)},
      );
      expect(labels(rows), <String>['Mood', '3-day check', 'Wellbeing']);
      expect(rows[2].done, isTrue);
      expect(ProgrammeSchedule.cardLine(rows), '1 of 3 done. 2 checks left.');
    });

    test('day 1 with a WHO-5 question skipped in setup: Wellbeing is due', () {
      final List<ScheduleRow> rows = today(DateTime(2026, 10, 1, 10));
      expect(labels(rows), <String>['Mood', '3-day check', 'Wellbeing']);
      expect(rows.where((ScheduleRow r) => r.done), isEmpty);
    });

    test('day 2: low mood and worry', () {
      final List<ScheduleRow> rows = today(
        DateTime(2026, 10, 2, 10),
        lastDone: <String, DateTime>{
          'phq4': DateTime(2026, 10, 1),
          'who5': DateTime(2026, 10, 1),
        },
        lastMood: DateTime(2026, 10, 2, 8),
      );
      expect(labels(rows), <String>['Mood', 'Low mood and worry']);
      expect(ProgrammeSchedule.cardLine(rows), '1 of 2 done. One check left.');
    });

    test('day 3: only Mood', () {
      final List<ScheduleRow> rows = today(
        DateTime(2026, 10, 3, 10),
        lastDone: <String, DateTime>{
          'phq4': DateTime(2026, 10, 1),
          'who5': DateTime(2026, 10, 1),
          'phq9': DateTime(2026, 10, 2),
          'gad7': DateTime(2026, 10, 2),
        },
      );
      expect(labels(rows), <String>['Mood']);
    });

    test('day 4: burnout and stress, and the 3-day check again', () {
      final List<ScheduleRow> rows = today(
        DateTime(2026, 10, 4, 10),
        lastDone: <String, DateTime>{
          'phq4': DateTime(2026, 10, 1),
          'who5': DateTime(2026, 10, 1),
          'phq9': DateTime(2026, 10, 2),
          'gad7': DateTime(2026, 10, 2),
        },
      );
      expect(labels(rows), <String>[
        'Mood',
        '3-day check',
        'Burnout and stress',
      ]);
    });
  });

  group('Local dates around midnight', () {
    test('one minute before midnight is still that day', () {
      final List<ScheduleRow> rows = today(
        DateTime(2026, 10, 1, 23, 59),
        lastDone: <String, DateTime>{'who5': DateTime(2026, 10, 1, 9)},
        lastMood: DateTime(2026, 10, 1, 0, 1),
      );
      expect(rows.first.done, isTrue);
      expect(labels(rows), isNot(contains('Low mood and worry')));
    });

    test('one minute after midnight is the next day', () {
      final List<ScheduleRow> rows = today(
        DateTime(2026, 10, 2, 0, 1),
        lastDone: <String, DateTime>{
          'phq4': DateTime(2026, 10, 1, 23, 58),
          'who5': DateTime(2026, 10, 1, 9),
        },
        lastMood: DateTime(2026, 10, 1, 23, 59),
      );
      expect(rows.first.done, isFalse);
      expect(labels(rows), <String>['Mood', 'Low mood and worry']);
    });
  });

  group('Wording', () {
    test('"{done} of {total} done" and the bubble', () {
      final List<ScheduleRow> rows = <ScheduleRow>[
        const ScheduleRow.mood(done: true),
        const ScheduleRow(
          label: '3-day check',
          assessmentIds: <String>['phq4'],
          done: false,
        ),
      ];
      expect(
        ProgrammeSchedule.cardLine(rows),
        '1 of 2 done. One short check left.',
      );
      expect(ProgrammeSchedule.bubble(rows), '1 check-in left today');
    });

    test('Your hospital: labels, frequencies and next dates', () {
      final DateTime now = DateTime(2026, 10, 27, 10); // a Tuesday
      final List<ScheduleOverviewRow> rows = ProgrammeSchedule.overview(
        config: config,
        joinedAt: joined,
        lastDone: <String, DateTime>{
          'phq4': DateTime(2026, 10, 24),
          'who5': DateTime(2026, 10, 23),
          'phq9': DateTime(2026, 10, 20),
          'gad7': DateTime(2026, 10, 20),
          'cbi': DateTime(2026, 10, 20),
          'pss10': DateTime(2026, 10, 20),
        },
        lastMood: DateTime(2026, 10, 27, 8),
        now: now,
        scales: <String, String>{
          'phq4': 'PHQ-4',
          'who5': 'WHO-5',
          'phq9': 'PHQ-9',
          'gad7': 'GAD-7',
          'cbi': 'CBI',
          'pss10': 'PSS-10',
        },
      );
      expect(rows.map((ScheduleOverviewRow r) => r.label).toList(), <String>[
        'Mood',
        '3-day check (PHQ-4)',
        'Wellbeing (WHO-5)',
        'PHQ-9 and GAD-7',
        'CBI and PSS-10',
      ]);
      expect(
        rows
            .map(
              (ScheduleOverviewRow r) =>
                  ProgrammeSchedule.frequency(r.everyDays),
            )
            .toList(),
        <String>[
          'Every day',
          'Every 3 days',
          'Every week',
          'Every 2 weeks',
          'Every month',
        ],
      );
      expect(
        rows
            .map((ScheduleOverviewRow r) => ProgrammeSchedule.dueLabel(r, now))
            .toList(),
        <String>['Done today', 'Today', 'Fri', '3 Nov', '19 Nov'],
      );
    });
  });
}
