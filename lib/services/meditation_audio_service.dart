import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../Models/meditation_audio.dart';
import '../Models/meditation_models.dart';
import 'meditation_voice_service.dart';

/// Everything a guided practice sounds like: the recorded voice (or the
/// backup voice), and the optional background sound. The player ViewModel
/// talks only to this; it never touches audio players.
abstract class MeditationAudioService {
  /// Loads the practice's clips. Returns each step's length in seconds: its
  /// own seconds, or longer when its recorded clip needs it.
  Future<List<int>> prepare(MeditationSession session);

  /// Whether step [index] has a matching recorded clip.
  bool usesRecordedClip(int index);

  /// Starts step [index]: the background sound (fading in the first time)
  /// and, when [voice] is true, its clip or the backup voice from the
  /// beginning. Anything still speaking is stopped first. Completes when the
  /// voice for this step ends: [SpeechOutcome.completed] at once without
  /// voice, [SpeechOutcome.interrupted] if it was stopped or replaced.
  Future<SpeechOutcome> playStep(int index, {required bool voice});

  /// Stops the voice (the background keeps playing).
  Future<void> stopVoice();

  /// Pauses the voice, the background and anything in between.
  Future<void> pause();

  /// Continues the clip from where it paused (the backup voice repeats the
  /// sentence it was on) and the background.
  Future<void> resume();

  /// The practice ended: the voice stops, the background fades out.
  Future<void> stop();

  /// [preview] plays the chosen sound now, so it can be heard from the
  /// sheet before or during a practice.
  Future<void> setAmbient(AmbientChoice choice, {bool preview = false});

  /// 0 to 0.6.
  Future<void> setAmbientVolume(double volume);

  /// Fires when a phone call or another app interrupts, or headphones are
  /// unplugged. The practice then pauses and does not resume by itself.
  Stream<void> get interruptions;

  /// Fades out and releases the players (the screen closed, or logout).
  Future<void> dispose();
}

/// [MeditationAudioService] on `just_audio`, with `flutter_tts` as the
/// backup voice. Nothing about the content is ever logged.
class JustAudioMeditationService implements MeditationAudioService {
  JustAudioMeditationService({
    required MeditationVoiceService backupVoice,
    Future<String> Function(String path)? loadString,
  }) : _backup = backupVoice,
       _loadString = loadString ?? rootBundle.loadString;

  final MeditationVoiceService _backup;
  final Future<String> Function(String) _loadString;

  static const Duration _rampTick = Duration(milliseconds: 40);

  VoiceManifest? _manifest;
  MeditationSession? _session;
  List<VoiceClip?> _clips = const <VoiceClip?>[];

  AudioPlayer? _current;
  AudioPlayer? _next;
  int? _nextIndex;
  AudioPlayer? _ambientPlayer;
  AmbientChoice? _loadedAmbient;

  AmbientChoice _ambient = AmbientChoice.off;
  double _volume = MeditationAudioRules.defaultAmbientVolume;
  double _ambientLevel = 0;
  bool _voiceSpeaking = false;
  Timer? _ramp;
  VoidCallback? _rampDone;

  int _token = 0;
  Completer<SpeechOutcome>? _voiceDone;
  StreamSubscription<ProcessingState>? _clipEnd;
  bool _clipPlaying = false;
  bool _backupRunning = false;
  bool _paused = false;
  bool _active = false;
  Completer<void>? _resumed;

  bool _sessionConfigured = false;
  final StreamController<void> _interruptions =
      StreamController<void>.broadcast();

  @override
  Stream<void> get interruptions => _interruptions.stream;

  // Setting up.

  Future<void> _configureSession() async {
    if (_sessionConfigured) {
      return;
    }
    _sessionConfigured = true;
    try {
      final AudioSession session = await AudioSession.instance;
      // Spoken audio that lowers other apps (such as music) and plays even
      // with the ring/silent switch on.
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: true,
        ),
      );
      session.interruptionEventStream.listen((AudioInterruptionEvent e) {
        if (e.begin && e.type != AudioInterruptionType.duck) {
          _interruptions.add(null);
        }
      });
      session.becomingNoisyEventStream.listen((_) => _interruptions.add(null));
    } catch (_) {
      // Playback still works with the default session.
    }
  }

  AudioPlayer _newPlayer() => AudioPlayer(
    handleInterruptions: false,
    handleAudioSessionActivation: true,
  );

  @override
  Future<List<int>> prepare(MeditationSession session) async {
    await _configureSession();
    _session = session;
    _current ??= _newPlayer();
    _next ??= _newPlayer();
    _nextIndex = null;
    try {
      _manifest ??= VoiceManifest.fromJson(
        await _loadString(VoiceManifest.assetPath),
      );
    } catch (_) {
      _manifest = null;
    }
    final List<VoiceClip> clips =
        _manifest?.clipsFor(session.id) ?? const <VoiceClip>[];
    _clips = <VoiceClip?>[
      for (int i = 0; i < session.steps.length; i += 1)
        session.hasVoice
            ? MeditationAudioRules.clipFor(clips, i, session.steps[i].text)
            : null,
    ];
    return <int>[
      for (int i = 0; i < session.steps.length; i += 1)
        MeditationAudioRules.stepSeconds(session.steps[i].seconds, _clips[i]),
    ];
  }

  @override
  bool usesRecordedClip(int index) =>
      index >= 0 && index < _clips.length && _clips[index] != null;

  // The voice.

  @override
  Future<SpeechOutcome> playStep(int index, {required bool voice}) async {
    final MeditationSession? session = _session;
    if (session == null || index < 0 || index >= session.steps.length) {
      return SpeechOutcome.failed;
    }
    await stopVoice();
    _active = true;
    if (_paused) {
      _paused = false;
      _resumed?.complete();
      _resumed = null;
    }
    unawaited(_ensureAmbientPlaying());
    if (!voice) {
      return SpeechOutcome.completed;
    }

    final int token = ++_token;
    final Completer<SpeechOutcome> done = Completer<SpeechOutcome>();
    _voiceDone = done;
    _setVoiceSpeaking(true);

    final VoiceClip? clip = _clips[index];
    if (clip == null || !await _playClip(token, index, clip)) {
      if (token == _token) {
        unawaited(_runBackup(token, session.steps[index].text));
      }
    }
    return done.future;
  }

  /// True if the clip started.
  Future<bool> _playClip(int token, int index, VoiceClip clip) async {
    try {
      AudioPlayer player;
      if (_nextIndex == index && _next != null) {
        // Swap: the preloaded player becomes the current one.
        player = _next!;
        _next = _current;
        _current = player;
      } else {
        player = _current ??= _newPlayer();
        await player.setAsset(clip.assetPath);
      }
      _nextIndex = null;
      if (token != _token) {
        return true;
      }
      await player.seek(Duration.zero);
      await player.setVolume(1.0);
      _clipEnd?.cancel();
      _clipEnd = player.processingStateStream.listen((ProcessingState s) {
        if (s == ProcessingState.completed) {
          _finish(token, SpeechOutcome.completed);
        }
      });
      _clipPlaying = true;
      unawaited(player.play());
      unawaited(_preload(index + 1));
      return true;
    } catch (_) {
      _clipPlaying = false;
      return false;
    }
  }

  /// Loads the next step's clip while this one plays, so it starts at once.
  Future<void> _preload(int index) async {
    if (index >= _clips.length) {
      return;
    }
    final VoiceClip? clip = _clips[index];
    final AudioPlayer? player = _next;
    if (clip == null || player == null) {
      return;
    }
    try {
      await player.setAsset(clip.assetPath);
      _nextIndex = index;
    } catch (_) {
      _nextIndex = null;
    }
  }

  /// The backup voice, sentence by sentence with a pause between them. After
  /// a pause it repeats the sentence it was on.
  Future<void> _runBackup(int token, String text) async {
    _backupRunning = true;
    final List<String> sentences = MeditationAudioRules.sentences(text);
    int i = 0;
    while (i < sentences.length) {
      if (token != _token) {
        return;
      }
      if (_paused) {
        await (_resumed ??= Completer<void>()).future;
        continue;
      }
      final SpeechOutcome outcome = await _backup.speak(sentences[i]);
      if (token != _token) {
        return;
      }
      if (outcome == SpeechOutcome.failed) {
        _finish(token, SpeechOutcome.failed);
        return;
      }
      if (outcome == SpeechOutcome.interrupted) {
        continue; // Paused mid-sentence: say it again on resume.
      }
      i += 1;
      if (i < sentences.length) {
        await Future<void>.delayed(MeditationAudioRules.sentenceGap);
      }
    }
    _finish(token, SpeechOutcome.completed);
  }

  void _finish(int token, SpeechOutcome outcome) {
    if (token != _token) {
      return;
    }
    _clipEnd?.cancel();
    _clipEnd = null;
    _clipPlaying = false;
    _backupRunning = false;
    _setVoiceSpeaking(false);
    final Completer<SpeechOutcome>? done = _voiceDone;
    _voiceDone = null;
    if (done != null && !done.isCompleted) {
      done.complete(outcome);
    }
  }

  @override
  Future<void> stopVoice() async {
    final bool clip = _clipPlaying;
    final bool backup = _backupRunning;
    _token += 1;
    _clipEnd?.cancel();
    _clipEnd = null;
    _clipPlaying = false;
    _backupRunning = false;
    _setVoiceSpeaking(false);
    final Completer<SpeechOutcome>? done = _voiceDone;
    _voiceDone = null;
    if (done != null && !done.isCompleted) {
      done.complete(SpeechOutcome.interrupted);
    }
    _resumed?.complete();
    _resumed = null;
    if (clip) {
      try {
        await _current?.pause();
      } catch (_) {}
    }
    if (backup) {
      await _backup.stop();
    }
  }

  @override
  Future<void> pause() async {
    if (_paused) {
      return;
    }
    _paused = true;
    _resumed ??= Completer<void>();
    _ramp?.cancel();
    try {
      if (_clipPlaying) {
        await _current?.pause();
      }
      if (_backupRunning) {
        await _backup.stop();
      }
      await _ambientPlayer?.pause();
    } catch (_) {}
  }

  @override
  Future<void> resume() async {
    if (!_paused) {
      return;
    }
    _paused = false;
    _resumed?.complete();
    _resumed = null;
    try {
      if (_clipPlaying) {
        unawaited(_current?.play());
      }
    } catch (_) {}
    unawaited(_ensureAmbientPlaying(fade: MeditationAudioRules.duckUp));
  }

  @override
  Future<void> stop() async {
    await stopVoice();
    _active = false;
    _paused = false;
    await _fadeAmbientOut(MeditationAudioRules.ambientFade);
  }

  // The background sound.

  double get _target => MeditationAudioRules.ambientTarget(
    _volume,
    voiceSpeaking: _voiceSpeaking,
  );

  Future<void> _ensureAmbientPlaying({
    Duration fade = MeditationAudioRules.ambientFade,
  }) async {
    final String? asset = _ambient.assetPath;
    if (asset == null || _paused) {
      return;
    }
    try {
      final AudioPlayer player = _ambientPlayer ??= _newPlayer();
      if (_loadedAmbient != _ambient) {
        await player.setAsset(asset);
        await player.setLoopMode(LoopMode.one);
        _loadedAmbient = _ambient;
        _ambientLevel = 0;
        await player.setVolume(0);
      }
      if (!player.playing) {
        unawaited(player.play());
      }
      _rampTo(_target, fade);
    } catch (_) {
      // The practice carries on without the background sound.
    }
  }

  Future<void> _fadeAmbientOut(Duration fade) async {
    final AudioPlayer? player = _ambientPlayer;
    if (player == null || !player.playing) {
      return;
    }
    final Completer<void> faded = Completer<void>();
    _rampTo(0, fade, onDone: faded.complete);
    await faded.future;
    try {
      await player.pause();
    } catch (_) {}
  }

  /// Moves the background volume to [target] over [duration]. A ramp that
  /// is replaced still calls its [onDone], so nothing waits for it forever.
  void _rampTo(double target, Duration duration, {VoidCallback? onDone}) {
    _ramp?.cancel();
    final VoidCallback? replaced = _rampDone;
    _rampDone = onDone;
    replaced?.call();
    final AudioPlayer? player = _ambientPlayer;
    if (player == null) {
      _rampDone = null;
      onDone?.call();
      return;
    }
    final double start = _ambientLevel;
    final int steps = (duration.inMilliseconds / _rampTick.inMilliseconds)
        .ceil()
        .clamp(1, 1000);
    int i = 0;
    _ramp = Timer.periodic(_rampTick, (Timer t) {
      i += 1;
      final double v = start + (target - start) * (i / steps);
      _ambientLevel = v;
      unawaited(player.setVolume(v.clamp(0.0, 1.0)).catchError((_) {}));
      if (i >= steps) {
        t.cancel();
        if (_rampDone == onDone) {
          _rampDone = null;
        }
        onDone?.call();
      }
    });
  }

  /// Ducking: the background drops to 60% over 400 ms while the voice
  /// speaks and comes back over 800 ms after.
  void _setVoiceSpeaking(bool speaking) {
    if (_voiceSpeaking == speaking) {
      return;
    }
    _voiceSpeaking = speaking;
    if (_ambientPlayer?.playing ?? false) {
      _rampTo(
        _target,
        speaking ? MeditationAudioRules.duckDown : MeditationAudioRules.duckUp,
      );
    }
  }

  @override
  Future<void> setAmbient(AmbientChoice choice, {bool preview = false}) async {
    if (choice == _ambient && !preview) {
      return;
    }
    final bool changed = choice != _ambient;
    _ambient = choice;
    if (choice == AmbientChoice.off) {
      await _fadeAmbientOut(MeditationAudioRules.duckUp);
      return;
    }
    if (changed) {
      await _ambientPlayer?.pause();
    }
    if (_active || preview) {
      await _configureSession();
      final bool wasPaused = _paused;
      _paused = false;
      await _ensureAmbientPlaying(fade: MeditationAudioRules.duckUp);
      _paused = wasPaused;
    }
  }

  @override
  Future<void> setAmbientVolume(double volume) async {
    _volume = MeditationAudioRules.clampVolume(volume);
    if (_ambientPlayer?.playing ?? false) {
      _rampTo(_target, const Duration(milliseconds: 120));
    }
  }

  @override
  Future<void> dispose() async {
    await stopVoice();
    _active = false;
    _paused = false;
    final AudioPlayer? current = _current;
    final AudioPlayer? next = _next;
    final AudioPlayer? ambient = _ambientPlayer;
    _current = null;
    _next = null;
    _nextIndex = null;
    _session = null;
    _clips = const <VoiceClip?>[];
    try {
      await current?.dispose();
      await next?.dispose();
    } catch (_) {}
    if (ambient != null) {
      // This player is let go at once, so a new practice gets its own.
      final double from = _ambientLevel;
      _ramp?.cancel();
      final VoidCallback? pending = _rampDone;
      _rampDone = null;
      pending?.call();
      _ambientPlayer = null;
      _loadedAmbient = null;
      _ambientLevel = 0;
      await _fadeOutAndDispose(ambient, from);
    }
  }

  /// Fades a released background player out over 3 s, then disposes it.
  static Future<void> _fadeOutAndDispose(
    AudioPlayer player,
    double from,
  ) async {
    try {
      if (player.playing && from > 0) {
        final int steps =
            MeditationAudioRules.ambientFade.inMilliseconds ~/
            _rampTick.inMilliseconds;
        for (int i = 1; i <= steps; i += 1) {
          await Future<void>.delayed(_rampTick);
          await player.setVolume(from * (1 - i / steps));
        }
      }
      await player.dispose();
    } catch (_) {}
  }
}
