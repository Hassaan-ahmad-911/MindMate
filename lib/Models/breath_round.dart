/// How long each part of a breath lasts.
class BreathTiming {
  const BreathTiming._();

  static const Duration inhale = Duration(seconds: 4);
  static const Duration exhale = Duration(seconds: 6);
  static const Duration shrinkBack = Duration(milliseconds: 700);
}

enum BreathPhase {
  /// A small bubble waits for the user to press and hold.
  ready,

  /// Holding: the bubble grows towards the ring.
  inhaling,

  /// The bubble reached the ring; it waits for release.
  full,

  /// Released: the bubble floats up and fades.
  exhaling,

  /// Released too early: the bubble shrinks back. The breath does not count.
  shrinking,

  /// Eight breaths are done.
  finished,
}

/// What happened when the user let go.
enum BreathRelease {
  /// Nothing was being held.
  ignored,

  /// Let go before the ring: the breath does not count.
  early,

  /// Let go at the ring: the bubble now floats away.
  exhale,
}

/// The rules of one round of the breathing bubble: eight breaths. Pure Dart,
/// so the screen only has to run the animations and tell this when each one
/// ends.
class BreathRound {
  static const int total = 8;

  BreathPhase _phase = BreathPhase.ready;
  int _completed = 0;

  BreathPhase get phase => _phase;

  /// Breaths that were held to the ring and let go slowly.
  int get completed => _completed;

  bool get isFinished => _phase == BreathPhase.finished;

  /// The breath being worked on, 1 to [total].
  int get current => isFinished ? total : _completed + 1;

  /// Starts breathing in. Only possible while a bubble is waiting.
  bool press() {
    if (_phase != BreathPhase.ready) {
      return false;
    }
    _phase = BreathPhase.inhaling;
    return true;
  }

  /// The bubble reached the ring while still held.
  bool reachedFull() {
    if (_phase != BreathPhase.inhaling) {
      return false;
    }
    _phase = BreathPhase.full;
    return true;
  }

  BreathRelease release() {
    switch (_phase) {
      case BreathPhase.inhaling:
        _phase = BreathPhase.shrinking;
        return BreathRelease.early;
      case BreathPhase.full:
        _phase = BreathPhase.exhaling;
        return BreathRelease.exhale;
      case BreathPhase.ready:
      case BreathPhase.exhaling:
      case BreathPhase.shrinking:
      case BreathPhase.finished:
        return BreathRelease.ignored;
    }
  }

  /// The early-release bubble is small again.
  void shrinkFinished() {
    if (_phase == BreathPhase.shrinking) {
      _phase = BreathPhase.ready;
    }
  }

  /// The bubble has floated away: the breath counts. Returns true when that
  /// was the last one of the round.
  bool exhaleFinished() {
    if (_phase != BreathPhase.exhaling) {
      return false;
    }
    _completed += 1;
    _phase = _completed >= total ? BreathPhase.finished : BreathPhase.ready;
    return _phase == BreathPhase.finished;
  }

  /// A new round.
  void restart() {
    _completed = 0;
    _phase = BreathPhase.ready;
  }
}
