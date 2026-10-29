import 'dart:async';
import 'dart:io';

import 'package:mindmate/Data/repositories/meditation_repository.dart';
import 'package:mindmate/Data/repositories/settings_repository.dart';
import 'package:mindmate/Models/meditation_log_entry.dart';
import 'package:mindmate/Models/meditation_models.dart';
import 'package:mindmate/Models/mood_model.dart';
import 'package:mindmate/services/keep_awake_service.dart';
import 'package:mindmate/Models/meditation_audio.dart';
import 'package:mindmate/services/meditation_audio_service.dart';
import 'package:mindmate/services/meditation_content_service.dart';
import 'package:mindmate/services/meditation_log_service.dart';
import 'package:mindmate/services/meditation_voice_service.dart';
import 'package:mindmate/services/mood_firestore_service.dart';

/// The practice's sound, controlled by the test: a step's voice lasts until
/// [finishSpeaking] is called. [spoken] lists the text of every step whose
/// voice was started.
class FakeAudioService implements MeditationAudioService {
  FakeAudioService({this.stepSeconds});

  /// Step lengths [prepare] returns; null keeps each step's own seconds.
  final List<int>? stepSeconds;

  final List<String> spoken = <String>[];

  /// stopVoice, pause and stop calls.
  int stops = 0;
  int pauses = 0;
  int resumes = 0;
  int ended = 0;
  int disposed = 0;
  bool paused = false;
  final List<AmbientChoice> ambientChoices = <AmbientChoice>[];
  final List<double> volumes = <double>[];
  final StreamController<void> interruptController =
      StreamController<void>.broadcast();

  MeditationSession? _session;
  Completer<SpeechOutcome>? _current;

  bool get isSpeaking => _current != null && !_current!.isCompleted;

  @override
  Future<List<int>> prepare(MeditationSession session) async {
    _session = session;
    return stepSeconds ??
        session.steps.map((MeditationStep s) => s.seconds).toList();
  }

  @override
  bool usesRecordedClip(int index) => false;

  @override
  Future<SpeechOutcome> playStep(int index, {required bool voice}) {
    _current?.complete(SpeechOutcome.interrupted);
    _current = null;
    paused = false;
    if (!voice) {
      return Future<SpeechOutcome>.value(SpeechOutcome.completed);
    }
    spoken.add(_session!.steps[index].text);
    _current = Completer<SpeechOutcome>();
    return _current!.future;
  }

  @override
  Future<void> stopVoice() async {
    stops += 1;
    _current?.complete(SpeechOutcome.interrupted);
    _current = null;
  }

  @override
  Future<void> pause() async {
    pauses += 1;
    paused = true;
  }

  @override
  Future<void> resume() async {
    resumes += 1;
    paused = false;
  }

  @override
  Future<void> stop() async {
    ended += 1;
    await stopVoice();
  }

  @override
  Future<void> setAmbient(AmbientChoice choice, {bool preview = false}) async {
    ambientChoices.add(choice);
  }

  @override
  Future<void> setAmbientVolume(double volume) async {
    volumes.add(volume);
  }

  @override
  Stream<void> get interruptions => interruptController.stream;

  @override
  Future<void> dispose() async {
    disposed += 1;
    _current?.complete(SpeechOutcome.interrupted);
    _current = null;
  }

  void finishSpeaking([SpeechOutcome outcome = SpeechOutcome.completed]) {
    _current?.complete(outcome);
    _current = null;
  }
}

class FakeKeepAwake implements KeepAwakeService {
  bool enabled = false;
  int enables = 0;
  int disables = 0;

  @override
  Future<void> enable() async {
    enabled = true;
    enables += 1;
  }

  @override
  Future<void> disable() async {
    enabled = false;
    disables += 1;
  }
}

/// Keeps practices in memory instead of Firestore.
class FakeLogService extends MeditationLogService {
  /// What [getSessionsSince] returns.
  List<MeditationLogEntry> history = <MeditationLogEntry>[];
  final List<MeditationLogEntry> saved = <MeditationLogEntry>[];
  final Map<String, int> feelAfterUpdates = <String, int>{};
  bool failLoading = false;
  int _next = 0;

  @override
  String newId() => 'log-${++_next}';

  @override
  Future<void> saveSession(MeditationLogEntry entry) async {
    saved.add(entry);
  }

  @override
  Future<void> updateFeelAfter(String id, int feelAfter) async {
    feelAfterUpdates[id] = feelAfter;
  }

  @override
  Future<List<MeditationLogEntry>> getSessionsSince(DateTime start) async {
    if (failLoading) {
      throw StateError('offline');
    }
    return history;
  }
}

/// Returns the given mood as today's only entry.
class FakeMoodService extends MoodFirestoreService {
  MoodModel? todayMood;
  bool failLoading = false;

  @override
  Future<List<MoodModel>> getMoodsBetween(DateTime start, DateTime end) async {
    if (failLoading) {
      throw StateError('offline');
    }
    final MoodModel? mood = todayMood;
    return mood == null ? <MoodModel>[] : <MoodModel>[mood];
  }
}

/// The text of the real content file. It is read synchronously so it also
/// works inside a widget test's fake clock.
String fileContentLoader() =>
    File('assets/meditation/meditation_sessions.json').readAsStringSync();

/// Loads the real content file from the project.
MeditationContentService fileContentService() {
  return MeditationContentService(loader: () async => fileContentLoader());
}

MeditationRepository buildRepository(
  FakeLogService logService, {
  SettingsRepository? settings,
}) {
  return MeditationRepository(
    fileContentService(),
    logService,
    settings: settings,
  );
}

/// Three steps of 3 seconds each, for quick tests.
const MeditationSession tinySession = MeditationSession(
  id: 'test_practice',
  title: 'Test practice',
  groupId: 'on_shift',
  technique: 'Testing',
  basedOn: '',
  minutes: 0,
  posture: '',
  goodFor: '',
  about: '',
  safetyNote: '',
  steps: <MeditationStep>[
    MeditationStep(phase: 'settle', seconds: 3, text: 'one'),
    MeditationStep(phase: 'practice', seconds: 3, text: 'two'),
    MeditationStep(phase: 'close', seconds: 3, text: 'three'),
  ],
);

/// A finished practice that ended at [endedAt].
MeditationLogEntry logEntry(
  DateTime endedAt, {
  int seconds = 180,
  bool completed = true,
  String sessionId = 'arriving',
}) {
  return MeditationLogEntry(
    id: 'log-${endedAt.microsecondsSinceEpoch}-$sessionId',
    sessionId: sessionId,
    title: sessionId,
    startedAt: endedAt.subtract(Duration(seconds: seconds)),
    endedAt: endedAt,
    secondsPractised: seconds,
    completed: completed,
  );
}
