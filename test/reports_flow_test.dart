import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Models/assessment_result.dart';
import 'package:mindmate/Models/break_log.dart';
import 'package:mindmate/Models/journal_model.dart';
import 'package:mindmate/Models/meditation_log_entry.dart';
import 'package:mindmate/Models/mood_catalog.dart';
import 'package:mindmate/Models/mood_model.dart';
import 'package:mindmate/ui/app/app_routes.dart';

import 'helpers/journal_fakes.dart';
import 'helpers/report_app.dart';

void ignoreOverflowErrors() {
  final FlutterExceptionHandler? original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (!details.exceptionAsString().contains('overflowed')) {
      original?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = original);
}

Future<void> go(WidgetTester tester, [int ms = 700]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
}

Future<ReportTestApp> open(
  WidgetTester tester, {
  ReportTestApp? app,
  String route = AppRoutes.reports,
}) async {
  // Tall, so every section of these long screens is built.
  tester.view.physicalSize = const Size(1170, 7000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  ignoreOverflowErrors();
  final ReportTestApp a = app ?? ReportTestApp();
  await tester.pumpWidget(a.build(initialRoute: route));
  await go(tester);
  await go(tester);
  return a;
}

MoodModel mood(
  DateTime at,
  String name, {
  List<String> factors = const <String>[],
}) => MoodModel(
  id: 'm${at.millisecondsSinceEpoch}',
  mood: name,
  valence: MoodCatalog.valenceFor(name),
  intensity: MoodCatalog.moderate,
  factors: factors,
  note: 'A private note',
  date: at,
);

MeditationLogEntry practice(DateTime at, {int? before, int? after}) =>
    MeditationLogEntry(
      id: 'p${at.millisecondsSinceEpoch}',
      sessionId: 'arriving',
      title: 'Arriving',
      startedAt: at,
      endedAt: at.add(const Duration(minutes: 10)),
      secondsPractised: 600,
      completed: true,
      feelBefore: before,
      feelAfter: after,
    );

/// A week (5-11 Oct 2026, today Thu 8 Oct) and the 30 days before it.
ReportTestApp seeded() {
  final ReportTestApp app = ReportTestApp();
  // This week: Mon good, Tue hard (night shift), Wed good, Thu between.
  app.moods.history.addAll(<MoodModel>[
    mood(DateTime(2026, 10, 5, 9), 'Happy'),
    mood(DateTime(2026, 10, 6, 9), 'Sad', factors: <String>['Night shift']),
    mood(DateTime(2026, 10, 7, 9), 'Grateful'),
    mood(DateTime(2026, 10, 8, 9), 'Tired'),
    // Last week: one good day.
    mood(DateTime(2026, 9, 29, 9), 'Calm'),
    mood(DateTime(2026, 9, 30, 9), 'Sad', factors: <String>['Night shift']),
    // Earlier in the 30 days.
    for (int d = 10; d <= 20; d += 1)
      mood(DateTime(2026, 9, d, 9), d.isEven ? 'Calm' : 'Stressed'),
  ]);
  app.practice.history.addAll(<MeditationLogEntry>[
    practice(DateTime(2026, 10, 5, 20), before: 2, after: 4),
    practice(DateTime(2026, 10, 7, 20), before: 3, after: 4),
    for (int d = 10; d <= 20; d += 2)
      practice(DateTime(2026, 9, d, 20), before: 2, after: 3),
  ]);
  app.breaks.stored.add(
    BreakLogEntry(
      id: 'b1',
      activity: BreakActivity.breathingBubble,
      startedAt: DateTime(2026, 10, 6, 12),
      seconds: 120,
      completed: true,
    ),
  );
  app.journal.addEntry(
    journalEntry(
      id: 'j1',
      createdAt: DateTime(2026, 10, 7, 21),
      tone: JournalTone.mixed,
      topics: <String>['Team'],
    ),
  );
  app.checkIns.stored.add(
    AssessmentResult(
      id: 'r1',
      assessmentId: 'phq9',
      contentVersion: 1,
      answers: const <int>[1, 1, 1, 1, 1, 1, 1, 1, 0],
      total: 8,
      bandId: 'mild',
      startedAt: DateTime(2026, 10, 6, 10),
      completedAt: DateTime(2026, 10, 6, 10),
    ),
  );
  return app;
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  group('Week', () {
    testWidgets('highlights, day by day, tiles and look closer', (
      WidgetTester tester,
    ) async {
      await open(tester, app: seeded());

      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('5 – 11 October'), findsOneWidget);
      expect(find.text('YOUR WEEK'), findsOneWidget);
      expect(
        find.text('More good days than last week: 2, up from 1'),
        findsOneWidget,
      );
      expect(
        find.text('You practised on 2 days, 20 minutes in all'),
        findsOneWidget,
      );
      expect(find.text('You completed 1 check-in'), findsOneWidget);
      expect(find.text('Day by day'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('days with a mood'), findsOneWidget);
      expect(find.text('calm minutes'), findsOneWidget);
      expect(find.text('journal entries'), findsOneWidget);
      expect(find.text('short breaks'), findsOneWidget);
      expect(find.text('↑ 20 from last week'), findsOneWidget);
      expect(find.text('What helped'), findsOneWidget);
      expect(find.text('Share a summary'), findsOneWidget);
      expect(
        find.text('Made on your phone from what you logged. Not a diagnosis.'),
        findsOneWidget,
      );
    });

    testWidgets('">" is off on the current week and "<" goes back', (
      WidgetTester tester,
    ) async {
      await open(tester, app: seeded());
      final IconButton next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
      );
      expect(next.onPressed, isNull);

      await tester.tap(find.byTooltip('Previous'));
      await go(tester);
      expect(find.text('28 September – 4 October'), findsOneWidget);
    });

    testWidgets('tapping a day opens the mood history for that day', (
      WidgetTester tester,
    ) async {
      await open(tester, app: seeded());
      await tester.tap(find.text('Tue'));
      await go(tester);
      expect(
        find.textContaining('PAGE ${AppRoutes.moodHistory}'),
        findsOneWidget,
      );
      expect(find.textContaining('2026-10-06'), findsOneWidget);
    });

    testWidgets('nothing logged invites a mood', (WidgetTester tester) async {
      await open(tester);
      expect(
        find.text('Nothing logged this week yet. A mood takes 10 seconds.'),
        findsOneWidget,
      );
      expect(find.text('Log mood'), findsOneWidget);
    });

    testWidgets('a failed source shows retry only in its own sections', (
      WidgetTester tester,
    ) async {
      final ReportTestApp app = seeded();
      app.practice.failRange = true;
      await open(tester, app: app);

      expect(find.text('Could not load. Tap to retry'), findsOneWidget);
      expect(find.text('days with a mood'), findsOneWidget);
      expect(find.text('journal entries'), findsOneWidget);

      app.practice.failRange = false;
      await tester.tap(find.text('Could not load. Tap to retry'));
      await go(tester);
      expect(find.text('Could not load. Tap to retry'), findsNothing);
      expect(find.text('calm minutes'), findsOneWidget);
    });
  });

  group('Month', () {
    testWidgets('calendar, week by week and tiles', (
      WidgetTester tester,
    ) async {
      final ReportTestApp app = seeded();
      await open(tester, app: app);
      final int loadsBefore = app.moods.loads;

      await tester.tap(find.text('Month'));
      await go(tester);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('Your month'), findsOneWidget);
      expect(find.text('Week by week'), findsOneWidget);
      expect(find.text('Average mood'), findsOneWidget);
      expect(find.text('days logged'), findsOneWidget);
      expect(find.text('calm time'), findsOneWidget);
      expect(find.text('20m'), findsOneWidget);

      // Back to the week: already loaded in this visit.
      final int loadsAfterMonth = app.moods.loads;
      expect(loadsAfterMonth, greaterThan(loadsBefore));
      await tester.tap(find.text('Week'));
      await go(tester);
      expect(app.moods.loads, loadsAfterMonth);
    });
  });

  group('What helped', () {
    testWidgets('shows comparison rows, before and after, harder days', (
      WidgetTester tester,
    ) async {
      await open(tester, app: seeded(), route: AppRoutes.reportsHelped);

      expect(find.text('What helped'), findsOneWidget);
      expect(find.text('Your mood on days when you…'), findsOneWidget);
      expect(find.text('Practised'), findsOneWidget);
      expect(find.text('Before and after practice'), findsOneWidget);
      expect(find.text('On harder days'), findsOneWidget);
      // 7 hard days (the Stressed days count too); Night shift on 2 of them
      // is under 60%, so the chip shows but not the sentence.
      expect(find.text('Night shift 2'), findsOneWidget);
      expect(find.textContaining('came up on'), findsNothing);
    });

    testWidgets('too little data hides the rows with a gentle line', (
      WidgetTester tester,
    ) async {
      final ReportTestApp app = ReportTestApp();
      app.moods.history.add(mood(DateTime(2026, 10, 7), 'Happy'));
      await open(tester, app: app, route: AppRoutes.reportsHelped);

      expect(
        find.text(
          'Log your mood on a few more days to see what goes together.',
        ),
        findsOneWidget,
      );
      expect(find.text('Before and after practice'), findsNothing);
      expect(find.text('On harder days'), findsNothing);
    });
  });

  group('Check-ins and writing', () {
    testWidgets('latest results and journal tone, no journal text', (
      WidgetTester tester,
    ) async {
      await open(tester, app: seeded(), route: AppRoutes.reportsCheckIns);

      expect(find.text('Latest check-ins'), findsOneWidget);
      expect(find.text('Low mood · Mild'), findsOneWidget);
      expect(find.text('PHQ-9 · 6 Oct'), findsOneWidget);
      expect(find.textContaining('Not taken in these 30 days'), findsOneWidget);
      expect(find.text('Journal tone'), findsOneWidget);
      expect(find.text('1 entry. Mostly mixed.'), findsOneWidget);
      expect(find.text('Team 1'), findsOneWidget);
      expect(
        find.text('Your journal text is never shown here.'),
        findsOneWidget,
      );
      expect(find.textContaining('Two admissions'), findsNothing);
    });
  });

  group('Share a summary', () {
    testWidgets('builds a PDF and opens the share sheet', (
      WidgetTester tester,
    ) async {
      final ReportTestApp app = await open(
        tester,
        app: seeded(),
        route: AppRoutes.reportsShare,
      );
      expect(find.text('Share a summary'), findsOneWidget);
      expect(find.text('1 month'), findsOneWidget);
      expect(
        find.text('Never included. Your writing stays private.'),
        findsOneWidget,
      );
      expect(find.textContaining('9 Sep to 8 Oct'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('Create PDF'));
        for (int i = 0; i < 40 && app.sharedFiles.isEmpty; i += 1) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }
      });
      await go(tester);
      expect(app.sharedFiles, <String>['MindMate-summary-2026-10-08.pdf']);
      expect(app.sharedBytes.single, isNotEmpty);
    });

    testWidgets('every switch off disables the button', (
      WidgetTester tester,
    ) async {
      await open(tester, app: seeded(), route: AppRoutes.reportsShare);
      for (final Element e in find.byType(Switch).evaluate().toList()) {
        await tester.tap(find.byWidget(e.widget));
        await go(tester, 200);
      }
      final Finder button = find.text('Create PDF');
      expect(button, findsOneWidget);
      // The GradientButton is disabled: tapping does nothing.
      await tester.tap(button, warnIfMissed: false);
      await go(tester);
      expect(find.text('Could not make the PDF'), findsNothing);
    });
  });
}
