import 'package:get/get.dart';

import '../../Data/repositories/break_repository.dart';
import '../../Models/break_log.dart';
import '../../Models/breath_round.dart';
import 'break_logger.dart';

/// One round of the breathing bubble. The screen runs the animations and
/// tells this when each part ends; [BreathRound] holds the rules.
class BreathingBubbleViewModel extends GetxController {
  BreathingBubbleViewModel(BreakRepository breaks, {DateTime Function()? clock})
    : _logger = BreakLogger(
        breaks,
        BreakActivity.breathingBubble,
        clock: clock,
      );

  final BreathRound _round = BreathRound();
  final BreakLogger _logger;

  final Rx<BreathPhase> phase = BreathPhase.ready.obs;

  /// Breaths done so far, for the dots.
  final RxInt completed = 0.obs;

  /// After letting go too early, until the next press.
  final RxBool holdLongerHint = false.obs;

  int get total => BreathRound.total;

  /// The breath being worked on, 1 to 8. Reads the observables, so a screen
  /// that shows it updates.
  int get current => isFinished ? total : completed.value + 1;

  bool get isFinished => phase.value == BreathPhase.finished;

  /// The big title: "Breathe in", "Let go", "Breathe out".
  String get title {
    switch (phase.value) {
      case BreathPhase.ready:
      case BreathPhase.inhaling:
      case BreathPhase.shrinking:
        return 'Breathe in';
      case BreathPhase.full:
        return 'Let go';
      case BreathPhase.exhaling:
        return 'Breathe out';
      case BreathPhase.finished:
        return 'Nicely done';
    }
  }

  /// The line under the title.
  String get instruction {
    if (holdLongerHint.value && phase.value != BreathPhase.inhaling) {
      return 'Hold a little longer';
    }
    switch (phase.value) {
      case BreathPhase.ready:
        return 'Press and hold anywhere to breathe in.';
      case BreathPhase.inhaling:
      case BreathPhase.shrinking:
        return 'Keep holding until the bubble fills the ring.';
      case BreathPhase.full:
        return 'Release when you are ready.';
      case BreathPhase.exhaling:
        return 'Let the breath go slowly.';
      case BreathPhase.finished:
        return 'You took ${BreathRound.total} slow breaths.';
    }
  }

  /// "Breath 3 of 8".
  String get progressLabel => 'Breath $current of $total';

  bool press() {
    if (!_round.press()) {
      return false;
    }
    _logger.markInteraction();
    holdLongerHint.value = false;
    _sync();
    return true;
  }

  /// The bubble reached the ring while still held.
  void reachedFull() {
    if (_round.reachedFull()) {
      _sync();
    }
  }

  BreathRelease release() {
    final BreathRelease result = _round.release();
    if (result == BreathRelease.early) {
      holdLongerHint.value = true;
    }
    _sync();
    return result;
  }

  /// The early-release bubble is small again.
  void shrinkFinished() {
    _round.shrinkFinished();
    _sync();
  }

  /// The bubble has floated away.
  void exhaleFinished() {
    final bool roundDone = _round.exhaleFinished();
    _sync();
    if (roundDone) {
      _logger.finish(completed: true);
    }
  }

  /// "Again": a fresh round.
  void again() {
    _round.restart();
    _logger.start();
    holdLongerHint.value = false;
    _sync();
  }

  void done() => Get.back<void>();

  void _sync() {
    phase.value = _round.phase;
    completed.value = _round.completed;
  }

  @override
  void onClose() {
    // Leaving part-way still counts as a break (not completed).
    _logger.finish(completed: false);
    super.onClose();
  }
}
