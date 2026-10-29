import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindmate/Models/break_log.dart';
import 'package:mindmate/Models/breath_round.dart';
import 'package:mindmate/Models/calm_match_game.dart';
import 'package:mindmate/Models/gratitude_entry.dart';

import 'helpers/games_fakes.dart';

/// Index pairs of cards that hold the same picture.
List<List<int>> pairsOf(CalmMatchGame game) {
  final Map<CalmSymbol, List<int>> byName = <CalmSymbol, List<int>>{};
  for (int i = 0; i < CalmMatchGame.cardCount; i += 1) {
    byName.putIfAbsent(game.symbols[i], () => <int>[]).add(i);
  }
  return byName.values.toList();
}

/// Two indices that do NOT hold the same picture.
List<int> mismatchOf(CalmMatchGame game) {
  for (int i = 0; i < CalmMatchGame.cardCount; i += 1) {
    for (int j = i + 1; j < CalmMatchGame.cardCount; j += 1) {
      if (game.symbols[i] != game.symbols[j]) {
        return <int>[i, j];
      }
    }
  }
  throw StateError('unreachable');
}

void main() {
  group('Calm match', () {
    test('a new game has 12 face-down cards in 6 pairs', () {
      final CalmMatchGame game = CalmMatchGame(random: Random(1));

      expect(game.symbols, hasLength(12));
      expect(game.faces.every((CardFace f) => f == CardFace.down), isTrue);
      expect(game.turns, 0);
      expect(game.pairsFound, 0);
      for (final CalmSymbol symbol in CalmSymbol.values) {
        expect(game.symbols.where((CalmSymbol s) => s == symbol), hasLength(2));
      }
      expect(pairsOf(game), hasLength(6));
    });

    test('the six pictures are leaf, moon, wave, heart, star and sun', () {
      expect(CalmSymbol.values.map((CalmSymbol s) => s.label), <String>[
        'leaf',
        'moon',
        'wave',
        'heart',
        'star',
        'sun',
      ]);
    });

    test('every new game is shuffled', () {
      final Set<String> layouts = <String>{};
      for (int seed = 0; seed < 8; seed += 1) {
        layouts.add(
          CalmMatchGame(
            random: Random(seed),
          ).symbols.map((CalmSymbol s) => s.name).join(','),
        );
      }
      expect(layouts.length, greaterThan(1));
    });

    test('the first card turns over and the turn is not counted yet', () {
      final CalmMatchGame game = CalmMatchGame(random: Random(2));

      expect(game.flip(0), FlipResult.flipped);
      expect(game.faces[0], CardFace.up);
      expect(game.turns, 0);
    });

    test('two matching cards stay up as matched and count one turn', () {
      final CalmMatchGame game = CalmMatchGame(random: Random(3));
      final List<int> pair = pairsOf(game).first;

      expect(game.flip(pair[0]), FlipResult.flipped);
      expect(game.flip(pair[1]), FlipResult.matched);

      expect(game.faces[pair[0]], CardFace.matched);
      expect(game.faces[pair[1]], CardFace.matched);
      expect(game.pairsFound, 1);
      expect(game.turns, 1);
      expect(game.isLocked, isFalse);
    });

    test('two different cards are a mismatch and lock the board', () {
      final CalmMatchGame game = CalmMatchGame(random: Random(4));
      final List<int> miss = mismatchOf(game);

      game.flip(miss[0]);
      expect(game.flip(miss[1]), FlipResult.mismatch);

      expect(game.turns, 1);
      expect(game.pairsFound, 0);
      expect(game.isLocked, isTrue);
      expect(game.faces[miss[0]], CardFace.up);
      expect(game.faces[miss[1]], CardFace.up);
    });

    test('taps are ignored while two unmatched cards are showing', () {
      final CalmMatchGame game = CalmMatchGame(random: Random(5));
      final List<int> miss = mismatchOf(game);
      game.flip(miss[0]);
      game.flip(miss[1]);
      final int third = List<int>.generate(
        12,
        (int i) => i,
      ).firstWhere((int i) => i != miss[0] && i != miss[1]);

      expect(game.flip(third), FlipResult.ignored);

      expect(game.faces[third], CardFace.down);
      expect(game.turns, 1);
    });

    test('after the pause the two cards turn back and play goes on', () {
      final CalmMatchGame game = CalmMatchGame(random: Random(6));
      final List<int> miss = mismatchOf(game);
      game.flip(miss[0]);
      game.flip(miss[1]);

      game.resolveMismatch();

      expect(game.faces[miss[0]], CardFace.down);
      expect(game.faces[miss[1]], CardFace.down);
      expect(game.isLocked, isFalse);
      expect(game.flip(miss[0]), FlipResult.flipped);
    });

    test('tapping a face-up or matched card does nothing', () {
      final CalmMatchGame game = CalmMatchGame(random: Random(7));
      final List<int> pair = pairsOf(game).first;

      game.flip(pair[0]);
      expect(game.flip(pair[0]), FlipResult.ignored);
      expect(game.turns, 0);

      game.flip(pair[1]);
      expect(game.flip(pair[0]), FlipResult.ignored);
      expect(game.flip(pair[1]), FlipResult.ignored);
      expect(game.turns, 1);
    });

    test('taps outside the grid are ignored', () {
      final CalmMatchGame game = CalmMatchGame(random: Random(8));

      expect(game.flip(-1), FlipResult.ignored);
      expect(game.flip(12), FlipResult.ignored);
    });

    test('finding all six pairs completes the game', () {
      final CalmMatchGame game = CalmMatchGame(random: Random(9));
      expect(game.isComplete, isFalse);

      for (final List<int> pair in pairsOf(game)) {
        game.flip(pair[0]);
        game.flip(pair[1]);
      }

      expect(game.isComplete, isTrue);
      expect(game.pairsFound, 6);
      expect(game.turns, 6);
      expect(game.faces.every((CardFace f) => f == CardFace.matched), isTrue);
    });

    test('turns count only completed pairs of flips, mistakes included', () {
      final CalmMatchGame game = CalmMatchGame(random: Random(10));
      final List<int> miss = mismatchOf(game);
      game.flip(miss[0]);
      game.flip(miss[1]);
      game.resolveMismatch();
      for (final List<int> pair in pairsOf(game)) {
        game.flip(pair[0]);
        game.flip(pair[1]);
      }

      expect(game.turns, 7);
      expect(game.isComplete, isTrue);
    });

    test('cards have clear accessibility labels', () {
      final CalmMatchGame game = CalmMatchGame(random: Random(11));
      final List<int> pair = pairsOf(game).first;
      final String name = game.symbols[pair[0]].label;

      expect(game.labelFor(pair[0]), 'Face-down card');
      game.flip(pair[0]);
      expect(game.labelFor(pair[0]), 'Face up: $name');
      game.flip(pair[1]);
      expect(game.labelFor(pair[0]), 'Matched: $name');
    });
  });

  group('Breathing round', () {
    /// One full breath: hold to the ring, let go, float away.
    bool breathe(BreathRound round) {
      round.press();
      round.reachedFull();
      round.release();
      return round.exhaleFinished();
    }

    test('starts with a small bubble waiting', () {
      final BreathRound round = BreathRound();

      expect(round.phase, BreathPhase.ready);
      expect(round.completed, 0);
      expect(round.current, 1);
    });

    test('holding to the ring and letting go counts one breath', () {
      final BreathRound round = BreathRound();

      expect(round.press(), isTrue);
      expect(round.phase, BreathPhase.inhaling);
      expect(round.reachedFull(), isTrue);
      expect(round.phase, BreathPhase.full);
      expect(round.release(), BreathRelease.exhale);
      expect(round.phase, BreathPhase.exhaling);
      expect(round.exhaleFinished(), isFalse);

      expect(round.completed, 1);
      expect(round.current, 2);
      expect(round.phase, BreathPhase.ready);
    });

    test('letting go early does not count the breath', () {
      final BreathRound round = BreathRound();
      round.press();

      expect(round.release(), BreathRelease.early);
      expect(round.phase, BreathPhase.shrinking);
      round.shrinkFinished();

      expect(round.phase, BreathPhase.ready);
      expect(round.completed, 0);
      expect(round.current, 1);
    });

    test('an early release can be followed by a proper breath', () {
      final BreathRound round = BreathRound();
      round.press();
      round.release();
      round.shrinkFinished();

      breathe(round);

      expect(round.completed, 1);
    });

    test('holding past the ring waits for release and nothing else', () {
      final BreathRound round = BreathRound();
      round.press();
      round.reachedFull();

      expect(round.reachedFull(), isFalse);
      expect(round.press(), isFalse);
      expect(round.phase, BreathPhase.full);
      expect(round.completed, 0);
    });

    test('presses are ignored while the bubble floats away or shrinks', () {
      final BreathRound round = BreathRound();
      round.press();
      round.reachedFull();
      round.release();
      expect(round.press(), isFalse);

      final BreathRound other = BreathRound();
      other.press();
      other.release();
      expect(other.press(), isFalse);
    });

    test('a release with nothing held does nothing', () {
      final BreathRound round = BreathRound();

      expect(round.release(), BreathRelease.ignored);
      expect(round.phase, BreathPhase.ready);
    });

    test('a breath only counts once the bubble has floated away', () {
      final BreathRound round = BreathRound();
      round.press();
      round.reachedFull();
      round.release();

      expect(round.completed, 0);
    });

    test('eight breaths complete the round', () {
      final BreathRound round = BreathRound();

      for (int i = 1; i <= 7; i += 1) {
        expect(breathe(round), isFalse);
        expect(round.completed, i);
      }
      expect(breathe(round), isTrue);

      expect(round.completed, 8);
      expect(round.isFinished, isTrue);
      expect(round.current, 8);
      expect(round.press(), isFalse);
    });

    test('early releases in between do not shorten the round', () {
      final BreathRound round = BreathRound();
      for (int i = 0; i < 8; i += 1) {
        round.press();
        round.release();
        round.shrinkFinished();
        breathe(round);
      }

      expect(round.isFinished, isTrue);
    });

    test('again starts a fresh round', () {
      final BreathRound round = BreathRound();
      for (int i = 0; i < 8; i += 1) {
        breathe(round);
      }

      round.restart();

      expect(round.completed, 0);
      expect(round.phase, BreathPhase.ready);
      expect(round.press(), isTrue);
    });

    test('the timings are 4 seconds in and 6 seconds out', () {
      expect(BreathTiming.inhale, const Duration(seconds: 4));
      expect(BreathTiming.exhale, const Duration(seconds: 6));
    });
  });

  group('Gratitude rules', () {
    final DateTime today = DateTime(2026, 10, 7, 9, 30);

    test('the document id is the local date, yyyy-MM-dd', () {
      expect(
        GratitudeRules.dateKey(DateTime(2026, 3, 5, 23, 59)),
        '2026-03-05',
      );
      expect(GratitudeRules.dateKey(today), '2026-10-07');
    });

    test('a date key reads back, and a bad one does not', () {
      expect(GratitudeRules.dateFromKey('2026-10-07'), DateTime(2026, 10, 7));
      expect(GratitudeRules.dateFromKey('2026-02-31'), isNull);
      expect(GratitudeRules.dateFromKey('yesterday'), isNull);
      expect(GratitudeRules.dateFromKey('2026-1-7'), isNull);
    });

    test('text must be 1 to 200 characters once trimmed', () {
      expect(GratitudeRules.canSave(''), isFalse);
      expect(GratitudeRules.canSave('   '), isFalse);
      expect(GratitudeRules.canSave(null), isFalse);
      expect(GratitudeRules.canSave('a'), isTrue);
      expect(GratitudeRules.canSave('a' * 200), isTrue);
      expect(GratitudeRules.canSave('a' * 201), isFalse);
      expect(GratitudeRules.cleanText('  tea with Sana  '), 'tea with Sana');
    });

    test('one entry per day: planting is blocked once today has a flower', () {
      final List<GratitudeEntry> none = <GratitudeEntry>[];
      final List<GratitudeEntry> yesterdayOnly = <GratitudeEntry>[
        entryOn(DateTime(2026, 10, 6), 'Yesterday'),
      ];
      final List<GratitudeEntry> planted = <GratitudeEntry>[
        entryOn(DateTime(2026, 10, 6), 'Yesterday'),
        entryOn(today, 'Today'),
      ];

      expect(GratitudeRules.canPlant(none, today), isTrue);
      expect(GratitudeRules.canPlant(yesterdayOnly, today), isTrue);
      expect(GratitudeRules.canPlant(planted, today), isFalse);
      expect(GratitudeRules.entryFor(planted, today)?.text, 'Today');
    });

    test('an entry can be edited on its own day only', () {
      final GratitudeEntry entry = entryOn(today, 'Today');

      expect(GratitudeRules.canEdit(entry, today), isTrue);
      expect(
        GratitudeRules.canEdit(entry, DateTime(2026, 10, 7, 23, 59)),
        isTrue,
      );
      expect(
        GratitudeRules.canEdit(entry, DateTime(2026, 10, 8, 0, 1)),
        isFalse,
      );
      expect(
        GratitudeRules.canEdit(entryOn(DateTime(2026, 10, 6), 'Old'), today),
        isFalse,
      );
    });

    test('the previous entry is the latest one before today', () {
      final List<GratitudeEntry> entries = <GratitudeEntry>[
        entryOn(today, 'Today'),
        entryOn(DateTime(2026, 10, 3), 'Older'),
        entryOn(DateTime(2026, 10, 5), 'Latest before today'),
        entryOn(DateTime(2026, 10, 8), 'Tomorrow, by a wrong clock'),
      ];

      expect(
        GratitudeRules.previousEntry(entries, today)?.text,
        'Latest before today',
      );
      expect(GratitudeRules.previousEntry(<GratitudeEntry>[], today), isNull);
    });

    test('the previous entry is labelled Yesterday or by its date', () {
      expect(GratitudeRules.dayLabel('2026-10-06', today), 'Yesterday');
      expect(GratitudeRules.dayLabel('2026-10-03', today), '3 Oct');
      expect(GratitudeRules.dayLabel('2025-12-31', today), '31 Dec 2025');
    });

    test('entries are sorted oldest first', () {
      final List<GratitudeEntry> sorted =
          GratitudeRules.sorted(<GratitudeEntry>[
            entryOn(DateTime(2026, 10, 5), 'b'),
            entryOn(DateTime(2026, 9, 30), 'a'),
            entryOn(DateTime(2026, 10, 7), 'c'),
          ]);

      expect(sorted.map((GratitudeEntry e) => e.text), <String>['a', 'b', 'c']);
    });

    test('a flower always looks the same for its date', () {
      final FlowerStyle first = FlowerStyle.forDateKey('2026-10-07');
      final FlowerStyle again = FlowerStyle.forDateKey('2026-10-07');

      expect(again.heightFraction, first.heightFraction);
      expect(again.colour, first.colour);
    });

    test('flower heights stay in range and colours vary across dates', () {
      final Set<FlowerColour> colours = <FlowerColour>{};
      final Set<double> heights = <double>{};
      for (int day = 1; day <= 60; day += 1) {
        final FlowerStyle style = FlowerStyle.forDateKey(
          GratitudeRules.dateKey(DateTime(2026, 1, day)),
        );
        expect(style.heightFraction, inInclusiveRange(0.34, 0.7));
        colours.add(style.colour);
        heights.add(style.heightFraction);
      }

      expect(colours, hasLength(FlowerColour.values.length));
      expect(heights.length, greaterThan(20));
    });
  });

  group('Breaks this week', () {
    final DateTime now = DateTime(2026, 10, 7, 12);

    test('counts breaks from the last seven days', () {
      final List<DateTime> starts = <DateTime>[
        now.subtract(const Duration(hours: 1)),
        now.subtract(const Duration(days: 3)),
        now.subtract(const Duration(days: 6, hours: 23)),
        now.subtract(const Duration(days: 7, hours: 1)),
        now.subtract(const Duration(days: 30)),
      ];

      expect(BreakStats.countThisWeek(starts, now), 3);
    });

    test('is zero with no breaks', () {
      expect(BreakStats.countThisWeek(const <DateTime>[], now), 0);
    });

    test(
      'the repository counts only the last seven days of stored breaks',
      () async {
        final FakeBreakService service = FakeBreakService();
        BreakLogEntry at(Duration ago) => BreakLogEntry(
          id: 'x',
          activity: BreakActivity.calmMatch,
          startedAt: now.subtract(ago),
          seconds: 60,
          completed: true,
        );
        service.stored.addAll(<BreakLogEntry>[
          at(const Duration(days: 1)),
          at(const Duration(days: 2)),
          at(const Duration(days: 9)),
        ]);

        expect(await breakRepository(service).countThisWeek(now: now), 2);
      },
    );

    test('the footer wording is gentle and has no target', () {
      expect(BreakStats.footerLine(4), startsWith('breaks taken this week'));
      expect(BreakStats.footerLine(1), startsWith('break taken this week'));
      expect(BreakStats.footerLine(0), 'A few minutes for yourself counts.');
    });

    test('a break stores the activity, start, seconds and completed only', () {
      final BreakLogEntry entry = BreakLogEntry(
        id: 'x',
        activity: BreakActivity.breathingBubble,
        startedAt: now,
        seconds: 95,
        completed: true,
      );

      expect(entry.toMap().keys.toSet(), <String>{
        'activity',
        'startedAt',
        'seconds',
        'completed',
      });
      expect(entry.toMap()['activity'], 'breathing_bubble');
      expect(BreakActivity.calmMatch.id, 'calm_match');
      expect(BreakActivity.gratitudeGarden.id, 'gratitude_garden');
    });
  });
}
