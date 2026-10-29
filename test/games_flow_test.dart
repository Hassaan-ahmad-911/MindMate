import 'dart:math';
import 'dart:ui' show AccessibilityFeatures;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Models/break_log.dart';
import 'package:mindmate/Models/breath_round.dart';
import 'package:mindmate/Models/calm_match_game.dart';
import 'package:mindmate/Models/gratitude_entry.dart';
import 'package:mindmate/ui/app/app_routes.dart';
import 'package:mindmate/ui/games/breathing_bubble_viewmodel.dart';
import 'package:mindmate/ui/games/calm_match_viewmodel.dart';
import 'package:mindmate/ui/games/gratitude_garden_viewmodel.dart';
import 'package:mindmate/ui/shared/gradient_button.dart';

import 'helpers/games_app.dart';
import 'helpers/games_fakes.dart';

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

Future<void> go(WidgetTester tester, [int milliseconds = 600]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: milliseconds));
}

Future<GamesTestApp> open(
  WidgetTester tester, {
  String route = AppRoutes.games,
  GamesTestApp? app,
}) async {
  tester.view.physicalSize = const Size(1170, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  ignoreOverflowErrors();

  final GamesTestApp games = app ?? GamesTestApp(random: Random(1));
  await tester.pumpWidget(games.build(initialRoute: route));
  await go(tester);
  return games;
}

bool buttonEnabled(WidgetTester tester) {
  return tester.widget<GradientButton>(find.byType(GradientButton)).onPressed !=
      null;
}

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  group('Take a break hub', () {
    testWidgets('shows the three activities and the calm wording', (
      WidgetTester tester,
    ) async {
      await open(tester);

      expect(find.text('Take a break'), findsOneWidget);
      expect(
        find.text('Short, calm activities. No scores, no timers.'),
        findsOneWidget,
      );
      expect(find.text('Breathing bubble'), findsOneWidget);
      expect(find.text('Calm match'), findsOneWidget);
      expect(find.text('Gratitude garden'), findsOneWidget);
      expect(find.text('2 min'), findsOneWidget);
      expect(find.text('3 min'), findsOneWidget);
    });

    testWidgets('the footer counts this week\'s breaks', (
      WidgetTester tester,
    ) async {
      final FakeBreakService breaks = FakeBreakService();
      for (int i = 0; i < 4; i += 1) {
        breaks.stored.add(
          BreakLogEntry(
            id: 'b$i',
            activity: BreakActivity.calmMatch,
            startedAt: DateTime.now().subtract(Duration(hours: i + 1)),
            seconds: 60,
            completed: true,
          ),
        );
      }
      await open(tester, app: GamesTestApp(breaks: breaks));

      expect(find.text('4'), findsOneWidget);
      expect(
        find.text('breaks taken this week. A few minutes for yourself counts.'),
        findsOneWidget,
      );
    });

    testWidgets('the garden chip changes once today\'s flower is planted', (
      WidgetTester tester,
    ) async {
      await open(tester);
      expect(find.text('Today\'s flower is waiting'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      Get.reset();
      Get.testMode = true;
      final FakeGratitudeService planted = FakeGratitudeService();
      planted.store[GratitudeRules.dateKey(DateTime.now())] = entryOn(
        DateTime.now(),
        'Done',
      );
      await open(tester, app: GamesTestApp(gratitude: planted));

      expect(find.text('Planted today'), findsOneWidget);
      expect(find.text('Today\'s flower is waiting'), findsNothing);
    });

    testWidgets('opens each activity', (WidgetTester tester) async {
      await open(tester);

      await tester.tap(find.text('Calm match'));
      await go(tester);
      expect(find.text('Take your time. There is no clock.'), findsOneWidget);

      Get.back<void>();
      await go(tester);
      await tester.tap(find.text('Breathing bubble'));
      await go(tester);
      expect(find.text('Press and hold anywhere'), findsOneWidget);

      Get.back<void>();
      await go(tester);
      await tester.tap(find.text('Gratitude garden'));
      await go(tester);
      expect(find.text('What is one good thing from today?'), findsOneWidget);
    });
  });

  group('Breathing bubble screen', () {
    Future<void> openBubble(WidgetTester tester, GamesTestApp app) =>
        open(tester, route: AppRoutes.breathingBubble, app: app);

    testWidgets('hold to the ring, let go, and the breath counts', (
      WidgetTester tester,
    ) async {
      await openBubble(tester, GamesTestApp());
      final BreathingBubbleViewModel vm = Get.find<BreathingBubbleViewModel>();
      expect(find.text('BREATH 1 OF 8'), findsOneWidget);
      expect(find.text('Breathe in'), findsOneWidget);

      final TestGesture hold = await tester.startGesture(
        tester.getCenter(find.byType(Scaffold)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(vm.phase.value, BreathPhase.inhaling);
      expect(
        find.text('Keep holding until the bubble fills the ring.'),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump();
      expect(vm.phase.value, BreathPhase.full);
      expect(find.text('Let go'), findsOneWidget);

      // Holding on changes nothing.
      await tester.pump(const Duration(seconds: 3));
      expect(vm.phase.value, BreathPhase.full);

      await hold.up();
      await tester.pump();
      expect(find.text('Breathe out'), findsOneWidget);
      expect(vm.completed.value, 0);

      await tester.pump(const Duration(milliseconds: 6100));
      await tester.pump();
      expect(vm.completed.value, 1);
      expect(vm.phase.value, BreathPhase.ready);
      expect(find.text('BREATH 2 OF 8'), findsOneWidget);
    });

    testWidgets('letting go early shrinks the bubble and does not count', (
      WidgetTester tester,
    ) async {
      await openBubble(tester, GamesTestApp());
      final BreathingBubbleViewModel vm = Get.find<BreathingBubbleViewModel>();

      final TestGesture hold = await tester.startGesture(
        tester.getCenter(find.byType(Scaffold)),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await hold.up();
      await tester.pump();

      expect(vm.phase.value, BreathPhase.shrinking);
      expect(find.text('Hold a little longer'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(vm.phase.value, BreathPhase.ready);
      expect(vm.completed.value, 0);
      expect(find.text('BREATH 1 OF 8'), findsOneWidget);
    });

    testWidgets('a press while the bubble floats away is ignored', (
      WidgetTester tester,
    ) async {
      await openBubble(tester, GamesTestApp());
      final BreathingBubbleViewModel vm = Get.find<BreathingBubbleViewModel>();
      final Offset centre = tester.getCenter(find.byType(Scaffold));

      final TestGesture hold = await tester.startGesture(centre);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4100));
      await tester.pump();
      await hold.up();
      await tester.pump(const Duration(seconds: 1));

      final TestGesture again = await tester.startGesture(centre);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(vm.phase.value, BreathPhase.exhaling);
      await again.up();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(vm.completed.value, 1);
    });

    testWidgets('eight breaths end on Nicely done with Again and Done', (
      WidgetTester tester,
    ) async {
      final GamesTestApp app = GamesTestApp();
      await openBubble(tester, app);
      final BreathingBubbleViewModel vm = Get.find<BreathingBubbleViewModel>();
      final Offset centre = tester.getCenter(find.byType(Scaffold));

      for (int i = 0; i < 8; i += 1) {
        final TestGesture hold = await tester.startGesture(centre);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 4100));
        await tester.pump();
        await hold.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 6100));
        await tester.pump();
      }

      expect(vm.isFinished, isTrue);
      expect(find.text('Nicely done'), findsOneWidget);
      expect(find.text('Again'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(app.breaks.saved, hasLength(1));
      expect(app.breaks.saved.single.completed, isTrue);

      await tester.tap(find.text('Again'));
      await go(tester);
      expect(find.text('BREATH 1 OF 8'), findsOneWidget);
    });

    testWidgets('works the same with reduce-motion on', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const _ReducedMotion();
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await openBubble(tester, GamesTestApp());
      final BreathingBubbleViewModel vm = Get.find<BreathingBubbleViewModel>();

      final TestGesture hold = await tester.startGesture(
        tester.getCenter(find.byType(Scaffold)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 4100));
      await tester.pump();
      expect(vm.phase.value, BreathPhase.full);
      await hold.up();
      await tester.pump(const Duration(milliseconds: 3000));
      expect(find.byType(Transform), findsWidgets);
      await tester.pump(const Duration(milliseconds: 3200));
      await tester.pump();

      expect(vm.completed.value, 1);
    });
  });

  group('Calm match screen', () {
    testWidgets('shows 12 face-down cards and the counters', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await open(tester, route: AppRoutes.calmMatch);

      expect(find.bySemanticsLabel('Face-down card'), findsNWidgets(12));
      expect(find.text('0 of 6 pairs'), findsOneWidget);
      expect(find.text('0 turns'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('tapping a card flips it and says what it shows', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await open(tester, route: AppRoutes.calmMatch);
      final CalmMatchViewModel vm = Get.find<CalmMatchViewModel>();
      final String name = vm.symbolAt(0).label;

      await tester.tap(find.bySemanticsLabel('Face-down card').first);
      await tester.pump(const Duration(milliseconds: 400));

      expect(vm.faces[0], CardFace.up);
      expect(find.bySemanticsLabel('Face up: $name'), findsOneWidget);
      expect(find.bySemanticsLabel('Face-down card'), findsNWidgets(11));
      semantics.dispose();
    });

    testWidgets('two that do not match flip back after 0.9 seconds', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await open(tester, route: AppRoutes.calmMatch);
      final CalmMatchViewModel vm = Get.find<CalmMatchViewModel>();
      int second = 1;
      while (vm.symbolAt(second) == vm.symbolAt(0)) {
        second += 1;
      }

      vm.flip(0);
      vm.flip(second);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('1 turn'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Face up: ')), findsNWidgets(2));

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('Face-down card'), findsNWidgets(12));
      semantics.dispose();
    });

    testWidgets('matched cards are labelled Matched', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await open(tester, route: AppRoutes.calmMatch);
      final CalmMatchViewModel vm = Get.find<CalmMatchViewModel>();
      int second = 1;
      while (vm.symbolAt(second) != vm.symbolAt(0)) {
        second += 1;
      }
      final String name = vm.symbolAt(0).label;

      vm.flip(0);
      vm.flip(second);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.bySemanticsLabel('Matched: $name'), findsNWidgets(2));
      expect(find.text('1 of 6 pairs'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('all matched shows the turns neutrally, with Play again', (
      WidgetTester tester,
    ) async {
      final GamesTestApp app = GamesTestApp(random: Random(1));
      await open(tester, route: AppRoutes.calmMatch, app: app);
      final CalmMatchViewModel vm = Get.find<CalmMatchViewModel>();

      final Map<CalmSymbol, List<int>> byName = <CalmSymbol, List<int>>{};
      for (int i = 0; i < 12; i += 1) {
        byName.putIfAbsent(vm.symbolAt(i), () => <int>[]).add(i);
      }
      for (final List<int> pair in byName.values) {
        vm.flip(pair[0]);
        vm.flip(pair[1]);
      }
      await go(tester);

      expect(find.text('All matched'), findsOneWidget);
      expect(find.text('You found all 6 pairs in 6 turns.'), findsOneWidget);
      expect(find.text('Play again'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(
        find.textContaining(RegExp('best|score', caseSensitive: false)),
        findsNothing,
      );

      await tester.tap(find.text('Play again'));
      await go(tester);
      expect(find.text('0 of 6 pairs'), findsOneWidget);
      expect(app.breaks.saved.single.completed, isTrue);
    });
  });

  group('Gratitude garden screen', () {
    testWidgets('an empty garden shows bare ground and the first-flower line', (
      WidgetTester tester,
    ) async {
      await open(tester, route: AppRoutes.gratitudeGarden);

      expect(find.text('Plant your first flower today.'), findsOneWidget);
      expect(find.textContaining('flower'), findsWidgets);
      expect(find.text('1 flower'), findsNothing);
      expect(buttonEnabled(tester), isFalse);
    });

    testWidgets('the button turns on with text, and planting shows the entry', (
      WidgetTester tester,
    ) async {
      final GamesTestApp app = GamesTestApp();
      await open(tester, route: AppRoutes.gratitudeGarden, app: app);

      await tester.enterText(find.byType(TextField), 'Tea with Sana.');
      await tester.pump();
      expect(buttonEnabled(tester), isTrue);

      await tester.tap(find.text('Plant today\'s flower'));
      await go(tester, 1200);

      expect(find.text('Planted today'), findsOneWidget);
      expect(find.text('Tea with Sana.'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('1 flower'), findsOneWidget);
      expect(find.text('Plant your first flower today.'), findsNothing);
      expect(app.gratitude.creates, 1);
    });

    testWidgets('Edit changes today\'s words, and Cancel leaves them', (
      WidgetTester tester,
    ) async {
      final GamesTestApp app = GamesTestApp();
      app.gratitude.store[GratitudeRules.dateKey(DateTime.now())] = entryOn(
        DateTime.now(),
        'First words',
      );
      await open(tester, route: AppRoutes.gratitudeGarden, app: app);

      await tester.tap(find.text('Edit'));
      await go(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'First words',
      );
      await tester.tap(find.text('Cancel'));
      await go(tester);
      expect(find.text('First words'), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await go(tester);
      await tester.enterText(find.byType(TextField), 'Better words');
      await tester.pump();
      await tester.tap(find.text('Save changes'));
      await go(tester);

      expect(find.text('Better words'), findsOneWidget);
      expect(app.gratitude.edits, 1);
      expect(app.gratitude.creates, 0);
    });

    testWidgets('a failed save keeps the words and offers Try again', (
      WidgetTester tester,
    ) async {
      final GamesTestApp app = GamesTestApp();
      await open(tester, route: AppRoutes.gratitudeGarden, app: app);
      app.gratitude.failWith = StateError('permission-denied');

      await tester.enterText(find.byType(TextField), 'Keep me');
      await tester.pump();
      await tester.tap(find.text('Plant today\'s flower'));
      await go(tester);

      expect(find.text('Keep me'), findsOneWidget);
      expect(
        find.text('We could not save that. Your words are still here.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);

      app.gratitude.failWith = null;
      await tester.tap(find.text('Try again'));
      await go(tester, 1200);

      expect(find.text('Planted today'), findsOneWidget);
    });

    testWidgets('shows yesterday\'s entry under Yesterday', (
      WidgetTester tester,
    ) async {
      final DateTime now = DateTime.now();
      final DateTime yesterday = DateTime(now.year, now.month, now.day - 1);
      final GamesTestApp app = GamesTestApp(
        gratitude: FakeGratitudeService(<GratitudeEntry>[
          entryOn(yesterday, 'Had tea with Sana after the night shift.'),
        ]),
      );
      await open(tester, route: AppRoutes.gratitudeGarden, app: app);

      expect(find.text('YESTERDAY'), findsOneWidget);
      expect(
        find.text('Had tea with Sana after the night shift.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping an entry opens its sheet, and Delete asks first', (
      WidgetTester tester,
    ) async {
      final DateTime now = DateTime.now();
      final DateTime yesterday = DateTime(now.year, now.month, now.day - 1);
      final GamesTestApp app = GamesTestApp(
        gratitude: FakeGratitudeService(<GratitudeEntry>[
          entryOn(yesterday, 'A kind word.'),
        ]),
      );
      await open(tester, route: AppRoutes.gratitudeGarden, app: app);

      await tester.tap(find.text('A kind word.'));
      await go(tester);
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await go(tester);
      expect(find.text('Remove this flower?'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await go(tester);
      expect(app.gratitude.store, isNotEmpty);

      await tester.tap(find.text('Delete'));
      await go(tester);
      await tester.tap(find.text('Remove'));
      await go(tester, 900);

      expect(app.gratitude.store, isEmpty);
      expect(find.text('YESTERDAY'), findsNothing);
      expect(Get.find<GratitudeGardenViewModel>().entries, isEmpty);
    });

    testWidgets('a garden that cannot load offers Try again, no form', (
      WidgetTester tester,
    ) async {
      final GamesTestApp app = GamesTestApp();
      app.gratitude.failWith = StateError('offline');
      await open(tester, route: AppRoutes.gratitudeGarden, app: app);

      expect(find.text('Could not open your garden'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      app.gratitude.failWith = null;
      await tester.tap(find.text('Try again'));
      await go(tester);

      expect(find.byType(TextField), findsOneWidget);
    });
  });
}

class _ReducedMotion implements AccessibilityFeatures {
  const _ReducedMotion();

  @override
  bool get accessibleNavigation => false;

  @override
  bool get boldText => false;

  @override
  bool get disableAnimations => true;

  @override
  bool get highContrast => false;

  @override
  bool get invertColors => false;

  @override
  bool get onOffSwitchLabels => false;

  @override
  bool get reduceMotion => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}
