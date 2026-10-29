import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:mindmate/Models/assessment_definition.dart';
import 'package:mindmate/Models/assessment_result.dart';
import 'package:mindmate/Models/break_log.dart';
import 'package:mindmate/Models/journal_model.dart';
import 'package:mindmate/Models/meditation_log_entry.dart';
import 'package:mindmate/Models/mood_catalog.dart';
import 'package:mindmate/Models/mood_model.dart';
import 'package:mindmate/Models/report_calculator.dart';
import 'package:mindmate/Models/report_pdf_data.dart';
import 'package:mindmate/Models/report_period.dart';
import 'package:mindmate/services/report_pdf_service.dart';

MoodModel mood(DateTime at, String name, {List<String> factors = const []}) {
  return MoodModel(
    mood: name,
    valence: MoodCatalog.valenceFor(name),
    intensity: MoodCatalog.mild,
    factors: factors,
    note: 'PRIVATE NOTE',
    date: at,
  );
}

MeditationLogEntry session(
  DateTime at, {
  int seconds = 300,
  int? before,
  int? after,
}) {
  return MeditationLogEntry(
    id: 's${at.millisecondsSinceEpoch}$seconds',
    sessionId: 'arriving',
    title: 'Arriving',
    startedAt: at,
    endedAt: at.add(Duration(seconds: seconds)),
    secondsPractised: seconds,
    completed: true,
    feelBefore: before,
    feelAfter: after,
  );
}

BreakLogEntry brk(DateTime at, {bool completed = true}) => BreakLogEntry(
  id: 'b${at.millisecondsSinceEpoch}',
  activity: BreakActivity.breathingBubble,
  startedAt: at,
  seconds: 120,
  completed: completed,
);

JournalSummary entry(
  DateTime at, {
  JournalTone? tone,
  List<String> topics = const [],
}) => JournalSummary(
  id: 'j${at.millisecondsSinceEpoch}',
  title: 'Title',
  type: 'free',
  tone: tone,
  toneScore: null,
  topics: topics,
  createdAt: at,
);

DateTime d(int month, int day, [int hour = 12]) =>
    DateTime(2026, month, day, hour);

void main() {
  group('Periods', () {
    test('a week runs Monday to Sunday', () {
      final ReportPeriod w = ReportPeriod.week(d(10, 8)); // a Thursday
      expect(w.start, DateTime(2026, 10, 5));
      expect(w.start.weekday, DateTime.monday);
      expect(w.lastDay, DateTime(2026, 10, 11));
      expect(w.label, '5 – 11 October');
      expect(ReportPeriod.week(DateTime(2026, 10, 11, 23)).start, w.start);
      expect(
        ReportPeriod.week(DateTime(2026, 10, 12)).start,
        DateTime(2026, 10, 12),
      );
      expect(w.previous.start, DateTime(2026, 9, 28));
      expect(w.previous.label, '28 September – 4 October');
    });

    test('a month is the calendar month', () {
      final ReportPeriod m = ReportPeriod.month(d(9, 15));
      expect(m.start, DateTime(2026, 9));
      expect(m.end, DateTime(2026, 10));
      expect(m.days, hasLength(30));
      expect(m.label, 'September 2026');
      expect(m.previous.start, DateTime(2026, 8));
    });
  });

  group('Days', () {
    test('day groups use the day score', () {
      final Map<DateTime, MoodGroup> groups = ReportCalculator.dayGroups(
        <MoodModel>[
          mood(d(10, 5, 8), 'Happy'), // +2
          mood(d(10, 5, 20), 'Okay'), // 0 -> day 1.0: good
          mood(d(10, 6), 'Calm'), // +1, good
          mood(d(10, 7), 'Okay'), // 0, between
          mood(d(10, 8, 8), 'Calm'),
          mood(d(10, 8, 20), 'Stressed'), // 0: between
          mood(d(10, 9), 'Sad'), // -2, hard
        ],
      );
      expect(groups[DateTime(2026, 10, 5)], MoodGroup.good);
      expect(groups[DateTime(2026, 10, 7)], MoodGroup.between);
      expect(groups[DateTime(2026, 10, 8)], MoodGroup.between);
      expect(groups[DateTime(2026, 10, 9)], MoodGroup.hard);
      expect(groups.containsKey(DateTime(2026, 10, 10)), isFalse);
    });

    test('practice, journal and break days; calm minutes', () {
      expect(
        ReportCalculator.practiceDays(<MeditationLogEntry>[
          session(d(10, 5), seconds: 60),
          session(d(10, 6), seconds: 59),
        ]),
        <DateTime>{DateTime(2026, 10, 5)},
      );
      expect(
        ReportCalculator.journalDays(<JournalSummary>[entry(d(10, 7))]),
        <DateTime>{DateTime(2026, 10, 7)},
      );
      expect(
        ReportCalculator.breakDays(<BreakLogEntry>[
          brk(d(10, 5)),
          brk(d(10, 6), completed: false),
        ]),
        <DateTime>{DateTime(2026, 10, 5)},
      );
      expect(
        ReportCalculator.calmMinutes(<MeditationLogEntry>[
          session(d(10, 5), seconds: 100),
          session(d(10, 6), seconds: 79),
        ]),
        2,
      );
    });
  });

  group('Comparison rows', () {
    List<MoodModel> days(List<int> dayNumbers, String name) => <MoodModel>[
      for (final int n in dayNumbers) mood(d(9, n), name),
    ];

    test('each side needs at least 3 mood days', () {
      final List<MoodModel> moods = <MoodModel>[
        ...days(<int>[1, 2, 3], 'Happy'),
        ...days(<int>[4, 5, 6], 'Sad'),
      ];
      final Set<DateTime> practiced = <DateTime>{
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 2),
        DateTime(2026, 9, 3),
      };
      final List<ComparisonRow> rows = ReportCalculator.comparisonRows(
        moods: moods,
        practiced: practiced,
        journaled: <DateTime>{DateTime(2026, 9, 1), DateTime(2026, 9, 2)},
        tookBreak: null,
      );
      expect(rows, hasLength(1));
      expect(rows.single.label, 'Practised');
      expect(rows.single.onAverage, 2);
      expect(rows.single.otherAverage, -2);
      expect(rows.single.onDays, 3);
      expect(rows.single.otherDays, 3);
    });

    test('too few days on the other side hides the row', () {
      final List<ComparisonRow> rows = ReportCalculator.comparisonRows(
        moods: <MoodModel>[
          ...days(<int>[1, 2, 3, 4], 'Happy'),
          ...days(<int>[5, 6], 'Sad'),
        ],
        practiced: <DateTime>{
          DateTime(2026, 9, 1),
          DateTime(2026, 9, 2),
          DateTime(2026, 9, 3),
          DateTime(2026, 9, 4),
        },
      );
      expect(rows, isEmpty);
    });

    test('activity days without a mood do not count', () {
      final List<ComparisonRow> rows = ReportCalculator.comparisonRows(
        moods: days(<int>[1, 2, 3, 4, 5, 6], 'Okay'),
        practiced: <DateTime>{
          DateTime(2026, 9, 1),
          DateTime(2026, 9, 2),
          DateTime(2026, 9, 20),
        },
      );
      expect(rows, isEmpty, reason: 'only 2 practised days have a mood');
    });
  });

  group('Before and after practice', () {
    test('needs 3 practices with both feelings', () {
      expect(
        ReportCalculator.beforeAfter(<MeditationLogEntry>[
          session(d(10, 1), before: 2, after: 4),
          session(d(10, 2), before: 3, after: 3),
          session(d(10, 3), before: 2),
        ]),
        isNull,
      );
      final BeforeAfter? ba = ReportCalculator.beforeAfter(<MeditationLogEntry>[
        session(d(10, 1), before: 2, after: 4),
        session(d(10, 2), before: 3, after: 3),
        session(d(10, 3), before: 2, after: 4),
      ]);
      expect(ba!.count, 3);
      expect(ba.better, 2);
      expect(ba.before, closeTo(2.33, 0.01));
      expect(ba.after, closeTo(3.67, 0.01));
    });
  });

  group('On harder days', () {
    test('no hard days hides the card', () {
      expect(
        ReportCalculator.harderDays(<MoodModel>[mood(d(10, 1), 'Happy')]),
        isNull,
      );
    });

    test('factors are counted once per hard day, top 3', () {
      final HarderDays? h = ReportCalculator.harderDays(<MoodModel>[
        mood(d(10, 1, 8), 'Sad', factors: <String>['Night shift', 'Sleep']),
        mood(d(10, 1, 20), 'Angry', factors: <String>['Night shift']),
        mood(d(10, 2), 'Sad', factors: <String>['Night shift', 'Workload']),
        mood(
          d(10, 3),
          'Overwhelmed',
          factors: <String>['Night shift', 'Sleep'],
        ),
        mood(d(10, 4), 'Sad', factors: <String>['Team']),
        mood(d(10, 5), 'Happy', factors: <String>['Night shift']),
      ]);
      expect(h!.hardDays, 4);
      expect(h.topFactors.first, isA<MapEntry<String, int>>());
      expect(h.topFactors.first.key, 'Night shift');
      expect(h.topFactors.first.value, 3);
      expect(h.topFactors, hasLength(3));
      expect(h.sentence, 'Night shift came up on 3 of your 4 harder days.');
    });

    test('the sentence needs n >= 2 and 60%', () {
      expect(
        ReportCalculator.harderDays(<MoodModel>[
          mood(d(10, 1), 'Sad', factors: <String>['Sleep']),
        ])!.sentence,
        isNull,
        reason: 'n is 1',
      );
      expect(
        ReportCalculator.harderDays(<MoodModel>[
          mood(d(10, 1), 'Sad', factors: <String>['Sleep']),
          mood(d(10, 2), 'Sad', factors: <String>['Team']),
          mood(d(10, 3), 'Sad', factors: <String>['Workload']),
        ])!.sentence,
        isNull,
        reason: '1 of 3 is under 60%',
      );
      expect(
        ReportCalculator.harderDays(<MoodModel>[
          mood(d(10, 1), 'Sad', factors: <String>['Sleep']),
          mood(d(10, 2), 'Sad', factors: <String>['Sleep']),
          mood(d(10, 3), 'Sad', factors: <String>['Sleep']),
          mood(d(10, 4), 'Sad', factors: <String>['Team']),
          mood(d(10, 5), 'Sad'),
        ])!.sentence,
        'Sleep came up on 3 of your 5 harder days.',
      );
    });
  });

  group('Highlights', () {
    PeriodStats stats({
      int good = 0,
      int hard = 0,
      int moodDays = 0,
      int practiceDays = 0,
      int minutes = 0,
      int journal = 0,
      int checkIns = 0,
      HarderDays? harder,
    }) => PeriodStats(
      moodDays: moodDays == 0 ? good + hard : moodDays,
      goodDays: good,
      hardDays: hard,
      practiceDays: practiceDays,
      calmMinutes: minutes,
      journalEntries: journal,
      breaks: 0,
      checkIns: checkIns,
      harder: harder,
    );

    const HarderDays nights = HarderDays(
      hardDays: 3,
      topFactors: <MapEntry<String, int>>[
        MapEntry<String, int>('Night shift', 3),
      ],
      sentenceFactor: 'Night shift',
      sentenceCount: 3,
    );

    List<String> lines(PeriodStats now, PeriodStats? before) =>
        ReportCalculator.highlights(
          now,
          before,
          ReportKind.week,
        ).map((Highlight h) => h.text).toList();

    test('rules in order, at most 3', () {
      expect(
        lines(
          stats(
            good: 4,
            practiceDays: 4,
            minutes: 42,
            harder: nights,
            checkIns: 1,
          ),
          stats(good: 2),
        ),
        <String>[
          'More good days than last week: 4, up from 2',
          'You practised on 4 days, 42 minutes in all',
          'Night shifts came up on most of your harder days',
        ],
      );
    });

    test('a harder week needs fewer good days and 3+ hard days', () {
      expect(
        lines(stats(good: 1, hard: 3), stats(good: 3)).first,
        'A harder week: 3 hard days. Be gentle with yourself.',
      );
      expect(lines(stats(good: 1, hard: 2), stats(good: 3)), isEmpty);
    });

    test('check-ins and journal entries', () {
      expect(lines(stats(moodDays: 1, checkIns: 1, journal: 2), null), <String>[
        'You completed 1 check-in',
        'You wrote 2 journal entries',
      ]);
      expect(lines(stats(moodDays: 1, checkIns: 2, journal: 1), null), <String>[
        'You completed 2 check-ins',
        'You wrote 1 journal entry',
      ]);
    });

    test('nothing logged gives no lines (the card invites a mood)', () {
      expect(lines(stats(), stats(good: 3)), isEmpty);
    });

    test('month wording', () {
      expect(
        ReportCalculator.highlights(
          stats(good: 5),
          stats(good: 1),
          ReportKind.month,
        ).first.text,
        'More good days than last month: 5, up from 1',
      );
    });
  });

  group('Change labels', () {
    test('up, down, same, and hidden without previous data', () {
      String? label(int a, int b, {bool prev = true}) =>
          ReportCalculator.changeLabel(
            a,
            b,
            previousHasData: prev,
            kind: ReportKind.week,
          );
      expect(label(42, 30), '↑ 12 from last week');
      expect(label(3, 4), '↓ 1 from last week');
      expect(label(5, 5), 'Same as last week');
      expect(label(5, 0, prev: false), isNull);
      expect(
        ReportCalculator.changeLabel(
          2,
          1,
          previousHasData: true,
          kind: ReportKind.month,
        ),
        '↑ 1 from last month',
      );
    });
  });

  group('Week by week', () {
    test('weeks overlapping the month, only its own days, 2-day minimum', () {
      // September 2026 starts on a Tuesday: week 1 is 31 Aug - 6 Sep.
      final ReportPeriod sept = ReportPeriod.month(d(9, 15));
      final List<WeekAverage> weeks = ReportCalculator.weekByWeek(<MoodModel>[
        mood(DateTime(2026, 8, 31), 'Sad'), // August: not counted
        mood(d(9, 1), 'Happy'),
        mood(d(9, 2), 'Calm'),
        mood(d(9, 8), 'Sad'), // week 2 has only one day
        mood(d(9, 29), 'Okay'),
        mood(d(9, 30), 'Happy'),
      ], sept);
      expect(weeks, hasLength(5));
      expect(weeks.first.start, DateTime(2026, 8, 31));
      expect(weeks.first.average, 1.5);
      expect(weeks[1].average, isNull);
      expect(weeks.last.start, DateTime(2026, 9, 28));
      expect(weeks.last.average, 1.0);
      expect(ReportCalculator.signed(0.6), '+0.6');
      expect(ReportCalculator.signed(-0.4), '−0.4');
    });
  });

  group('Journal tone', () {
    test('counts, most common tone and top topics', () {
      final ToneSummary? t = ReportCalculator.toneSummary(<JournalSummary>[
        entry(d(10, 1), tone: JournalTone.light, topics: <String>['Team']),
        entry(
          d(10, 2),
          tone: JournalTone.mixed,
          topics: <String>['Team', 'Sleep'],
        ),
        entry(
          d(10, 3),
          tone: JournalTone.mixed,
          topics: <String>['Night shift'],
        ),
        entry(d(10, 4), tone: JournalTone.heavy, topics: <String>['Team']),
        entry(d(10, 5)),
      ]);
      expect(t!.entries, 5);
      expect(t.light, 1);
      expect(t.mixed, 2);
      expect(t.heavy, 1);
      expect(t.mostly, JournalTone.mixed);
      expect(t.topTopics.first.key, 'Team');
      expect(t.topTopics.first.value, 3);
      expect(ReportCalculator.toneSummary(<JournalSummary>[]), isNull);
    });
  });

  group('The PDF', () {
    late ReportPdfFonts fonts;

    setUpAll(() async {
      fonts = await ReportPdfFonts.load(
        loader: (String path) async {
          final Uint8List bytes = File(path).readAsBytesSync();
          return ByteData.sublistView(bytes);
        },
      );
    });

    final MoodSummary moodSummary = ReportCalculator.moodSummary(
      <MoodModel>[
        for (int i = 1; i <= 28; i += 1)
          mood(
            d(9, i),
            i.isEven ? 'Calm' : 'Sad',
            factors: <String>['Night shift'],
          ),
      ],
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 10, 1),
    )!;

    test('mood summary for the period', () {
      expect(moodSummary.daysLogged, 28);
      expect(moodSummary.totalDays, 30);
      expect(moodSummary.good + moodSummary.between + moodSummary.hard, 28);
      expect(moodSummary.dailyScores, hasLength(30));
      expect(moodSummary.hardFactors.first.key, 'Night shift');
    });

    test('check-in rows show the score, range and question 9 note', () {
      final AssessmentContent content = AssessmentContent.fromJson(
        File('assets/assessments/assessments_content.json').readAsStringSync(),
      );
      final List<CheckInRow> rows = ReportCalculator.checkInRows(
        <AssessmentLatest>[
          AssessmentLatest(
            latest: AssessmentSummary(
              assessmentId: 'phq9',
              total: 11,
              bandId: 'moderate',
              areas: null,
              headline: 11,
              headlineBandId: 'moderate',
              completedAt: d(10, 8),
              item9Positive: true,
            ),
            previous: AssessmentSummary(
              assessmentId: 'phq9',
              total: 14,
              bandId: 'moderate',
              areas: null,
              headline: 14,
              completedAt: d(9, 24),
            ),
          ),
          AssessmentLatest(
            latest: AssessmentSummary(
              assessmentId: 'cbi',
              total: null,
              bandId: null,
              areas: const <String, double>{
                'work': 68,
                'personal': 54,
                'patients': 33.3,
              },
              headline: 68,
              headlineBandId: 'moderate',
              completedAt: d(10, 1),
            ),
          ),
        ],
        content,
      );
      expect(rows[0].scale, 'PHQ-9');
      expect(rows[0].score, '11 / 27');
      expect(rows[0].range, 'Moderate');
      expect(rows[0].previous, '14 (24 Sep)');
      expect(rows[0].item9Positive, isTrue);
      expect(rows[1].score, 'Work 68, Personal 54, Patients 33');
      expect(rows[1].previous, 'None');
    });

    test('every switch combination gives exactly one page', () async {
      for (int mask = 0; mask < 8; mask += 1) {
        final ReportPdfData data = ReportPdfData(
          name: 'Ayesha Khan',
          role: 'Staff nurse',
          firstDay: DateTime(2026, 7, 12),
          lastDay: DateTime(2026, 10, 9),
          createdAt: DateTime(2026, 10, 9),
          includeMood: mask & 1 != 0,
          includeCheckIns: mask & 2 != 0,
          includePractice: mask & 4 != 0,
          mood: mask.isEven ? moodSummary : null,
          checkIns: <CheckInRow>[
            for (int i = 0; i < 6; i += 1)
              CheckInRow(
                scale: 'PHQ-9',
                name: 'Low mood',
                date: d(10, 8),
                score: 'Work 68, Personal 54, Patients 33',
                range: 'Moderately severe',
                previous: '14 (24 Sep)',
                item9Positive: true,
              ),
          ],
          practice: const PracticeSummary(
            sessions: 11,
            minutes: 94,
            feelBefore: 2.4,
            feelAfter: 3.6,
            breaks: 14,
            journalEntries: 12,
          ),
        );
        final pw.Document doc = ReportPdfService.build(data, fonts);
        final Uint8List bytes = await doc.save();
        expect(
          doc.document.pdfPageList.pages,
          hasLength(1),
          reason: 'mask $mask',
        );
        // Mood notes and journal text are never part of the PDF data.
        expect(String.fromCharCodes(bytes).contains('PRIVATE NOTE'), isFalse);
      }
    });

    test('the file name and period line', () {
      expect(
        ReportPdfService.fileName(DateTime(2026, 10, 9)),
        'MindMate-summary-2026-10-09.pdf',
      );
      expect(
        ReportPdfService.periodLabel(
          DateTime(2026, 9, 10),
          DateTime(2026, 10, 9),
        ),
        '10 September to 9 October 2026',
      );
    });
  });
}
