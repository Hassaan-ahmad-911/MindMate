import 'package:shared_preferences/shared_preferences.dart';

import '../../Models/breathing_sessions.dart';
import '../../Models/meditation_audio.dart';
import '../../Models/meditation_log_entry.dart';
import '../../Models/meditation_models.dart';
import '../../Models/meditation_stats.dart';
import '../../services/meditation_content_service.dart';
import '../../services/meditation_log_service.dart';
import 'settings_repository.dart';

/// The practices (from the content file, plus the breathing practices) and the
/// user's practice history.
class MeditationRepository {
  MeditationRepository(
    this._contentService,
    this._logService, {
    SettingsRepository? settings,
  }) : _settings = settings;

  final SettingsRepository? _settings;

  static const String _voiceEnabledKey = 'meditation_voice_enabled';

  final MeditationContentService _contentService;
  final MeditationLogService _logService;

  /// Loads the practices. Safe to call again: the file is read only once.
  Future<void> loadContent() => _contentService.load();

  bool get isLoaded => _contentService.content != null;

  /// The groups from the content file, then "Breathing". Empty until
  /// [loadContent] has finished.
  List<MeditationGroup> get groups {
    final MeditationContent? content = _contentService.content;
    if (content == null) {
      return const <MeditationGroup>[];
    }
    return <MeditationGroup>[...content.groups, BreathingLibrary.group];
  }

  /// The guided practices in file order, then the breathing practices.
  /// Empty until [loadContent] has finished.
  List<MeditationSession> get sessions {
    final MeditationContent? content = _contentService.content;
    if (content == null) {
      return const <MeditationSession>[];
    }
    return <MeditationSession>[
      ...content.sessions,
      ...BreathingLibrary.sessions,
    ];
  }

  /// A practice by id, or null if it is not there (or not loaded yet).
  MeditationSession? sessionById(String id) {
    for (final MeditationSession session in sessions) {
      if (session.id == id) {
        return session;
      }
    }
    return null;
  }

  /// Like [sessionById], but loads the practices first if needed.
  Future<MeditationSession?> findSession(String id) async {
    await loadContent();
    return sessionById(id);
  }

  MeditationGroup? groupById(String id) {
    for (final MeditationGroup group in groups) {
      if (group.id == id) {
        return group;
      }
    }
    return null;
  }

  /// Practices from the last 90 days (enough for the streak), newest first.
  Future<List<MeditationLogEntry>> getRecentLogs({DateTime? now}) {
    return _logService.getSessionsSince(
      MeditationStats.historyStart(now ?? DateTime.now()),
    );
  }

  /// Practices started with [start] <= startedAt < [end], newest first.
  Future<List<MeditationLogEntry>> getLogsBetween(
    DateTime start,
    DateTime end,
  ) {
    return _logService.getSessionsBetween(start, end);
  }

  String newLogId() => _logService.newId();

  Future<void> saveLog(MeditationLogEntry entry) {
    return _logService.saveSession(entry);
  }

  Future<void> updateFeelAfter(String id, int feelAfter) {
    return _logService.updateFeelAfter(id, feelAfter);
  }

  /// Whether voice guidance is on. It is on until the user turns it off.
  Future<bool> isVoiceEnabled() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_voiceEnabledKey) ?? true;
  }

  Future<void> setVoiceEnabled(bool enabled) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_voiceEnabledKey, enabled);
  }

  // The background sound. It lives in the user's settings
  // (`settings.meditationSound`), shared with the Settings screen.

  /// Off until the user picks a sound, or when settings cannot be read.
  Future<AmbientChoice> getAmbient() async {
    final SettingsRepository? settings = _settings;
    if (settings == null) {
      return AmbientChoice.off;
    }
    return AmbientChoice.fromId((await settings.load()).meditationSound);
  }

  Future<void> setAmbient(AmbientChoice choice) async {
    await _settings?.setMeditationSound(choice.id);
  }

  Future<double> getAmbientVolume() async {
    final SettingsRepository? settings = _settings;
    if (settings == null) {
      return MeditationAudioRules.defaultAmbientVolume;
    }
    return MeditationAudioRules.clampVolume(
      (await settings.load()).meditationSoundVolume,
    );
  }

  Future<void> setAmbientVolume(double volume) async {
    await _settings?.setMeditationSoundVolume(
      MeditationAudioRules.clampVolume(volume),
    );
  }
}
