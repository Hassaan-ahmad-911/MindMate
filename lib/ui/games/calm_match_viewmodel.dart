import 'dart:async';
import 'dart:math' as math;

import 'package:get/get.dart';

import '../../Data/repositories/break_repository.dart';
import '../../Models/break_log.dart';
import '../../Models/calm_match_game.dart';
import 'break_logger.dart';

/// Calm match: no timer, no score. The screen taps cards; this turns
/// non-matching pairs back after a short pause.
class CalmMatchViewModel extends GetxController {
  CalmMatchViewModel(
    BreakRepository breaks, {
    math.Random? random,
    DateTime Function()? clock,
    this.mismatchDelay = const Duration(milliseconds: 900),
  }) : _random = random,
       _logger = BreakLogger(breaks, BreakActivity.calmMatch, clock: clock) {
    _game = CalmMatchGame(random: _random);
    faces = _game.faces.toList().obs;
  }

  final math.Random? _random;
  final BreakLogger _logger;

  /// How long two cards that do not match stay face up.
  final Duration mismatchDelay;

  late CalmMatchGame _game;
  Timer? _turnBack;

  /// What each card shows, for the grid.
  late final RxList<CardFace> faces;
  final RxInt pairsFound = 0.obs;
  final RxInt turns = 0.obs;
  final RxBool finished = false.obs;

  int get pairTotal => CalmMatchGame.pairCount;

  CalmSymbol symbolAt(int index) => _game.symbols[index];

  /// "Face-down card", "Face up: leaf" or "Matched: leaf".
  String labelFor(int index) => _game.labelFor(index);

  void flip(int index) {
    final FlipResult result = _game.flip(index);
    if (result == FlipResult.ignored) {
      return;
    }
    _logger.markInteraction();
    _sync();

    if (result == FlipResult.mismatch) {
      _turnBack?.cancel();
      _turnBack = Timer(mismatchDelay, () {
        _game.resolveMismatch();
        _sync();
      });
    } else if (result == FlipResult.matched && _game.isComplete) {
      finished.value = true;
      _logger.finish(completed: true);
    }
  }

  /// "Play again": shuffled cards, a fresh game.
  void playAgain() {
    _turnBack?.cancel();
    _game = CalmMatchGame(random: _random);
    _logger.start();
    finished.value = false;
    _sync();
  }

  void done() => Get.back<void>();

  void _sync() {
    faces.assignAll(_game.faces);
    pairsFound.value = _game.pairsFound;
    turns.value = _game.turns;
  }

  @override
  void onClose() {
    _turnBack?.cancel();
    _logger.finish(completed: false);
    super.onClose();
  }
}
