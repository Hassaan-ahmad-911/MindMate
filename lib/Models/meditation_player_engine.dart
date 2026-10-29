import 'meditation_models.dart';

/// What happened on a [MeditationPlayerEngine.tick].
enum PlayerTick {
  /// Still in the same step.
  none,

  /// Moved on to the next step.
  stepChanged,

  /// The last step ended.
  finished,
}

/// The steps and clock of one practice, with no timers, voice or screen code
/// in it. The player ViewModel calls [tick] once a second while playing.
///
/// Each step lasts its length (its `seconds`, or longer for a long clip). If the voice is still speaking when a step's
/// time is up, the engine waits (see `holdForSpeech`), but never for longer
/// than [maxSpeechHoldSeconds].
class MeditationPlayerEngine {
  /// [stepSeconds] gives each step's length when it differs from the
  /// step's own `seconds` (a recorded clip can make a step a little longer).
  MeditationPlayerEngine(List<MeditationStep> steps, {List<int>? stepSeconds})
    : steps = List<MeditationStep>.unmodifiable(steps),
      _lengths = List<int>.unmodifiable(
        stepSeconds != null && stepSeconds.length == steps.length
            ? stepSeconds
            : steps.map((MeditationStep s) => s.seconds),
      ) {
    if (steps.isEmpty) {
      throw ArgumentError('A practice needs at least one step.');
    }
  }

  /// The longest the engine waits for the voice after a step's time is up.
  static const int maxSpeechHoldSeconds = 20;

  final List<MeditationStep> steps;
  final List<int> _lengths;

  /// How long step [index] lasts, in seconds.
  int lengthOf(int index) => _lengths[index];

  int get _currentLength => _lengths[_stepIndex];

  int _stepIndex = 0;
  int _secondsIntoStep = 0;
  int _secondsPractised = 0;
  int _holdSeconds = 0;
  bool _isPlaying = false;
  bool _finished = false;
  bool _endedEarly = false;

  /// Index of the current step, from 0.
  int get stepIndex => _stepIndex;

  int get stepCount => steps.length;

  MeditationStep get currentStep => steps[_stepIndex];

  bool get isFirstStep => _stepIndex == 0;

  bool get isLastStep => _stepIndex == steps.length - 1;

  /// Seconds spent in the current step.
  int get secondsIntoStep => _secondsIntoStep;

  /// Time actually practised, not counting pauses.
  int get secondsPractised => _secondsPractised;

  bool get isPlaying => _isPlaying;

  /// The last step ended on its own.
  bool get isFinished => _finished;

  /// True only if the last step finished.
  bool get completed => _finished;

  /// Finished, or ended early.
  bool get isEnded => _finished || _endedEarly;

  /// Length of the whole practice.
  int get totalSeconds =>
      _lengths.fold<int>(0, (int total, int length) => total + length);

  /// Time left in the whole practice.
  int get secondsLeft {
    if (_finished) {
      return 0;
    }
    int left = _currentLength - _secondsIntoStep;
    for (int i = _stepIndex + 1; i < steps.length; i += 1) {
      left += _lengths[i];
    }
    return left;
  }

  /// How far through the current step, 0 to 1.
  double get stepProgress {
    if (_finished) {
      return 1;
    }
    return (_secondsIntoStep / _currentLength).clamp(0.0, 1.0).toDouble();
  }

  /// The current step's time is up and the engine is waiting to move on.
  bool get isStepTimeUp => !isEnded && _secondsIntoStep >= _currentLength;

  /// Starts, or resumes after a pause.
  void play() {
    if (!isEnded) {
      _isPlaying = true;
    }
  }

  void pause() {
    _isPlaying = false;
  }

  /// Moves the clock on one second. Does nothing while paused or ended.
  ///
  /// Set [holdForSpeech] while the voice is still speaking: when the step's
  /// time is up the engine then stays on the step until the voice is done
  /// (see [advanceIfStepTimeUp]) or [maxSpeechHoldSeconds] have passed.
  PlayerTick tick({bool holdForSpeech = false}) {
    if (!_isPlaying || isEnded) {
      return PlayerTick.none;
    }
    _secondsPractised += 1;

    if (_secondsIntoStep < _currentLength) {
      _secondsIntoStep += 1;
      if (_secondsIntoStep < _currentLength) {
        return PlayerTick.none;
      }
    } else {
      _holdSeconds += 1;
    }

    // The step's time is up.
    if (holdForSpeech && _holdSeconds < maxSpeechHoldSeconds) {
      return PlayerTick.none;
    }
    return _advance();
  }

  /// Moves on if the step's time is up. Call this when the voice finishes
  /// while the engine is waiting for it.
  PlayerTick advanceIfStepTimeUp() {
    if (!_isPlaying || !isStepTimeUp) {
      return PlayerTick.none;
    }
    return _advance();
  }

  /// Jumps to the start of the next step. False on the last step.
  bool next() {
    if (isEnded || isLastStep) {
      return false;
    }
    _stepIndex += 1;
    _secondsIntoStep = 0;
    _holdSeconds = 0;
    return true;
  }

  /// Jumps to the start of the previous step. On the first step it starts
  /// that step again.
  bool previous() {
    if (isEnded) {
      return false;
    }
    if (_stepIndex > 0) {
      _stepIndex -= 1;
    }
    _secondsIntoStep = 0;
    _holdSeconds = 0;
    return true;
  }

  /// Stops the practice before the last step has finished.
  void endEarly() {
    if (!_finished) {
      _endedEarly = true;
    }
    _isPlaying = false;
  }

  PlayerTick _advance() {
    _holdSeconds = 0;
    if (isLastStep) {
      _finished = true;
      _isPlaying = false;
      _secondsIntoStep = _currentLength;
      return PlayerTick.finished;
    }
    _stepIndex += 1;
    _secondsIntoStep = 0;
    return PlayerTick.stepChanged;
  }
}
