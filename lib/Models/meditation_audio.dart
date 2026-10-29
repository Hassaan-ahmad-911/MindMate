import 'dart:convert';

/// One recorded voice clip from `voice_manifest.json`.
class VoiceClip {
  const VoiceClip({
    required this.index,
    required this.file,
    required this.text,
    required this.durationMs,
  });

  /// The step it belongs to, counted from 0 like the app's steps.
  final int index;

  /// The file name in `assets/meditation/voice/`.
  final String file;

  /// The exact text that was recorded.
  final String text;
  final int durationMs;

  String get assetPath => '${VoiceManifest.folder}/$file';

  static VoiceClip? fromMap(Map<String, dynamic> map) {
    final Object? index = map['index'];
    final Object? file = map['file'];
    final Object? text = map['text'];
    final Object? ms = map['durationMs'];
    if (index is! num || file is! String || text is! String || ms is! num) {
      return null;
    }
    return VoiceClip(
      index: index.toInt(),
      file: file,
      text: text,
      durationMs: ms.toInt(),
    );
  }
}

/// The recorded clips of every practice.
class VoiceManifest {
  const VoiceManifest(this.sessions);

  static const String folder = 'assets/meditation/voice';
  static const String assetPath = '$folder/voice_manifest.json';

  /// Practice id -> its clips.
  final Map<String, List<VoiceClip>> sessions;

  List<VoiceClip> clipsFor(String sessionId) =>
      sessions[sessionId] ?? const <VoiceClip>[];

  factory VoiceManifest.fromJson(String source) {
    final Object? decoded = jsonDecode(source);
    final Object? sessions = decoded is Map ? decoded['sessions'] : null;
    if (sessions is! Map) {
      throw const FormatException('The voice manifest has no sessions.');
    }
    return VoiceManifest(<String, List<VoiceClip>>{
      for (final MapEntry<dynamic, dynamic> e in sessions.entries)
        if (e.value is List)
          '${e.key}': <VoiceClip>[
            for (final Object? c in e.value as List)
              if (c is Map) ?VoiceClip.fromMap(c.cast<String, dynamic>()),
          ],
    });
  }
}

/// The soft background sounds.
enum AmbientChoice {
  off('off', 'Off', null),
  softRain(
    'soft_rain',
    'Soft rain',
    'assets/meditation/ambient/ambient_soft_rain.m4a',
  ),
  warmTones(
    'warm_tones',
    'Warm tones',
    'assets/meditation/ambient/ambient_warm_tones.m4a',
  );

  const AmbientChoice(this.id, this.label, this.assetPath);

  /// Stored in preferences.
  final String id;
  final String label;
  final String? assetPath;

  static AmbientChoice fromId(String? id) {
    for (final AmbientChoice c in values) {
      if (c.id == id) {
        return c;
      }
    }
    return AmbientChoice.off;
  }
}

/// The rules for the voice and the background sound. Pure Dart.
class MeditationAudioRules {
  const MeditationAudioRules._();

  /// Extra time after a recorded clip before the step may end.
  static const int clipTailMs = 1500;

  static const double defaultAmbientVolume = 0.25;
  static const double maxAmbientVolume = 0.6;

  /// The background drops to this share of its volume while the voice speaks.
  static const double duckFactor = 0.6;
  static const Duration duckDown = Duration(milliseconds: 400);
  static const Duration duckUp = Duration(milliseconds: 800);
  static const Duration ambientFade = Duration(seconds: 3);

  /// Pause between sentences of the backup voice.
  static const Duration sentenceGap = Duration(milliseconds: 700);

  /// The recorded clip for a step: one with the same index whose text is
  /// exactly the step's current text. Anything else (no clip, or a script
  /// edited since recording) means the backup voice, so stale audio never
  /// plays.
  static VoiceClip? clipFor(List<VoiceClip> clips, int index, String text) {
    for (final VoiceClip c in clips) {
      if (c.index == index) {
        return c.text == text ? c : null;
      }
    }
    return null;
  }

  /// A step lasts its own seconds, or the clip plus 1.5 s if that is longer.
  static int stepSeconds(int seconds, VoiceClip? clip) {
    if (clip == null) {
      return seconds;
    }
    final int withTail = ((clip.durationMs + clipTailMs) / 1000).ceil();
    return withTail > seconds ? withTail : seconds;
  }

  /// The backup voice says a step sentence by sentence (split after ".",
  /// "!" and "?"), so it can pause between them.
  static List<String> sentences(String text) {
    return RegExp(r'[^.!?]+[.!?]*')
        .allMatches(text)
        .map((RegExpMatch m) => m.group(0)!.trim())
        .where((String s) => s.isNotEmpty)
        .toList(growable: false);
  }

  /// The background volume while the voice is speaking, or not.
  static double ambientTarget(double volume, {required bool voiceSpeaking}) =>
      voiceSpeaking ? volume * duckFactor : volume;

  static double clampVolume(double v) => v.clamp(0.0, maxAmbientVolume);
}
