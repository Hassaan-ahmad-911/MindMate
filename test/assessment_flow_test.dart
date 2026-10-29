import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Models/assessment_result.dart';
import 'package:mindmate/ui/app/app_routes.dart';

import 'helpers/assessment_app.dart';

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

Future<AssessmentTestApp> open(
  WidgetTester tester, {
  AssessmentTestApp? app,
  String route = AppRoutes.assessments,
  bool tall = false,
}) async {
  // A tall window keeps every row of the longer screens built.
  tester.view.physicalSize = Size(1170, tall ? 6000 : 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  ignoreOverflowErrors();
  final AssessmentTestApp a = app ?? AssessmentTestApp();
  await tester.pumpWidget(a.build(initialRoute: route));
  await go(tester);
  return a;
}

Future<void> tapText(WidgetTester tester, String text, [int ms = 400]) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.pump();
  await tester.tap(find.text(text).last);
  await go(tester, ms);
}

/// Picks [answer] and presses Next (or "See my result").
Future<void> answer(WidgetTester tester, String answer) async {
  await tapText(tester, answer, 100);
  final Finder next = find.text('Next').evaluate().isNotEmpty
      ? find.text('Next')
      : find.text('See my result');
  await tester.tap(next);
  await go(tester, 300);
}

AssessmentResult phqResult(double total, String band, DateTime at) {
  return AssessmentResult(
    id: 'saved-${at.millisecondsSinceEpoch}',
    assessmentId: 'phq9',
    contentVersion: 1,
    answers: const <int>[1, 1, 1, 1, 1, 1, 1, 1, 0],
    total: total,
    bandId: band,
    startedAt: at,
    completedAt: at,
  );
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  group('The hub', () {
    testWidgets('suggests the first check-in not taken and shows ranges', (
      WidgetTester tester,
    ) async {
      final AssessmentTestApp app = AssessmentTestApp();
      app.service.stored.add(phqResult(11, 'moderate', DateTime(2026, 10, 1)));
      await open(tester, app: app, tall: true);

      expect(find.text('Check-ins'), findsOneWidget);
      expect(find.text('SUGGESTED THIS WEEK'), findsOneWidget);
      expect(find.text('Burnout check'), findsOneWidget);
      expect(
        find.text('You have not taken it yet. 19 questions, about 4 minutes.'),
        findsOneWidget,
      );
      expect(find.text('MOOD AND WORRY'), findsOneWidget);
      expect(find.text('PHQ-9 · 9 questions'), findsOneWidget);
      expect(find.text('Moderate'), findsOneWidget);
      expect(find.text('Not taken'), findsNWidgets(5));
      expect(
        find.text(
          'Your answers are private. Results help you spot changes over time.',
        ),
        findsOneWidget,
      );
    });
  });

  group('PHQ-9', () {
    testWidgets(
      'question 9 above 0: support screen, difficulty, then the result card',
      (WidgetTester tester) async {
        final AssessmentTestApp app = await open(tester, tall: true);

        await tapText(tester, 'Low mood');
        expect(find.text('Low mood check'), findsOneWidget);
        expect(
          find.text('PHQ-9 · 9 questions · about 2 minutes'),
          findsOneWidget,
        );
        expect(find.text('Only you can see your answers'), findsOneWidget);
        await tapText(tester, 'Start');

        expect(find.text('1 of 9'), findsOneWidget);
        expect(
          find.text(
            'Over the last 2 weeks, how often have you been bothered by any '
            'of the following problems?',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Little interest or pleasure in doing things'),
          findsOneWidget,
        );
        for (int i = 0; i < 8; i += 1) {
          await answer(tester, i < 2 ? 'Several days' : 'Not at all');
        }
        expect(find.text('9 of 9'), findsOneWidget);
        expect(
          find.text(
            'Thoughts that you would be better off dead, or of hurting '
            'yourself in some way',
          ),
          findsOneWidget,
        );
        await answer(tester, 'Several days');

        // The support screen, before anything else.
        expect(find.text('Thank you for telling us'), findsOneWidget);
        expect(find.text('Talk to someone now'), findsOneWidget);
        await tapText(tester, 'Reach out to someone you trust');
        expect(app.share.shared, <String>['Hi, are you free to talk today?']);

        await tapText(tester, "I'm safe, continue");
        expect(find.text('One more'), findsOneWidget);
        expect(
          find.textContaining('how difficult have they made'),
          findsOneWidget,
        );
        await answer(tester, 'Somewhat difficult');
        await go(tester, 1200);

        // The result, with the support card whatever the total.
        expect(
          find.text(
            'You told us about thoughts of hurting yourself. Please talk to '
            'someone today.',
          ),
          findsOneWidget,
        );
        expect(find.text('3'), findsOneWidget);
        expect(find.text('out of 27'), findsOneWidget);
        expect(find.text('Minimal range'), findsOneWidget);
        expect(
          find.text('This is a screening result, not a diagnosis.'),
          findsOneWidget,
        );

        final AssessmentResult saved = app.service.stored.single;
        expect(saved.assessmentId, 'phq9');
        expect(saved.answers, <int>[1, 1, 0, 0, 0, 0, 0, 0, 1]);
        expect(saved.extraAnswers, <String, int>{'difficulty': 1});
        expect(saved.total, 3);
        expect(saved.bandId, 'minimal');

        await tapText(tester, 'Review my answers');
        expect(find.text('Take it again'), findsOneWidget);
        expect(find.text('Somewhat difficult'), findsOneWidget);
        await tester.tapAt(const Offset(20, 20));
        await go(tester);

        await tester.tap(find.text('Done'));
        await go(tester);
        expect(
          find.text('Support is here whenever you need it.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('going back does not show the support screen twice', (
      WidgetTester tester,
    ) async {
      await open(tester, route: '/assessments/phq9');
      await tapText(tester, 'Start');
      for (int i = 0; i < 8; i += 1) {
        await answer(tester, 'Not at all');
      }
      await answer(tester, 'Nearly every day');
      expect(find.text('Thank you for telling us'), findsOneWidget);

      await tapText(tester, "I'm safe, continue");
      // Back from the difficulty question to question 9.
      await tapText(tester, 'Back');
      expect(find.text('9 of 9'), findsOneWidget);
      await answer(tester, 'Several days');
      expect(find.text('Thank you for telling us'), findsNothing);
      expect(find.text('One more'), findsOneWidget);
    });

    testWidgets('"Stop the check here" saves nothing and opens support', (
      WidgetTester tester,
    ) async {
      final AssessmentTestApp app = await open(
        tester,
        route: '/assessments/phq9',
      );
      await tapText(tester, 'Start');
      for (int i = 0; i < 8; i += 1) {
        await answer(tester, 'Not at all');
      }
      await answer(tester, 'Several days');
      await tapText(tester, 'Stop the check here');

      expect(find.text('PAGE ${AppRoutes.support}'), findsOneWidget);
      expect(app.service.stored, isEmpty);
      expect(app.repository.item9PositiveThisSession, isTrue);
    });

    testWidgets('all "Not at all": no difficulty question, no support', (
      WidgetTester tester,
    ) async {
      final AssessmentTestApp app = await open(
        tester,
        route: '/assessments/phq9',
      );
      await tapText(tester, 'Start');
      for (int i = 0; i < 8; i += 1) {
        await answer(tester, 'Not at all');
      }
      expect(find.text('See my result'), findsOneWidget);
      await answer(tester, 'Not at all');
      await go(tester, 1200);

      expect(find.text('Minimal range'), findsOneWidget);
      expect(find.textContaining('thoughts of hurting'), findsNothing);
      expect(app.service.stored.single.extraAnswers, isEmpty);
    });

    testWidgets('leaving midway asks first and saves nothing', (
      WidgetTester tester,
    ) async {
      final AssessmentTestApp app = await open(tester);
      await tapText(tester, 'Low mood');
      await tapText(tester, 'Start');
      await answer(tester, 'Several days');

      await tester.tap(find.byTooltip('Close'));
      await go(tester, 300);
      expect(find.text('Leave this check-in?'), findsOneWidget);
      await tester.tap(find.text('Keep going'));
      await go(tester, 300);
      expect(find.text('2 of 9'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await go(tester, 300);
      await tester.tap(find.text('Leave'));
      await go(tester);
      expect(Get.currentRoute, AppRoutes.assessments);
      expect(find.text('Low mood'), findsOneWidget);
      expect(app.service.stored, isEmpty);
    });

    testWidgets('a result shows the change since the last one', (
      WidgetTester tester,
    ) async {
      final AssessmentTestApp app = AssessmentTestApp();
      app.service.stored.add(phqResult(14, 'moderate', DateTime(2026, 9, 24)));
      await open(tester, app: app, route: '/assessments/phq9', tall: true);
      await tapText(tester, 'Start');
      for (int i = 0; i < 9; i += 1) {
        await answer(tester, i < 5 ? 'More than half the days' : 'Not at all');
      }
      await answer(tester, 'Very difficult');
      await go(tester, 1200);

      expect(find.text('10'), findsOneWidget);
      expect(find.text('Moderate range'), findsOneWidget);
      expect(find.text('4 since 24 Sep'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
      expect(
        find.text(
          'A score of 10 or more is a good reason to talk with a doctor or '
          'counsellor.',
        ),
        findsOneWidget,
      );
      expect(find.text('Self-compassion break'), findsOneWidget);
    });
  });

  group('Area results', () {
    testWidgets('CBI shows three areas, highest first, and no total', (
      WidgetTester tester,
    ) async {
      final AssessmentTestApp app = await open(
        tester,
        route: '/assessments/cbi',
        tall: true,
      );
      expect(find.text('Burnout check'), findsOneWidget);
      await tapText(tester, 'Start');
      // The CBI uses two answer sets; each item shows its own.
      const List<String> answers = <String>[
        ...<String>['Sometimes', 'Sometimes', 'Sometimes'],
        ...<String>['Sometimes', 'Sometimes', 'Sometimes'],
        ...<String>['To a high degree', 'To a high degree', 'To a high degree'],
        ...<String>['Often', 'Often', 'Often', 'Often'],
        ...<String>['To a low degree', 'To a low degree'],
        ...<String>['To a low degree', 'To a low degree'],
        ...<String>['Seldom', 'Seldom'],
      ];
      for (final String a in answers) {
        await answer(tester, a);
      }
      await go(tester, 1200);

      expect(find.text('Your three areas'), findsOneWidget);
      expect(
        find.text('Work is where you feel most drained right now.'),
        findsOneWidget,
      );
      expect(find.text('Tiredness linked to your job'), findsOneWidget);
      expect(
        find.text(
          'Lines mark 50 and 75. These are common guides, not official '
          'cut-offs. The CBI has no overall score.',
        ),
        findsOneWidget,
      );
      final AssessmentResult saved = app.service.stored.single;
      expect(saved.total, isNull);
      expect(saved.areas!['personal'], 50);
      expect(saved.areas!['patients'], 25);
      expect(find.text('Leaving work at work'), findsOneWidget);
    });

    testWidgets('workplace shows five areas and the overall percentage', (
      WidgetTester tester,
    ) async {
      await open(tester, route: '/assessments/workplace', tall: true);
      await tapText(tester, 'Start');
      for (int i = 0; i < 15; i += 1) {
        await answer(tester, 'Neutral');
      }
      await go(tester, 1200);

      expect(find.text('Your five areas'), findsOneWidget);
      expect(find.text('Overall 50% · Needs Attention'), findsOneWidget);
      expect(
        find.text('A MindMate questionnaire, not a clinical scale.'),
        findsOneWidget,
      );
    });
  });

  group('Over time', () {
    testWidgets('lists results with changes and opens one read-only', (
      WidgetTester tester,
    ) async {
      final AssessmentTestApp app = AssessmentTestApp();
      app.service.stored
        ..add(phqResult(15, 'moderately_severe', DateTime(2026, 9, 10)))
        ..add(phqResult(14, 'moderate', DateTime(2026, 9, 24)))
        ..add(phqResult(11, 'moderate', DateTime(2026, 10, 8, 8)));
      await open(tester, app: app, route: AppRoutes.assessmentHistory);

      expect(find.text('Over time'), findsOneWidget);
      expect(find.text('PHQ-9 score'), findsOneWidget);
      expect(find.text('Lower is better'), findsOneWidget);
      expect(find.text('Today, 8 Oct'), findsOneWidget);
      expect(find.text('−3'), findsOneWidget);
      expect(find.text('Moderately severe'), findsOneWidget);
      expect(
        find.text('Next suggested: in 14 days, around 22 Oct'),
        findsOneWidget,
      );

      await tapText(tester, 'Today, 8 Oct', 1200);
      expect(find.text('out of 27'), findsOneWidget);
      expect(find.text('3 since 24 Sep'), findsOneWidget);
    });

    testWidgets('WHO-5 starts with the first check-in', (
      WidgetTester tester,
    ) async {
      final AssessmentTestApp app = AssessmentTestApp();
      app.service.initialWho5 = InitialWho5(
        score: 44,
        completedAt: DateTime(2026, 9, 1),
      );
      await open(tester, app: app, route: AppRoutes.assessmentHistory);
      await tester.scrollUntilVisible(
        find.text('Wellbeing'),
        120,
        scrollable: find.byWidgetPredicate(
          (Widget w) =>
              w is Scrollable && w.axisDirection == AxisDirection.right,
        ),
      );
      await tapText(tester, 'Wellbeing');

      expect(find.text('First check-in'), findsOneWidget);
      expect(find.text('Higher is better'), findsOneWidget);
    });

    testWidgets('with no results it invites the first one', (
      WidgetTester tester,
    ) async {
      await open(tester, route: AppRoutes.assessmentHistory);
      expect(
        find.text('Take this check-in to start seeing changes over time.'),
        findsOneWidget,
      );
    });
  });
}
