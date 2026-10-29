import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../Data/repositories/break_repository.dart';
import '../../Models/break_log.dart';

/// Writes one "break taken" entry for an activity, at most once per round.
/// It never holds what the user typed, and a failed write is quietly dropped:
/// the break itself must not feel like it failed.
class BreakLogger {
  BreakLogger(this._repository, this._activity, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    start();
  }

  /// With no connection a write only finishes when the phone is back online,
  /// so it is never waited on for long.
  static const Duration _patience = Duration(seconds: 8);

  final BreakRepository _repository;
  final BreakActivity _activity;
  final DateTime Function() _clock;

  late DateTime _startedAt;
  bool _interacted = false;
  bool _logged = false;

  /// Starts timing a new round (a new game after "Again").
  void start() {
    _startedAt = _clock();
    _interacted = false;
    _logged = false;
  }

  /// The user did something (held a bubble, turned a card). Opening the screen
  /// and leaving straight away is not a break.
  void markInteraction() => _interacted = true;

  bool get hasInteracted => _interacted;

  bool get isLogged => _logged;

  /// Records the break. [completed] is true when the round was finished.
  /// Does nothing if it was already recorded, or if [completed] is false and
  /// the user never interacted.
  void finish({required bool completed}) {
    if (_logged || (!completed && !_interacted)) {
      return;
    }
    _logged = true;

    final DateTime now = _clock();
    final int seconds = now.difference(_startedAt).inSeconds;
    unawaited(_write(seconds < 0 ? 0 : seconds, completed));
  }

  Future<void> _write(int seconds, bool completed) async {
    try {
      final BreakLogEntry entry = BreakLogEntry(
        id: _repository.newId(),
        activity: _activity,
        startedAt: _startedAt,
        seconds: seconds,
        completed: completed,
      );
      await _repository.saveBreak(entry).timeout(_patience);
    } on TimeoutException {
      // Saved on the phone; it will sync when the connection is back.
    } catch (error) {
      debugPrint('Break not logged (${error.runtimeType}).');
    }
  }
}
