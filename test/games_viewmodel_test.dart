import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mindmate/Models/break_log.dart';
import 'package:mindmate/Models/breath_round.dart';
import 'package:mindmate/Models/calm_match_game.dart';
import 'package:mindmate/Models/gratitude_entry.dart';
import 'package:mindmate/ui/games/breathing_bubble_viewmodel.dart';
import 'package:mindmate/ui/games/calm_match_viewmodel.dart';
import 'package:mindmate/ui/games/games_hub_viewmodel.dart';
import 'package:mindmate/ui/games/gratitude_garden_viewmodel.dart';

import 'helpers/games_fakes.dart';

/// Lets queued futures (the unawaited writes) finish.
Future<void> settle() async {
  for (int i = 0; i < 5; i += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  group('Gratitude garden', () {
    late FakeGratitudeService service;
    late FakeBreakService breaks;
    late DateTime now;

    GratitudeGardenViewModel build() {
      return Get.put<GratitudeGardenViewModel>(
        GratitudeGardenViewModel(
          gratitudeRepository(service),
          breakRepository(breaks),
          clock: () => now,
        ),
      );
    }

    setUp(() {
      service = FakeGratitudeService();
      breaks = FakeBreakService();
      now = DateTime(2026, 10, 7, 9, 30);
    });

    test(
      'starts empty, with the button disabled while the field is empty',
      () async {
        final GratitudeGardenViewModel vm = build();
        await settle();

        expect(vm.isLoading.value, isFalse);
        expect(vm.entries, isEmpty);
        expect(vm.isWriting, isTrue);
        expect(vm.canSubmit, isFalse);

        vm.textController.text = '   ';
        expect(vm.canSubmit, isFalse);

        vm.textController.text = 'Tea with Sana.';
        expect(vm.canSubmit, isTrue);
      },
    );

    test('the field holds up to 200 characters', () async {
      final GratitudeGardenViewModel vm = build();
      await settle();

      vm.textController.text = 'a' * 201;
      expect(vm.canSubmit, isFalse);
      vm.textController.text = 'a' * 200;
      expect(vm.canSubmit, isTrue);
    });

    test('planting saves the flower under today\'s date', () async {
      final GratitudeGardenViewModel vm = build();
      await settle();
      vm.textController.text = '  A patient\'s daughter thanked me.  ';

      await vm.submit();

      expect(service.creates, 1);
      expect(service.store.keys, <String>['2026-10-07']);
      expect(
        service.store['2026-10-07']!.text,
        'A patient\'s daughter thanked me.',
      );
      expect(vm.todayEntry?.text, 'A patient\'s daughter thanked me.');
      expect(vm.isWriting, isFalse);
      expect(vm.justPlantedKey.value, '2026-10-07');
      expect(vm.textController.text, isEmpty);
    });

    test('planting counts as a break, without storing the text', () async {
      final GratitudeGardenViewModel vm = build();
      await settle();
      vm.textController.text = 'Private words';

      await vm.submit();
      await settle();

      expect(breaks.saved, hasLength(1));
      final BreakLogEntry entry = breaks.saved.single;
      expect(entry.activity, BreakActivity.gratitudeGarden);
      expect(entry.completed, isTrue);
      expect(entry.toMap().toString(), isNot(contains('Private words')));
    });

    test('only one flower can be planted a day', () async {
      final GratitudeGardenViewModel vm = build();
      await settle();
      vm.textController.text = 'First';
      await vm.submit();

      vm.textController.text = 'Second';
      await vm.submit();

      expect(service.creates, 1);
      expect(vm.entries, hasLength(1));
      expect(vm.todayEntry?.text, 'First');
    });

    test(
      'an entry from today can be edited, keeping when it was planted',
      () async {
        final GratitudeGardenViewModel vm = build();
        await settle();
        vm.textController.text = 'First';
        await vm.submit();
        final DateTime planted = vm.todayEntry!.createdAt;

        now = DateTime(2026, 10, 7, 18, 0);
        vm.startEdit();
        expect(vm.isEditing.value, isTrue);
        expect(vm.textController.text, 'First');
        vm.textController.text = 'First, changed';
        await vm.submit();

        expect(service.creates, 1);
        expect(service.edits, 1);
        expect(vm.todayEntry?.text, 'First, changed');
        expect(vm.todayEntry?.createdAt, planted);
        expect(vm.todayEntry?.updatedAt, now);
        expect(vm.isEditing.value, isFalse);
      },
    );

    test('cancelling an edit leaves the entry as it was', () async {
      final GratitudeGardenViewModel vm = build();
      await settle();
      vm.textController.text = 'First';
      await vm.submit();

      vm.startEdit();
      vm.textController.text = 'Something else';
      vm.cancelEdit();

      expect(vm.isEditing.value, isFalse);
      expect(vm.todayEntry?.text, 'First');
      expect(service.edits, 0);
    });

    test('yesterday\'s flower cannot be edited', () async {
      service = FakeGratitudeService(<GratitudeEntry>[
        entryOn(DateTime(2026, 10, 6), 'Yesterday\'s'),
      ]);
      final GratitudeGardenViewModel vm = build();
      await settle();

      vm.startEdit();

      expect(vm.isEditing.value, isFalse);
      expect(vm.todayEntry, isNull);
      expect(vm.previousEntry?.text, 'Yesterday\'s');
    });

    test('the next day starts a new flower and the old one stays', () async {
      final GratitudeGardenViewModel vm = build();
      await settle();
      vm.textController.text = 'Monday';
      await vm.submit();

      now = DateTime(2026, 10, 8, 8, 0);
      expect(vm.todayEntry, isNull);
      expect(vm.isWriting, isTrue);
      expect(vm.previousEntry?.text, 'Monday');
      vm.textController.text = 'Tuesday';
      await vm.submit();

      expect(service.creates, 2);
      expect(vm.entries.map((GratitudeEntry e) => e.text), <String>[
        'Monday',
        'Tuesday',
      ]);
    });

    test('words edited across midnight do not change the old flower', () async {
      final GratitudeGardenViewModel vm = build();
      await settle();
      vm.textController.text = 'Late';
      await vm.submit();
      vm.startEdit();
      vm.textController.text = 'Written after midnight';

      now = DateTime(2026, 10, 8, 0, 5);
      await vm.submit();

      expect(service.edits, 0);
      expect(service.store['2026-10-07']!.text, 'Late');
      expect(service.store['2026-10-08']!.text, 'Written after midnight');
      expect(vm.isEditing.value, isFalse);
    });

    test('a failed save keeps the text and can be retried', () async {
      final GratitudeGardenViewModel vm = build();
      await settle();
      vm.textController.text = 'Keep these words';
      service.failWith = StateError('permission-denied');

      await vm.submit();

      expect(vm.saveFailed.value, isTrue);
      expect(vm.textController.text, 'Keep these words');
      expect(vm.entries, isEmpty);
      expect(vm.isSaving.value, isFalse);
      expect(vm.canSubmit, isTrue);

      service.failWith = null;
      await vm.submit();

      expect(vm.saveFailed.value, isFalse);
      expect(vm.todayEntry?.text, 'Keep these words');
      expect(vm.textController.text, isEmpty);
    });

    testWidgets('with no connection the flower is kept on the phone', (
      WidgetTester tester,
    ) async {
      final GratitudeGardenViewModel vm = build();
      await tester.pump();
      vm.textController.text = 'Offline thought';
      service.neverFinishes = true;

      final Future<void> saving = vm.submit();
      await tester.pump(const Duration(seconds: 5));
      await saving;

      expect(vm.saveFailed.value, isFalse);
      expect(vm.todayEntry?.text, 'Offline thought');
      expect(vm.isSaving.value, isFalse);
    });

    test(
      'a garden that cannot load shows an error and hides the form',
      () async {
        service.failWith = StateError('offline');
        final GratitudeGardenViewModel vm = build();
        await settle();

        expect(vm.loadFailed.value, isTrue);
        expect(vm.isLoading.value, isFalse);

        vm.textController.text = 'Words';
        await vm.submit();
        expect(service.creates, 0);

        service.failWith = null;
        await vm.load();
        expect(vm.loadFailed.value, isFalse);
      },
    );

    test('flowers load oldest first', () async {
      service = FakeGratitudeService(<GratitudeEntry>[
        entryOn(DateTime(2026, 10, 5), 'b'),
        entryOn(DateTime(2026, 10, 1), 'a'),
        entryOn(DateTime(2026, 10, 6), 'c'),
      ]);
      final GratitudeGardenViewModel vm = build();
      await settle();

      expect(vm.entries.map((GratitudeEntry e) => e.text), <String>[
        'a',
        'b',
        'c',
      ]);
    });

    test('deleting removes the flower, and a failure brings it back', () async {
      final GratitudeEntry old = entryOn(DateTime(2026, 10, 5), 'Old');
      service = FakeGratitudeService(<GratitudeEntry>[old]);
      final GratitudeGardenViewModel vm = build();
      await settle();

      service.failWith = StateError('offline');
      await vm.delete(old);
      expect(vm.entries, hasLength(1));

      service.failWith = null;
      await vm.delete(old);
      expect(vm.entries, isEmpty);
      expect(service.store, isEmpty);
    });

    test('deleting today\'s flower lets the user plant again', () async {
      final GratitudeGardenViewModel vm = build();
      await settle();
      vm.textController.text = 'One';
      await vm.submit();

      await vm.delete(vm.todayEntry!);

      expect(vm.todayEntry, isNull);
      expect(vm.isWriting, isTrue);
    });
  });

  group('Games hub', () {
    test('shows the breaks from this week and the garden chip', () async {
      final DateTime now = DateTime(2026, 10, 7, 12);
      final FakeBreakService breaks = FakeBreakService();
      for (final int days in <int>[0, 2, 5, 10]) {
        breaks.stored.add(
          BreakLogEntry(
            id: 'b$days',
            activity: BreakActivity.calmMatch,
            startedAt: now.subtract(Duration(days: days)),
            seconds: 30,
            completed: true,
          ),
        );
      }
      final FakeGratitudeService garden = FakeGratitudeService();

      final GamesHubViewModel vm = Get.put<GamesHubViewModel>(
        GamesHubViewModel(
          breakRepository(breaks),
          gratitudeRepository(garden),
          clock: () => now,
        ),
      );
      await settle();

      expect(vm.breaksThisWeek.value, 3);
      expect(vm.plantedToday.value, isFalse);
      expect(vm.gardenChip, 'Today\'s flower is waiting');

      garden.store['2026-10-07'] = entryOn(now, 'Planted');
      await vm.reload();

      expect(vm.gardenChip, 'Planted today');
    });

    test('says nothing wrong when the numbers cannot be loaded', () async {
      final FakeBreakService breaks = FakeBreakService()..failLoading = true;
      final FakeGratitudeService garden = FakeGratitudeService()
        ..failWith = StateError('offline');

      final GamesHubViewModel vm = Get.put<GamesHubViewModel>(
        GamesHubViewModel(breakRepository(breaks), gratitudeRepository(garden)),
      );
      await settle();

      expect(vm.breaksThisWeek.value, isNull);
      expect(vm.plantedToday.value, isNull);
      expect(vm.gardenChip, isNot('Planted today'));
      expect(vm.gardenChip, isNot('Today\'s flower is waiting'));
    });
  });

  group('Breathing bubble', () {
    late FakeBreakService breaks;
    late BreathingBubbleViewModel vm;

    setUp(() {
      breaks = FakeBreakService();
      vm = Get.put<BreathingBubbleViewModel>(
        BreathingBubbleViewModel(breakRepository(breaks)),
      );
    });

    void breathe() {
      vm.press();
      vm.reachedFull();
      vm.release();
      vm.exhaleFinished();
    }

    test('names each part of the breath', () {
      expect(vm.title, 'Breathe in');
      vm.press();
      expect(vm.title, 'Breathe in');
      vm.reachedFull();
      expect(vm.title, 'Let go');
      vm.release();
      expect(vm.title, 'Breathe out');
      vm.exhaleFinished();
      expect(vm.title, 'Breathe in');
    });

    test('letting go early shows a kind hint and does not count', () {
      vm.press();
      vm.release();

      expect(vm.instruction, 'Hold a little longer');
      expect(vm.completed.value, 0);
      vm.shrinkFinished();
      expect(vm.phase.value, BreathPhase.ready);
      expect(vm.progressLabel, 'Breath 1 of 8');

      vm.press();
      expect(vm.instruction, isNot('Hold a little longer'));
    });

    test('progress reads Breath x of 8', () {
      expect(vm.progressLabel, 'Breath 1 of 8');
      breathe();
      expect(vm.progressLabel, 'Breath 2 of 8');
      expect(vm.completed.value, 1);
    });

    test(
      'eight breaths finish the round and log one completed break',
      () async {
        for (int i = 0; i < 8; i += 1) {
          breathe();
        }
        await settle();

        expect(vm.isFinished, isTrue);
        expect(vm.title, 'Nicely done');
        expect(breaks.saved, hasLength(1));
        expect(breaks.saved.single.activity, BreakActivity.breathingBubble);
        expect(breaks.saved.single.completed, isTrue);
      },
    );

    test(
      'closing after a finished round does not log a second break',
      () async {
        for (int i = 0; i < 8; i += 1) {
          breathe();
        }
        await settle();

        Get.delete<BreathingBubbleViewModel>(force: true);
        await settle();

        expect(breaks.saved, hasLength(1));
      },
    );

    test('again starts a new round that logs its own break', () async {
      for (int i = 0; i < 8; i += 1) {
        breathe();
      }
      vm.again();
      expect(vm.completed.value, 0);
      expect(vm.isFinished, isFalse);
      for (int i = 0; i < 8; i += 1) {
        breathe();
      }
      await settle();

      expect(breaks.saved, hasLength(2));
    });

    test('leaving part-way logs a break that is not completed', () async {
      breathe();
      breathe();

      Get.delete<BreathingBubbleViewModel>(force: true);
      await settle();

      expect(breaks.saved, hasLength(1));
      expect(breaks.saved.single.completed, isFalse);
    });

    test('opening the screen and leaving at once logs nothing', () async {
      Get.delete<BreathingBubbleViewModel>(force: true);
      await settle();

      expect(breaks.saved, isEmpty);
    });

    test('a failed log write never reaches the user', () async {
      breaks.failSaving = true;
      for (int i = 0; i < 8; i += 1) {
        breathe();
      }
      await settle();

      expect(vm.isFinished, isTrue);
    });
  });

  group('Calm match', () {
    late FakeBreakService breaks;
    late CalmMatchViewModel vm;

    setUp(() {
      breaks = FakeBreakService();
      vm = Get.put<CalmMatchViewModel>(
        CalmMatchViewModel(
          breakRepository(breaks),
          random: Random(1),
          mismatchDelay: const Duration(milliseconds: 900),
        ),
      );
    });

    List<List<int>> pairs() {
      final Map<CalmSymbol, List<int>> byName = <CalmSymbol, List<int>>{};
      for (int i = 0; i < 12; i += 1) {
        byName.putIfAbsent(vm.symbolAt(i), () => <int>[]).add(i);
      }
      return byName.values.toList();
    }

    List<int> mismatch() {
      final List<List<int>> p = pairs();
      return <int>[p[0][0], p[1][0]];
    }

    testWidgets('a mismatch turns back after 0.9 seconds', (
      WidgetTester tester,
    ) async {
      final List<int> miss = mismatch();
      vm.flip(miss[0]);
      vm.flip(miss[1]);

      expect(vm.faces[miss[0]], CardFace.up);
      expect(vm.turns.value, 1);

      await tester.pump(const Duration(milliseconds: 800));
      expect(vm.faces[miss[0]], CardFace.up);
      await tester.pump(const Duration(milliseconds: 150));

      expect(vm.faces[miss[0]], CardFace.down);
      expect(vm.faces[miss[1]], CardFace.down);
    });

    testWidgets('taps are ignored until the cards have turned back', (
      WidgetTester tester,
    ) async {
      final List<int> miss = mismatch();
      vm.flip(miss[0]);
      vm.flip(miss[1]);
      final int other = pairs()[2][0];

      vm.flip(other);
      expect(vm.faces[other], CardFace.down);

      await tester.pump(const Duration(seconds: 1));
      vm.flip(other);
      expect(vm.faces[other], CardFace.up);
    });

    test('a match stays up and counts the pair', () {
      final List<int> pair = pairs().first;
      vm.flip(pair[0]);
      vm.flip(pair[1]);

      expect(vm.faces[pair[0]], CardFace.matched);
      expect(vm.pairsFound.value, 1);
      expect(vm.turns.value, 1);
      expect(vm.labelFor(pair[0]), startsWith('Matched: '));
    });

    test(
      'finding every pair finishes the game and logs a completed break',
      () async {
        for (final List<int> pair in pairs()) {
          vm.flip(pair[0]);
          vm.flip(pair[1]);
        }
        await settle();

        expect(vm.finished.value, isTrue);
        expect(vm.pairsFound.value, 6);
        expect(breaks.saved, hasLength(1));
        expect(breaks.saved.single.activity, BreakActivity.calmMatch);
        expect(breaks.saved.single.completed, isTrue);
        // No turns and no score are stored.
        expect(breaks.saved.single.toMap().keys, isNot(contains('turns')));
      },
    );

    test('play again shuffles a fresh game', () {
      final List<String> before = List<String>.generate(
        12,
        (int i) => vm.symbolAt(i).name,
      );
      for (final List<int> pair in pairs()) {
        vm.flip(pair[0]);
        vm.flip(pair[1]);
      }

      vm.playAgain();

      expect(vm.finished.value, isFalse);
      expect(vm.turns.value, 0);
      expect(vm.pairsFound.value, 0);
      expect(vm.faces.every((CardFace f) => f == CardFace.down), isTrue);
      final List<String> after = List<String>.generate(
        12,
        (int i) => vm.symbolAt(i).name,
      );
      expect(after.toSet().length, 6);
      expect(after, isNot(before));
    });

    test('leaving mid-game logs a break that is not completed', () async {
      vm.flip(0);

      Get.delete<CalmMatchViewModel>(force: true);
      await settle();

      expect(breaks.saved, hasLength(1));
      expect(breaks.saved.single.completed, isFalse);
    });

    test('leaving without touching a card logs nothing', () async {
      Get.delete<CalmMatchViewModel>(force: true);
      await settle();

      expect(breaks.saved, isEmpty);
    });
  });
}
