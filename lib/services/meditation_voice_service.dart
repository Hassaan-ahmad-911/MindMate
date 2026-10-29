import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// How a spoken step ended.
enum SpeechOutcome {
  /// The whole text was read out.
  completed,

  /// It was stopped, or replaced by other text.
  interrupted,

  /// The voice is not available, or did not start.
  failed,
}

/// Reads practice steps aloud.
abstract class MeditationVoiceService {
  /// Speaks [text] and completes when the speech ends. Never throws: if the
  /// voice cannot be used the result is [SpeechOutcome.failed].
  Future<SpeechOutcome> speak(String text);

  /// Stops any speech right now.
  Future<void> stop();
}

/// The phone's own text-to-speech voice, at a slow, calm pace. It is only
/// the backup: practices use their recorded voice clips when they match.
class FlutterTtsVoiceService implements MeditationVoiceService {
  FlutterTtsVoiceService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  /// 0.5 is normal speed on both Android and iOS.
  static double get speechRate =>
      defaultTargetPlatform == TargetPlatform.iOS ? 0.42 : 0.40;

  static const double pitch = 0.92;

  static const List<String> _goodVoiceWords = <String>[
    'network',
    'enhanced',
    'premium',
    'neural',
  ];

  /// The first English voice whose name sounds like a higher-quality one,
  /// preferring en-GB, then en-US, then any English. Null keeps the default.
  static Map<String, String>? pickVoice(List<Map<String, String>> voices) {
    bool good(Map<String, String> v) {
      final String name = (v['name'] ?? '').toLowerCase();
      return _goodVoiceWords.any(name.contains);
    }

    String locale(Map<String, String> v) =>
        (v['locale'] ?? '').toLowerCase().replaceAll('_', '-');

    for (final String wanted in <String>['en-gb', 'en-us', 'en']) {
      for (final Map<String, String> v in voices) {
        if (good(v) && locale(v).startsWith(wanted)) {
          return v;
        }
      }
    }
    return null;
  }

  static const Duration _setupTimeout = Duration(seconds: 4);
  static const Duration _startTimeout = Duration(seconds: 8);
  static const Duration _stopTimeout = Duration(seconds: 2);

  final FlutterTts _tts;

  Future<void>? _setup;
  Completer<SpeechOutcome>? _pending;
  Timer? _startWatchdog;
  int _generation = 0;

  Future<void> _configure() async {
    _tts.setStartHandler(_onStarted);
    _tts.setCompletionHandler(_onCompleted);
    _tts.setErrorHandler(_onError);
    // The cancel handler is left unset on purpose. stop() ends a pending
    // speech itself, and a late "cancel" from an older utterance must not end
    // a newer one.
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(speechRate);
    await _tts.setPitch(pitch);
    await _tts.setVolume(1.0);
    try {
      final Object? raw = await _tts.getVoices;
      final List<Map<String, String>> voices = <Map<String, String>>[
        if (raw is List)
          for (final Object? v in raw)
            if (v is Map)
              <String, String>{
                for (final MapEntry<dynamic, dynamic> e in v.entries)
                  '${e.key}': '${e.value}',
              },
      ];
      final Map<String, String>? chosen = pickVoice(voices);
      if (chosen != null) {
        await _tts.setVoice(chosen);
      }
    } catch (_) {
      // Keep the default voice.
    }
  }

  /// Sets the voice up once. A voice that cannot start up must not hold a
  /// practice back, so this gives up after a few seconds.
  Future<bool> _ensureSetup() async {
    try {
      await (_setup ??= _configure()).timeout(_setupTimeout);
      return true;
    } catch (_) {
      _setup = null;
      return false;
    }
  }

  @override
  Future<SpeechOutcome> speak(String text) async {
    final int generation = ++_generation;
    _finish(SpeechOutcome.interrupted);

    if (!await _ensureSetup()) {
      return SpeechOutcome.failed;
    }
    if (generation != _generation) {
      return SpeechOutcome.interrupted;
    }

    final Completer<SpeechOutcome> completer = Completer<SpeechOutcome>();
    _pending = completer;
    _startWatchdog?.cancel();
    _startWatchdog = Timer(_startTimeout, () => _finish(SpeechOutcome.failed));

    try {
      await _tts.speak(text).timeout(_startTimeout);
    } catch (_) {
      if (generation == _generation) {
        _finish(SpeechOutcome.failed);
      }
    }
    return completer.future;
  }

  @override
  Future<void> stop() async {
    _generation += 1;
    _finish(SpeechOutcome.interrupted);
    if (_setup == null) {
      return;
    }
    try {
      await _tts.stop().timeout(_stopTimeout);
    } catch (_) {
      // Nothing more to do if the voice cannot be stopped.
    }
  }

  void _onStarted() {
    _startWatchdog?.cancel();
    _startWatchdog = null;
  }

  void _onCompleted() => _finish(SpeechOutcome.completed);

  void _onError(dynamic message) => _finish(SpeechOutcome.failed);

  void _finish(SpeechOutcome outcome) {
    _startWatchdog?.cancel();
    _startWatchdog = null;
    final Completer<SpeechOutcome>? completer = _pending;
    _pending = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(outcome);
    }
  }
}
