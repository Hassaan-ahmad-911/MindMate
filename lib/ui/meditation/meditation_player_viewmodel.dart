import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../Data/repositories/meditation_repository.dart';
import '../../Models/meditation_audio.dart';
import '../../Models/meditation_log_entry.dart';
import '../../Models/meditation_models.dart';
import '../../Models/meditation_player_engine.dart';
import '../../Models/meditation_stats.dart';
import '../../services/keep_awake_service.dart';
import '../../services/meditation_audio_service.dart';
import '../../services/meditation_voice_service.dart';
import '../app/app_routes.dart';
import '../shared/app_feedback.dart';
import 'meditation_viewmodel.dart';

/// One practice from "Session details" to "Well done": the check-in, the
/// guided player and saving the result. It is created by the details route
/// and shared by the screens after it.
class MeditationPlayerViewModel extends GetxController
    with WidgetsBindingObserver {
  /// [source] is a practice id (String) or a [MeditationSession].
  MeditationPlayerViewModel({
    required MeditationRepository repository,
    required MeditationAudioService audio,
    required KeepAwakeService keepAwake,
    required Object? source,
    Duration tickInterval = const Duration(seconds: 1),
  }) : _repository = repository,
       _audio = audio,
       _keepAwake = keepAwake,
       _source = source,
       _tickInterval = tickInterval;

  /// The screens of one practice. Leaving the practice pops all of them.
  static const Set<String> flowRoutes = <String>{
    AppRoutes.meditationDetails,
    AppRoutes.meditationCheckIn,
    AppRoutes.meditationPlayer,
    AppRoutes.meditationComplete,
  };

  final MeditationRepository _repository;
  final MeditationAudioService _audio;
  final KeepAwakeService _keepAwake;
  final Object? _source;
  final Duration _tickInterval;

  final Rxn<MeditationSession> session = Rxn<MeditationSession>();
  final RxBool isLoading = true.obs;
  final RxBool hasLoadError = false.obs;

  // Check-in.
  final Rxn<int> feelBefore = Rxn<int>();

  /// Whether the steps are read aloud.
  final RxBool voiceEnabled = false.obs;

  /// False once the voice has failed on this phone.
  final RxBool voiceAvailable = true.obs;

  /// The background sound and its volume, remembered per user.
  final Rx<AmbientChoice> ambient = AmbientChoice.off.obs;
  final RxDouble ambientVolume = MeditationAudioRules.defaultAmbientVolume.obs;

  // Player.
  final RxBool isPlaying = false.obs;
  final RxInt stepIndex = 0.obs;
  final RxInt secondsLeft = 0.obs;
  final RxDouble stepProgress = 0.0.obs;

  // Well done.
  final Rxn<int> feelAfter = Rxn<int>();
  final RxInt weekMinutes = 0.obs;
  final RxInt streak = 0.obs;

  MeditationPlayerEngine? _engine;
  Timer? _timer;
  DateTime? _startedAt;

  int _speechToken = 0;
  bool _speechBusy = false;
  bool _needsRespeak = false;
  bool _voiceFailureShown = false;
  bool _wasPlayingBeforeDialog = false;
  StreamSubscription<void>? _interruptions;

  MeditationLogEntry? _logged;
  List<MeditationLogEntry> _loadedLogs = <MeditationLogEntry>[];

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  // ---------------------------------------------------------------------------
  // What the screens read.
  // ---------------------------------------------------------------------------

  int get stepCount => session.value?.steps.length ?? 0;

  /// The title of the group the practice belongs to, e.g. "Between patients".
  String? get groupTitle {
    final MeditationSession? current = session.value;
    if (current == null) {
      return null;
    }
    return _repository.groupById(current.groupId)?.title;
  }

  /// The text of the current step.
  String get stepText {
    final MeditationSession? current = session.value;
    if (current == null) {
      return '';
    }
    final int index = stepIndex.value.clamp(0, current.steps.length - 1);
    return current.steps[index].text;
  }

  bool get isFirstStep => stepIndex.value == 0;

  bool get isLastStep => stepIndex.value >= stepCount - 1;

  /// Whether this practice can be read aloud on this phone.
  bool get canSpeak =>
      (session.value?.hasVoice ?? false) && voiceAvailable.value;

  /// Time left, e.g. "1:15".
  String get timeLeftLabel => formatTimeLeft(secondsLeft.value);

  static String formatTimeLeft(int seconds) {
    final int safe = seconds < 0 ? 0 : seconds;
    final String rest = (safe % 60).toString().padLeft(2, '0');
    return '${safe ~/ 60}:$rest';
  }

  bool get _voiceActive =>
      voiceEnabled.value &&
      voiceAvailable.value &&
      (session.value?.hasVoice ?? false);

  // ---------------------------------------------------------------------------
  // Loading.
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    try {
      final Object? source = _source;
      MeditationSession? found;
      if (source is MeditationSession) {
        found = source;
      } else if (source is String) {
        found = await _repository.findSession(source);
      }
      if (found == null) {
        hasLoadError.value = true;
        return;
      }

      session.value = found;
      List<int>? lengths;
      try {
        lengths = await _audio.prepare(found);
      } catch (_) {
        lengths = null; // Steps keep their own length; the backup voice reads.
      }
      _engine = MeditationPlayerEngine(found.steps, stepSeconds: lengths);
      _syncFromEngine();
      voiceEnabled.value = found.hasVoice && await _repository.isVoiceEnabled();
      await _loadAmbient();
      _interruptions = _audio.interruptions.listen((_) => pause());
      unawaited(_loadLogs());
    } catch (_) {
      hasLoadError.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadAmbient() async {
    try {
      ambient.value = await _repository.getAmbient();
      ambientVolume.value = await _repository.getAmbientVolume();
      await _audio.setAmbientVolume(ambientVolume.value);
      await _audio.setAmbient(ambient.value);
    } catch (_) {
      // Off, at the default volume.
    }
  }

  Future<void> _loadLogs() async {
    try {
      _loadedLogs = await _repository.getRecentLogs();
      _refreshStats();
    } catch (_) {
      // The chips then count only this practice.
    }
  }

  // ---------------------------------------------------------------------------
  // Check-in.
  // ---------------------------------------------------------------------------

  void beginCheckIn() => Get.toNamed(AppRoutes.meditationCheckIn);

  void setFeelBefore(int value) => feelBefore.value = value;

  /// The "Voice guidance" switch. This choice is remembered.
  void setVoiceGuidance(bool enabled) {
    voiceEnabled.value = enabled && (session.value?.hasVoice ?? false);
    unawaited(_repository.setVoiceEnabled(enabled));
  }

  /// "Start practice".
  void startPractice() {
    if (_engine == null) {
      return;
    }
    _startedAt = DateTime.now();
    _beginPlayback();
    Get.offNamed(AppRoutes.meditationPlayer);
  }

  /// "Skip the check-in".
  void skipCheckIn() {
    feelBefore.value = null;
    startPractice();
  }

  // ---------------------------------------------------------------------------
  // Player.
  // ---------------------------------------------------------------------------

  void _beginPlayback() {
    final MeditationPlayerEngine? engine = _engine;
    if (engine == null) {
      return;
    }
    engine.play();
    _startTimer();
    unawaited(_keepAwake.enable());
    _speakCurrentStep();
    _syncFromEngine();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_tickInterval, (Timer timer) => _onTick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _onTick() {
    final MeditationPlayerEngine? engine = _engine;
    if (engine == null) {
      return;
    }
    _handle(engine.tick(holdForSpeech: _speechBusy));
    _syncFromEngine();
  }

  void _handle(PlayerTick result) {
    switch (result) {
      case PlayerTick.none:
        break;
      case PlayerTick.stepChanged:
        _speakCurrentStep();
      case PlayerTick.finished:
        _onFinished();
    }
  }

  void togglePlayPause() {
    if (isPlaying.value) {
      pause();
    } else {
      resume();
    }
  }

  void pause() {
    final MeditationPlayerEngine? engine = _engine;
    if (engine == null || !engine.isPlaying) {
      return;
    }
    engine.pause();
    _stopTimer();
    // The clip pauses where it is and continues on resume.
    unawaited(_audio.pause());
    unawaited(_keepAwake.disable());
    _syncFromEngine();
  }

  void resume() {
    final MeditationPlayerEngine? engine = _engine;
    if (engine == null || engine.isEnded || engine.isPlaying) {
      return;
    }
    engine.play();
    _startTimer();
    unawaited(_keepAwake.enable());
    if (_needsRespeak) {
      // A step was changed while paused: it starts from the beginning.
      _speakCurrentStep();
    } else {
      unawaited(_audio.resume());
    }
    _syncFromEngine();
  }

  /// Jumps to the start of the next step.
  void next() {
    final MeditationPlayerEngine? engine = _engine;
    if (engine == null || !engine.next()) {
      return;
    }
    _afterJump();
  }

  /// Jumps to the start of the previous step (or restarts the first one).
  void previous() {
    final MeditationPlayerEngine? engine = _engine;
    if (engine == null || !engine.previous()) {
      return;
    }
    _afterJump();
  }

  void _afterJump() {
    if (_engine?.isPlaying ?? false) {
      _speakCurrentStep();
    } else {
      // Paused: start the new step when playback resumes.
      _speechToken++;
      _speechBusy = false;
      _needsRespeak = true;
      unawaited(_audio.stopVoice());
    }
    _syncFromEngine();
  }

  /// The voice button in the player. This only affects the current practice.
  void toggleVoice() {
    if (!canSpeak) {
      return;
    }
    final bool enabled = !voiceEnabled.value;
    voiceEnabled.value = enabled;
    if (!enabled) {
      _speechToken++;
      _speechBusy = false;
      unawaited(_audio.stopVoice());
    } else if (_engine?.isPlaying ?? false) {
      _speakCurrentStep();
    } else {
      _needsRespeak = true;
    }
  }

  /// Pauses while the "End this practice?" question is on screen.
  void pauseForDialog() {
    _wasPlayingBeforeDialog = isPlaying.value;
    pause();
  }

  /// "Keep going".
  void resumeAfterDialog() {
    if (_wasPlayingBeforeDialog) {
      resume();
    }
    _wasPlayingBeforeDialog = false;
  }

  /// "End": saves the practice as not completed (if any of it was done) and
  /// leaves.
  void endEarly() {
    final MeditationPlayerEngine? engine = _engine;
    if (engine == null) {
      _leaveFlow();
      return;
    }
    _stopTimer();
    engine.endEarly();
    _speechToken++;
    _speechBusy = false;
    unawaited(_audio.stop());
    unawaited(_keepAwake.disable());
    _syncFromEngine();
    if (engine.secondsPractised > 0) {
      _saveLog(completed: false);
    }
    _leaveFlow();
  }

  void _onFinished() {
    _stopTimer();
    _speechToken++;
    _speechBusy = false;
    unawaited(_audio.stop());
    unawaited(_keepAwake.disable());
    _saveLog(completed: true);
    Get.offNamed(AppRoutes.meditationComplete);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      pause();
    }
  }

  // ---------------------------------------------------------------------------
  // Voice.
  // ---------------------------------------------------------------------------

  /// Starts the current step's sound: the background, and its recorded
  /// clip (or the backup voice) when the voice is on. Anything still being
  /// said is replaced.
  void _speakCurrentStep() {
    final int token = ++_speechToken;
    _speechBusy = false;
    _needsRespeak = false;

    final MeditationPlayerEngine? engine = _engine;
    if (engine == null) {
      return;
    }
    final bool voice = _voiceActive;
    _speechBusy = voice;
    unawaited(
      _audio.playStep(engine.stepIndex, voice: voice).then((
        SpeechOutcome outcome,
      ) {
        if (voice) {
          _onSpeechOutcome(token, outcome);
        }
      }),
    );
  }

  void _onSpeechOutcome(int token, SpeechOutcome outcome) {
    if (token != _speechToken) {
      return; // Stopped or replaced since.
    }
    _speechBusy = false;

    if (outcome == SpeechOutcome.failed) {
      _onVoiceFailed();
    }

    // The step's time may be up already, with the practice waiting for the
    // voice to finish.
    final MeditationPlayerEngine? engine = _engine;
    if (engine != null && engine.isPlaying) {
      _handle(engine.advanceIfStepTimeUp());
      _syncFromEngine();
    }
  }

  void _onVoiceFailed() {
    voiceAvailable.value = false;
    if (_voiceFailureShown) {
      return;
    }
    _voiceFailureShown = true;
    showMindMateSnackBar(
      'Voice is not available',
      'The text will keep showing, so you can carry on silently.',
    );
  }

  // ---------------------------------------------------------------------------
  // Background sound.
  // ---------------------------------------------------------------------------

  /// A choice in the "Background sound" sheet. It plays at once so it can be
  /// heard, and is remembered.
  void selectAmbient(AmbientChoice choice) {
    ambient.value = choice;
    unawaited(_audio.setAmbient(choice, preview: choice != AmbientChoice.off));
    unawaited(_repository.setAmbient(choice).catchError((Object _) {}));
  }

  /// While the slider moves.
  void setAmbientVolume(double volume) {
    final double v = MeditationAudioRules.clampVolume(volume);
    ambientVolume.value = v;
    unawaited(_audio.setAmbientVolume(v));
  }

  /// When the slider is let go.
  void saveAmbientVolume() {
    unawaited(
      _repository
          .setAmbientVolume(ambientVolume.value)
          .catchError((Object _) {}),
    );
  }

  // ---------------------------------------------------------------------------
  // Saving and the "Well done" screen.
  // ---------------------------------------------------------------------------

  void _saveLog({required bool completed}) {
    final MeditationSession? current = session.value;
    final MeditationPlayerEngine? engine = _engine;
    final DateTime? startedAt = _startedAt;
    if (current == null || engine == null || startedAt == null) {
      return;
    }

    String id = '';
    try {
      id = _repository.newLogId();
    } catch (error) {
      showMindMateSnackBar(
        'Could not save this practice',
        _saveErrorMessage(error),
      );
    }

    final MeditationLogEntry entry = MeditationLogEntry(
      id: id,
      sessionId: current.id,
      title: current.title,
      startedAt: startedAt,
      endedAt: DateTime.now(),
      secondsPractised: engine.secondsPractised,
      completed: completed,
      feelBefore: feelBefore.value,
    );
    _logged = entry;
    _refreshStats();

    // Without an id the practice could not be saved, so the library does not
    // count it.
    if (id.isNotEmpty) {
      _notifyLibrary(entry);
      unawaited(_persist(entry));
    }
  }

  /// Not awaited by the screens: with no connection a write only finishes
  /// when the phone is back online, and the practice must not wait for it.
  Future<void> _persist(MeditationLogEntry entry) async {
    try {
      await _repository.saveLog(entry);
    } catch (error) {
      showMindMateSnackBar(
        'Could not save this practice',
        _saveErrorMessage(error),
      );
    }
  }

  /// "How do you feel now?" on the "Well done" screen.
  void setFeelAfter(int value) {
    feelAfter.value = value;

    final MeditationLogEntry? logged = _logged;
    if (logged == null) {
      return;
    }
    final MeditationLogEntry updated = logged.copyWith(feelAfter: value);
    _logged = updated;

    if (updated.id.isNotEmpty) {
      _notifyLibrary(updated);
      unawaited(_persistFeelAfter(updated.id, value));
    }
  }

  Future<void> _persistFeelAfter(String id, int value) async {
    try {
      await _repository.updateFeelAfter(id, value);
    } catch (error) {
      showMindMateSnackBar(
        'Could not save how you feel',
        _saveErrorMessage(error),
      );
    }
  }

  void _refreshStats() {
    final DateTime now = DateTime.now();
    final MeditationLogEntry? logged = _logged;
    final List<MeditationLogEntry> all = <MeditationLogEntry>[
      ..._loadedLogs.where(
        (MeditationLogEntry log) => logged == null || log.id != logged.id,
      ),
      ?logged,
    ];
    weekMinutes.value = MeditationStats.minutesThisWeek(all, now: now);
    streak.value = MeditationStats.streak(all, now: now);
  }

  void _notifyLibrary(MeditationLogEntry entry) {
    if (Get.isRegistered<MeditationViewModel>()) {
      Get.find<MeditationViewModel>().recordLog(entry);
    }
  }

  String _saveErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      return 'Please sign in again to save your practices.';
    }
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'You do not have permission to save this.';
    }
    return 'Please try again later.';
  }

  // ---------------------------------------------------------------------------
  // Leaving.
  // ---------------------------------------------------------------------------

  /// "Done": back to where the practice was started from.
  void done() => _leaveFlow();

  /// "Log this in Mood".
  void logInMood() {
    _leaveFlow();
    Get.toNamed(AppRoutes.moodLog);
  }

  /// Pops every screen of this practice, down to the one beneath (the library,
  /// or wherever the practice was opened from).
  void _leaveFlow() {
    Get.until(
      (Route<dynamic> route) => !flowRoutes.contains(route.settings.name),
    );
  }

  void _syncFromEngine() {
    final MeditationPlayerEngine? engine = _engine;
    if (engine == null) {
      return;
    }
    isPlaying.value = engine.isPlaying;
    stepIndex.value = engine.stepIndex;
    secondsLeft.value = engine.secondsLeft;
    stepProgress.value = engine.stepProgress;
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTimer();
    _speechToken++;
    unawaited(_interruptions?.cancel());
    // Fades the background out and releases the players.
    unawaited(_audio.dispose());
    unawaited(_keepAwake.disable());
    super.onClose();
  }
}
