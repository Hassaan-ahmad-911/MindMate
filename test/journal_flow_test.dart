import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Models/journal_content.dart';
import 'package:mindmate/Models/journal_model.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'helpers/journal_app.dart';
import 'helpers/journal_fakes.dart';

/// The text in these tests is wider than the real font, which can overflow a
/// row. Overflow is not what these tests are about, so it is left out.
void ignoreOverflowErrors() {
  final FlutterExceptionHandler? original = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (!details.exceptionAsString().contains('overflowed')) {
      original?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = original);
}

Future<void> go(WidgetTester tester, [int milliseconds = 700]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: milliseconds));
}

Future<JournalTestApp> open(
  WidgetTester tester, {
  JournalTestApp? app,
  String route = AppRoutes.journal,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  ignoreOverflowErrors();

  final JournalTestApp journal = app ?? JournalTestApp();
  await tester.pumpWidget(journal.build(initialRoute: route));
  await go(tester);
  return journal;
}

/// From Journal home, through "How do you want to write?", to the editor.
Future<void> startWriting(WidgetTester tester, {String? template}) async {
  await tester.tap(find.byIcon(Icons.edit_rounded));
  await go(tester);
  if (template != null) {
    await tester.ensureVisible(find.text(template));
    await go(tester, 300);
    await tester.tap(find.text(template));
    await go(tester, 300);
  }
  await tester.tap(find.text('Start writing'));
  await go(tester);
}

Map<String, dynamic> stored(JournalTestApp app) =>
    app.service.entries.values.single;

const String happened =
    'Two admissions back to back and a family who needed more time than I '
    'had. I felt rushed all night.';
const String didWell =
    'I stayed calm with the family and explained the plan twice. Sara '
    'covered my break, so I said thank you.';
const String leaving =
    'The feeling that I should have done more. I did what one person could '
    'do.';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  group('Journal home', () {
    testWidgets('shows the prompt card and entries grouped by day', (
      WidgetTester tester,
    ) async {
      final JournalTestApp app = JournalTestApp();
      app.service.addEntry(
        journalEntry(
          id: 'a',
          createdAt: DateTime(2026, 10, 8, 21),
          moodLabel: 'Tired',
        ),
      );
      app.service.addEntry(
        journalEntry(
          id: 'b',
          title: 'A quiet rest day',
          type: JournalTypes.free,
          createdAt: DateTime(2026, 10, 7, 18, 5),
          tone: JournalTone.light,
        ),
      );
      await open(tester, app: app);

      expect(find.text('Journal'), findsOneWidget);
      expect(find.text('Private. Only you can see it.'), findsOneWidget);
      expect(find.text("TONIGHT'S PROMPT"), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('YESTERDAY'), findsOneWidget);
      expect(find.text('Long night on Ward 4'), findsOneWidget);
      expect(find.text('21:00 · After shift'), findsOneWidget);
      expect(find.text('Mixed'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(app.service.migrated, isTrue);

      // The last chip is off to the right until the row is scrolled.
      await tester.scrollUntilVisible(
        find.text('Free write'),
        120,
        scrollable: find.byWidgetPredicate(
          (Widget w) =>
              w is Scrollable && w.axisDirection == AxisDirection.right,
        ),
      );
      await go(tester, 300);
      await tester.tap(find.text('Free write'));
      await go(tester);
      expect(find.text('Long night on Ward 4'), findsNothing);
      expect(find.text('A quiet rest day'), findsOneWidget);
    });

    testWidgets('search filters by title and text', (
      WidgetTester tester,
    ) async {
      final JournalTestApp app = JournalTestApp();
      app.service.addEntry(journalEntry(id: 'a'));
      app.service.addEntry(
        journalEntry(
          id: 'b',
          title: 'Rest day',
          body: 'Walked to the market with Ammi.',
          createdAt: DateTime(2026, 10, 7),
        ),
      );
      await open(tester, app: app);

      await tester.tap(find.byTooltip('Search'));
      await go(tester, 300);
      await tester.enterText(find.byType(TextField), 'ammi');
      await go(tester, 300);
      expect(find.text('Rest day'), findsOneWidget);
      expect(find.text('Long night on Ward 4'), findsNothing);
    });

    testWidgets('an empty journal invites the first entry', (
      WidgetTester tester,
    ) async {
      await open(tester);
      expect(
        find.text('Your journal is empty.\nWrite your first entry tonight.'),
        findsOneWidget,
      );
      expect(find.text("TONIGHT'S PROMPT"), findsOneWidget);
    });

    testWidgets('a failed load offers to try again', (
      WidgetTester tester,
    ) async {
      final JournalTestApp app = JournalTestApp()..service.failLoading = true;
      await open(tester, app: app);
      expect(find.text('Your journal did not load'), findsOneWidget);

      app.service.failLoading = false;
      await tester.tap(find.text('Try again'));
      await go(tester);
      expect(find.text('Your journal did not load'), findsNothing);
    });
  });

  group('Writing', () {
    testWidgets('an after-shift debrief is saved with its tone and mood', (
      WidgetTester tester,
    ) async {
      final JournalTestApp app = JournalTestApp(
        todayMood: JournalTestApp.tiredModerate(),
      );
      await open(tester, app: app);
      await startWriting(tester);

      expect(find.text('After-shift debrief'), findsOneWidget);
      expect(find.text('What happened today?'), findsOneWidget);
      expect(find.text('Tired · Moderate'), findsOneWidget);
      expect(find.text('Thursday 8 October · 21:40'), findsOneWidget);

      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Long night on Ward 4');
      await tester.enterText(fields.at(1), happened);
      await tester.enterText(fields.at(2), didWell);
      await tester.enterText(fields.at(3), leaving);
      await go(tester, 200);
      expect(find.text('55 words'), findsOneWidget);

      await tester.tap(find.text('Save entry'));
      await go(tester, 900);

      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('After-shift debrief · 21:40'), findsOneWidget);
      expect(find.text('Mixed'), findsOneWidget);
      expect(
        find.text('Some hard moments, and some good ones too.'),
        findsOneWidget,
      );
      expect(find.text('Leaving work at work'), findsOneWidget);

      final Map<String, dynamic> doc = stored(app);
      expect(doc['type'], 'after_shift');
      expect(doc['tone'], 'mixed');
      expect(doc['moodLabel'], 'Tired');
      expect(doc['moodIntensity'], 'Moderate');
      expect(doc['moodId'], 'mood-1');
      expect((doc['answers'] as List<dynamic>).length, 3);
      expect(app.drafts.drafts, isEmpty);

      await tester.tap(find.text('Done'));
      await go(tester);
      expect(find.text('Long night on Ward 4'), findsOneWidget);
    });

    testWidgets('support wording shows the support card instead of the tone', (
      WidgetTester tester,
    ) async {
      final JournalTestApp app = JournalTestApp();
      await open(tester, app: app);
      await startWriting(tester, template: 'Free write');

      await tester.enterText(
        find.byType(TextField).at(1),
        'Exhausted after another awful shift. Some nights I just want to end '
        'it all.',
      );
      await tester.tap(find.text('Save entry'));
      await go(tester, 900);

      expect(find.text('Thank you for writing this down.'), findsOneWidget);
      expect(find.text('Talk to someone now'), findsOneWidget);
      expect(find.text('Breathe with me first'), findsOneWidget);
      expect(find.text('TONE OF THIS ENTRY'), findsNothing);
      // Saved normally, with its tone, and nothing else stored.
      final Map<String, dynamic> doc = stored(app);
      expect(doc['tone'], 'heavy');
      expect(doc.keys.where((String k) => k.contains('support')), isEmpty);

      await tester.tap(find.text('Talk to someone now'));
      await go(tester);
      expect(find.text('PAGE ${AppRoutes.support}'), findsOneWidget);
    });

    testWidgets('a draft is kept on close and offered again', (
      WidgetTester tester,
    ) async {
      final JournalTestApp app = JournalTestApp();
      await open(tester, app: app);
      await startWriting(tester, template: 'Free write');

      await tester.enterText(find.byType(TextField).at(1), 'Half a thought');
      await go(tester, 1200);
      expect(find.text('Draft saved'), findsOneWidget);
      expect(app.drafts.drafts.values.single.body, 'Half a thought');

      await tester.tap(find.byTooltip('Close'));
      await go(tester, 300);
      expect(find.text('Keep this as a draft?'), findsOneWidget);
      await tester.tap(find.text('Keep draft'));
      await go(tester);
      expect(app.drafts.drafts, hasLength(1));

      await tester.tap(find.byIcon(Icons.edit_rounded));
      await go(tester, 300);
      expect(find.text('Continue your draft?'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await go(tester);
      expect(find.text('Half a thought'), findsOneWidget);
      expect(find.text('Free write'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await go(tester, 300);
      await tester.tap(find.text('Discard'));
      await go(tester);
      expect(app.drafts.drafts, isEmpty);
    });

    testWidgets('changing the type keeps the text', (
      WidgetTester tester,
    ) async {
      await open(tester);
      await startWriting(tester);

      await tester.enterText(find.byType(TextField).at(1), 'First answer');
      await tester.tap(find.byTooltip('Change how you write'));
      await go(tester, 400);
      await tester.tap(find.text('Free write').last);
      await go(tester, 400);

      expect(find.text('What happened today?'), findsNothing);
      expect(find.text('First answer'), findsOneWidget);
    });
  });

  group('Let it out', () {
    testWidgets('letting go saves nothing and clears the draft', (
      WidgetTester tester,
    ) async {
      final JournalTestApp app = JournalTestApp();
      await open(tester, app: app);
      await startWriting(tester, template: 'Let it out');

      await tester.enterText(
        find.byType(TextField).at(1),
        'Nobody listened today and I am tired of it',
      );
      await tester.tap(find.text('Done'));
      await go(tester);
      expect(find.text('Keep it, or\nlet it go?'), findsOneWidget);
      expect(find.text('listened'), findsOneWidget);

      await tester.tap(find.text('Let it go'));
      await go(tester, 2700);
      await go(tester);

      expect(find.text('Journal'), findsOneWidget);
      expect(app.service.entries, isEmpty);
      expect(app.drafts.drafts, isEmpty);
    });

    testWidgets('keeping it saves it as Let it out', (
      WidgetTester tester,
    ) async {
      final JournalTestApp app = JournalTestApp();
      await open(tester, app: app);
      await startWriting(tester, template: 'Let it out');

      await tester.enterText(find.byType(TextField).at(1), 'A rough day.');
      await tester.tap(find.text('Done'));
      await go(tester);
      await tester.tap(find.text('Keep it in my journal'));
      await go(tester, 900);

      expect(find.text('Saved'), findsOneWidget);
      expect(stored(app)['type'], 'let_it_out');
      expect(app.drafts.drafts, isEmpty);
    });

    testWidgets('support wording shows the card before choosing', (
      WidgetTester tester,
    ) async {
      final JournalTestApp app = JournalTestApp();
      await open(tester, app: app);
      await startWriting(tester, template: 'Let it out');

      await tester.enterText(
        find.byType(TextField).at(1),
        'I cant go on like this',
      );
      await tester.tap(find.text('Done'));
      await go(tester, 900);
      // The sheet opens once the screen is up.
      await go(tester, 600);

      expect(find.text('Thank you for writing this down.'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await go(tester);
      expect(find.text('Keep it, or\nlet it go?'), findsOneWidget);
      expect(app.service.entries, isEmpty);
    });
  });

  group('Reading an entry', () {
    JournalModel guided() {
      return journalEntry(
        id: 'g1',
        createdAt: DateTime(2026, 10, 8, 20),
        body: '$happened\n\n$didWell',
        topics: <String>['Team'],
        moodLabel: 'Tired',
      ).copyWith(
        answers: const <JournalAnswer>[
          JournalAnswer(
            questionId: 'happened',
            question: 'What happened today?',
            text: happened,
          ),
          JournalAnswer(
            questionId: 'did_well',
            question: 'What did I do well?',
            text: didWell,
          ),
          JournalAnswer(
            questionId: 'leaving',
            question: 'What am I leaving at work?',
            text: '',
          ),
        ],
      );
    }

    testWidgets('shows the answers, edits and deletes', (
      WidgetTester tester,
    ) async {
      final JournalTestApp app = JournalTestApp();
      app.service.addEntry(guided());
      for (int i = 1; i <= 3; i += 1) {
        app.service.addEntry(
          journalEntry(
            id: 'team-$i',
            title: 'Team $i',
            createdAt: DateTime(2026, 10, i, 9),
            topics: <String>['Team'],
          ),
        );
      }
      await open(tester, app: app);

      await tester.tap(find.text('Long night on Ward 4'));
      await go(tester);
      expect(find.text('What happened today?'), findsOneWidget);
      expect(find.text('What did I do well?'), findsOneWidget);
      expect(
        find.text('What am I leaving at work?'),
        findsNothing,
        reason: 'empty answers are left out',
      );
      expect(find.text('Edited 21:40'), findsNothing);
      expect(
        find.textContaining('in 4 entries this month.', findRichText: true),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Edit'));
      await go(tester);
      expect(find.text('Save changes'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'A better title');
      await tester.tap(find.text('Save changes'));
      await go(tester, 900);

      expect(find.text('A better title'), findsOneWidget);
      expect(find.text('Edited 21:40'), findsOneWidget);
      expect(app.service.entries['g1']!['title'], 'A better title');

      await tester.tap(find.byTooltip('Delete'));
      await go(tester, 300);
      expect(find.text('Delete this entry?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await go(tester, 900);

      expect(app.service.entries.containsKey('g1'), isFalse);
      expect(find.text('A better title'), findsNothing);
      expect(find.text('Entry deleted'), findsOneWidget);
    });

    testWidgets('an old entry gets its tone the first time it is opened', (
      WidgetTester tester,
    ) async {
      final JournalTestApp app = JournalTestApp();
      app.service.entries['old'] = <String, dynamic>{
        'title': 'Old entry',
        'content': 'Exhausted and stressed after a terrible night.',
        'moodLabel': 'Neutral',
        'createdAt': Timestamp.fromDate(DateTime(2026, 9, 2, 22)),
      };
      await open(tester, app: app);
      expect(find.text('Heavy'), findsNothing);

      await tester.tap(find.text('Old entry'));
      await go(tester);
      expect(find.text('Heavy'), findsOneWidget);
      expect(find.text('Okay'), findsOneWidget);
      expect(app.service.entries['old']!['tone'], 'heavy');
      expect(app.service.entries['old']!['wordCount'], 7);
    });
  });

  group('Your writing', () {
    testWidgets('shows the month in tiles and charts', (
      WidgetTester tester,
    ) async {
      final JournalTestApp app = JournalTestApp();
      app.service.addEntry(
        journalEntry(
          id: '1',
          createdAt: DateTime(2026, 10, 1, 21),
          tone: JournalTone.heavy,
          topics: <String>['Team', 'Night shift'],
        ),
      );
      app.service.addEntry(
        journalEntry(
          id: '2',
          createdAt: DateTime(2026, 10, 2, 21),
          topics: <String>['Team'],
        ),
      );
      app.service.addEntry(
        journalEntry(
          id: '3',
          createdAt: DateTime(2026, 10, 8, 21),
          tone: JournalTone.light,
        ),
      );
      app.service.addEntry(
        journalEntry(id: 'sept', createdAt: DateTime(2026, 9, 20)),
      );
      await open(tester, app: app, route: AppRoutes.journalInsights);

      expect(find.text('Your writing'), findsOneWidget);
      expect(find.text('October'), findsOneWidget);
      expect(find.text('3'), findsNWidgets(2), reason: 'entries and days');
      expect(find.text('entries'), findsOneWidget);
      expect(find.text('days written'), findsOneWidget);
      expect(find.text('Tone by week'), findsOneWidget);
      expect(find.text('Week 5'), findsOneWidget);
      expect(find.text('What you wrote about'), findsOneWidget);
      expect(find.text('Night shift'), findsOneWidget);
      expect(
        find.text(
          'Worked out on your phone from your own words. Not a diagnosis.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Previous month'));
      await go(tester);
      expect(find.text('September'), findsOneWidget);
      expect(
        find.text('Write a few more entries this month to see your patterns.'),
        findsOneWidget,
      );
    });
  });
}
