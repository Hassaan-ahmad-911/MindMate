import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/Models/programme_schedule.dart';
import 'package:mindmate/Models/reminder_plan.dart';
import 'package:mindmate/Models/user_settings.dart';

import 'helpers/programme_fakes.dart';
import 'helpers/reminder_fakes.dart';

/// Thursday 29 October 2026, 08:00.
final DateTime morning = DateTime(2026, 10, 29, 8);

ReminderPlan plan(
  UserSettings s, {
  DateTime? now,
  bool moodDone = false,
  bool journalDone = false,
  bool practiceDone = false,
  ProgrammeConfig? programme,
  DateTime? joinedAt,
  Map<String, DateTime> lastDone = const <String, DateTime>{},
  Map<String, int> retakeDays = const <String, int>{},
}) => ReminderPlanner.plan(
  ReminderInputs(
    settings: s.reminders,
    now: now ?? morning,
    moodDoneToday: moodDone,
    journalDoneToday: journalDone,
    practiceDoneToday: practiceDone,
    programme: programme,
    joinedAt: joinedAt,
    lastDone: lastDone,
    retakeDays: retakeDays,
  ),
);

List<PlannedReminder> kind(ReminderPlan p, ReminderKind k) =>
    p.singles.where((PlannedReminder r) => r.kind == k).toList();

List<DateTime> checkInDays(ReminderPlan p) => kind(
  p,
  ReminderKind.checkIns,
).map((PlannedReminder r) => ProgrammeSchedule.dayOf(r.at)).toList();

void main() {
  group('Each kind at its time', () {
    test('mood, journal and practice every day for 14 days', () {
      final ReminderPlan p = plan(
        settingsWith(mood: '20:00', journal: '21:30', practice: '12:00'),
      );
      final List<PlannedReminder> moods = kind(p, ReminderKind.mood);
      expect(moods, hasLength(14));
      expect(moods.first.at, DateTime(2026, 10, 29, 20));
      expect(moods.last.at, DateTime(2026, 11, 11, 20));
      expect(
        kind(p, ReminderKind.journal).first.at,
        DateTime(2026, 10, 29, 21, 30),
      );
      expect(
        kind(p, ReminderKind.practice).first.at,
        DateTime(2026, 10, 29, 12),
      );
    });

    test('only on the chosen days', () {
      // Monday and Thursday only.
      final ReminderPlan p = plan(settingsWith(days: <int>[1, 4]));
      expect(
        kind(
          p,
          ReminderKind.mood,
        ).map((PlannedReminder r) => r.at.weekday).toSet(),
        <int>{1, 4},
      );
      expect(kind(p, ReminderKind.mood), hasLength(4));
    });

    test('a reminder switched off is never planned', () {
      final ReminderPlan p = plan(settingsWith(moodOn: false));
      expect(kind(p, ReminderKind.mood), isEmpty);
    });
  });

  group('Quiet hours', () {
    test('that cross midnight skip the reminder, never move it', () {
      final ReminderPlan p = plan(
        settingsWith(
          mood: '23:30',
          practice: '06:30',
          journal: '07:00',
          quietFrom: '23:00',
          quietTo: '07:00',
        ),
      );
      expect(kind(p, ReminderKind.mood), isEmpty);
      expect(kind(p, ReminderKind.practice), isEmpty);
      // 07:00 is the end of the quiet window: sent.
      expect(kind(p, ReminderKind.journal).first.at.hour, 7);
    });
  });

  group('Skip if already done today', () {
    test('mood, journal and practice, today only', () {
      final ReminderPlan p = plan(
        settingsWith(mood: '20:00', journal: '21:30', practice: '12:00'),
        moodDone: true,
        journalDone: true,
        practiceDone: true,
      );
      for (final ReminderKind k in <ReminderKind>[
        ReminderKind.mood,
        ReminderKind.journal,
        ReminderKind.practice,
      ]) {
        final List<PlannedReminder> list = kind(p, k);
        expect(list, hasLength(13), reason: '$k: today skipped');
        expect(list.first.at.day, 30);
      }
    });

    test('anything earlier today is in the past and dropped', () {
      final ReminderPlan p = plan(
        settingsWith(mood: '07:00'),
        now: DateTime(2026, 10, 29, 9),
      );
      expect(kind(p, ReminderKind.mood).first.at, DateTime(2026, 10, 30, 7));
    });
  });

  group('Merging', () {
    test('less than 60 minutes apart: one at the earliest time', () {
      final ReminderPlan p = plan(
        settingsWith(mood: '20:00', journal: '20:59'),
      );
      final PlannedReminder first = p.notifications.first;
      expect(first.kind, ReminderKind.merged);
      expect(first.at, DateTime(2026, 10, 29, 20));
      expect(first.parts.map((PlannedReminder r) => r.kind), <ReminderKind>[
        ReminderKind.mood,
        ReminderKind.journal,
      ]);
      expect(first.payload, ReminderTargets.today);
    });

    test('60 minutes or more apart: two reminders', () {
      final ReminderPlan p = plan(
        settingsWith(mood: '20:00', journal: '21:00'),
      );
      expect(
        p.notifications.take(2).map((PlannedReminder r) => r.kind),
        <ReminderKind>[ReminderKind.mood, ReminderKind.journal],
      );
    });
  });

  group('The window and the cap', () {
    test('14 days, and never more than 60', () {
      final ReminderPlan p = plan(
        settingsWith(mood: '20:00', journal: '09:00', practice: '14:00'),
      );
      expect(p.singles, hasLength(42));
      expect(p.notifications, hasLength(42));
      expect(p.notifications.last.at.isBefore(DateTime(2026, 11, 12)), isTrue);

      final ReminderPlan many = plan(
        settingsWith(mood: '20:00', journal: '09:00', practice: '14:00'),
        programme: fileProgramme(),
        joinedAt: DateTime(2026, 10, 29),
      );
      expect(many.notifications.length, lessThanOrEqualTo(ReminderPlanner.cap));
    });
  });

  group('Check-ins due, in a hospital programme', () {
    final ProgrammeConfig config = fileProgramme();

    test('at the mood time, on the due day and once more the next day', () {
      final ReminderPlan p = plan(
        settingsWith(mood: '20:00', checkInsDue: true),
        programme: config,
        joinedAt: DateTime(2026, 10, 1),
        lastDone: <String, DateTime>{
          'phq4': DateTime(2026, 10, 28), // due 31 Oct
          'who5': DateTime(2026, 10, 28), // due 4 Nov
          'phq9': DateTime(2026, 10, 28),
          'gad7': DateTime(2026, 10, 28),
          'cbi': DateTime(2026, 10, 28),
          'pss10': DateTime(2026, 10, 28),
        },
      );
      final List<PlannedReminder> due = kind(p, ReminderKind.checkIns);
      expect(due.first.at, DateTime(2026, 10, 31, 20));
      expect(due.first.assessmentIds, <String>['phq4']);
      expect(due.first.payload, 'checkin:phq4');
      expect(checkInDays(p), <DateTime>[
        DateTime(2026, 10, 31),
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 4),
        DateTime(2026, 11, 5),
        DateTime(2026, 11, 11),
      ]);
    });

    test('several due on one day are one reminder', () {
      final ReminderPlan p = plan(
        settingsWith(mood: '20:00', checkInsDue: true),
        programme: config,
        joinedAt: DateTime(2026, 10, 29),
        lastDone: <String, DateTime>{'who5': DateTime(2026, 10, 29, 7)},
      );
      final PlannedReminder day1 = kind(p, ReminderKind.checkIns).first;
      expect(day1.at, DateTime(2026, 10, 29, 20));
      expect(day1.assessmentIds, <String>['phq4']);

      // Day 2: PHQ-4 once more, and PHQ-9 + GAD-7 fall due.
      final PlannedReminder day2 = kind(p, ReminderKind.checkIns)[1];
      expect(day2.at, DateTime(2026, 10, 30, 20));
      expect(day2.assessmentIds, <String>['phq4', 'phq9', 'gad7']);
      expect(day2.payload, ReminderTargets.today);
    });

    test('the first-week spread: days 1, 2 and 4', () {
      final ReminderPlan p = plan(
        settingsWith(mood: '20:00', checkInsDue: true),
        programme: config,
        joinedAt: DateTime(2026, 10, 29),
        // On day 1 the setup WHO-5 is done; then nothing else is taken.
        lastDone: <String, DateTime>{'who5': DateTime(2026, 10, 29, 7)},
      );
      final Map<DateTime, List<String>> byDay = <DateTime, List<String>>{
        for (final PlannedReminder r in kind(p, ReminderKind.checkIns))
          ProgrammeSchedule.dayOf(r.at): r.assessmentIds,
      };
      expect(byDay[DateTime(2026, 10, 29)], <String>['phq4']);
      expect(
        byDay[DateTime(2026, 10, 30)],
        containsAll(<String>['phq9', 'gad7']),
      );
      expect(byDay[DateTime(2026, 11, 1)], <String>['cbi', 'pss10']);
      expect(byDay[DateTime(2026, 11, 2)], <String>['cbi', 'pss10']);
    });

    test('long overdue: no more reminders until it is next due', () {
      final ReminderPlan p = plan(
        settingsWith(mood: '20:00', checkInsDue: true),
        programme: config,
        joinedAt: DateTime(2026, 9, 1),
        lastDone: <String, DateTime>{
          for (final String id in <String>[
            'phq4',
            'who5',
            'phq9',
            'gad7',
            'cbi',
            'pss10',
          ])
            id: DateTime(2026, 9, 20),
        },
      );
      expect(kind(p, ReminderKind.checkIns), isEmpty);
    });

    test('mood time 19:00 when the mood reminder is off', () {
      final ReminderPlan p = plan(
        settingsWith(moodOn: false, checkInsDue: true),
        programme: config,
        joinedAt: DateTime(2026, 10, 29),
      );
      expect(
        kind(p, ReminderKind.checkIns).first.at,
        DateTime(2026, 10, 29, 19),
      );
    });
  });

  group('Check-ins due, not in a programme', () {
    test(
      'on the retake day and once more 7 days later; never-taken skipped',
      () {
        final ReminderPlan p = plan(
          settingsWith(mood: '20:00', checkInsDue: true),
          lastDone: <String, DateTime>{'phq9': DateTime(2026, 10, 16)},
          retakeDays: <String, int>{'phq9': 14, 'gad7': 14, 'cbi': 30},
        );
        final List<PlannedReminder> due = kind(p, ReminderKind.checkIns);
        expect(checkInDays(p), <DateTime>[
          DateTime(2026, 10, 30),
          DateTime(2026, 11, 6),
        ]);
        expect(due.first.programme, isFalse);
        expect(due.first.payload, ReminderTargets.hub);
      },
    );
  });

  group('Wording', () {
    final List<PlannedReminder> every = <PlannedReminder>[
      PlannedReminder(at: DateTime(2026, 10, 29, 8), kind: ReminderKind.mood),
      PlannedReminder(at: DateTime(2026, 10, 29, 20), kind: ReminderKind.mood),
      PlannedReminder(
        at: DateTime(2026, 10, 29, 8),
        kind: ReminderKind.journal,
      ),
      PlannedReminder(
        at: DateTime(2026, 10, 29, 21),
        kind: ReminderKind.journal,
      ),
      PlannedReminder(
        at: DateTime(2026, 10, 29, 7),
        kind: ReminderKind.practice,
      ),
      for (final List<String> ids in <List<String>>[
        <String>['phq4'],
        <String>['who5'],
        <String>['phq9', 'gad7'],
        <String>['cbi', 'pss10'],
        <String>['phq4', 'who5'],
      ])
        PlannedReminder(
          at: DateTime(2026, 10, 29, 20),
          kind: ReminderKind.checkIns,
          assessmentIds: ids,
          programme: true,
        ),
      PlannedReminder(
        at: DateTime(2026, 10, 29, 20),
        kind: ReminderKind.checkIns,
        assessmentIds: const <String>['cbi'],
      ),
      PlannedReminder(
        at: DateTime(2026, 10, 29, 20),
        kind: ReminderKind.merged,
      ),
      PlannedReminder(at: DateTime(2026, 10, 29, 20), kind: ReminderKind.test),
    ];

    const List<String> banned = <String>[
      '!',
      'missed',
      'streak',
      'late',
      'overdue',
      'behind',
      'failed',
      'forgot',
      'PHQ',
      'GAD',
      'WHO',
      'CBI',
      'PSS',
      'depress',
      'anxi',
      'burnout',
      'stress',
      'score',
    ];

    test('no banned word, "!" or questionnaire name in any reminder', () {
      for (final bool hidden in <bool>[false, true]) {
        for (final PlannedReminder r in every) {
          final ({String title, String body}) t = ReminderWording.of(
            r,
            hidden: hidden,
          );
          final String text = '${t.title} ${t.body}';
          for (final String word in banned) {
            expect(
              text.toLowerCase().contains(word.toLowerCase()),
              isFalse,
              reason: '"$word" in "$text"',
            );
          }
        }
      }
    });

    test('the exact words', () {
      String words(PlannedReminder r) {
        final ({String title, String body}) t = ReminderWording.of(
          r,
          hidden: false,
        );
        return '${t.title} | ${t.body}';
      }

      expect(every.map(words).toList(), <String>[
        'How are you feeling today? | A quick check-in takes about 10 seconds.',
        'How are you feeling tonight? | A quick check-in takes about 10 seconds.',
        "A moment to write? | Today's prompt is ready.",
        "A moment to write? | Tonight's prompt is ready.",
        'A calm minute? | A short practice is ready when you are.',
        'Your 3-day check is ready | 4 questions, about 30 seconds.',
        'A short wellbeing check is ready | 5 questions, about a minute.',
        'Your check-in is ready | A few minutes, whenever suits you.',
        'Your check-in is ready | A few minutes, whenever suits you.',
        'Your check-in is ready | A few minutes, whenever suits you.',
        'A short check-in is ready | A few minutes, whenever suits you.',
        "A couple of gentle reminders | Open MindMate to see what's ready.",
        'This is a test reminder | Your reminders will look like this.',
      ]);
    });

    test(
      '"Hide reminder text" on: MindMate, "You have a gentle reminder."',
      () {
        for (final PlannedReminder r in every) {
          final ({String title, String body}) t = ReminderWording.of(
            r,
            hidden: true,
          );
          expect(t.title, 'MindMate');
          expect(t.body, 'You have a gentle reminder.');
        }
      },
    );

    test('the next-reminder line', () {
      expect(
        ReminderWording.nextLine(
          PlannedReminder(
            at: DateTime(2026, 10, 29, 20),
            kind: ReminderKind.mood,
          ),
          morning,
        ),
        'Today 20:00 · Mood check-in',
      );
      expect(
        ReminderWording.nextLine(
          PlannedReminder(
            at: DateTime(2026, 10, 30, 7, 30),
            kind: ReminderKind.practice,
          ),
          morning,
        ),
        'Tomorrow 07:30 · Practice',
      );
      expect(
        ReminderWording.nextLine(
          PlannedReminder(
            at: DateTime(2026, 10, 31, 20),
            kind: ReminderKind.journal,
          ),
          morning,
        ),
        'Sat 20:00 · Journal prompt',
      );
    });
  });
}
