import 'dart:convert';

/// A set of related practices, shown as a filter on the library screen.
class MeditationGroup {
  const MeditationGroup({required this.id, required this.title});

  /// The group that holds the original timer-only breathing practices.
  static const String breathingId = 'breathing';
  static const MeditationGroup breathing = MeditationGroup(
    id: breathingId,
    title: 'Breathing',
  );

  final String id;
  final String title;

  factory MeditationGroup.fromMap(Map<String, dynamic> map) {
    return MeditationGroup(
      id: _requiredString(map, 'id'),
      title: _requiredString(map, 'title'),
    );
  }
}

/// One timed step of a practice. [text] is shown, and spoken when voice
/// guidance is on.
class MeditationStep {
  const MeditationStep({
    required this.phase,
    required this.seconds,
    required this.text,
  });

  /// "settle", "practice" or "close".
  final String phase;
  final int seconds;
  final String text;

  factory MeditationStep.fromMap(Map<String, dynamic> map) {
    final Object? seconds = map['seconds'];
    if (seconds is! int || seconds <= 0) {
      throw const FormatException('A step needs a positive "seconds" value.');
    }
    return MeditationStep(
      phase: _optionalString(map, 'phase'),
      seconds: seconds,
      text: _requiredString(map, 'text'),
    );
  }
}

/// A guided practice, or one of the original breathing practices.
class MeditationSession {
  const MeditationSession({
    required this.id,
    required this.title,
    required this.groupId,
    required this.technique,
    required this.basedOn,
    required this.minutes,
    required this.posture,
    required this.goodFor,
    required this.about,
    required this.safetyNote,
    required this.steps,
  });

  final String id;
  final String title;

  /// The id of the [MeditationGroup] this practice belongs to.
  final String groupId;
  final String technique;
  final String basedOn;

  /// The length written in the content file. The app shows [lengthMinutes],
  /// which is worked out from the steps.
  final int minutes;
  final String posture;
  final String goodFor;
  final String about;
  final String safetyNote;
  final List<MeditationStep> steps;

  /// Length of the whole practice, from its steps.
  int get totalSeconds => steps.fold<int>(
    0,
    (int total, MeditationStep step) => total + step.seconds,
  );

  /// [totalSeconds] in minutes, at least 1.
  int get lengthMinutes {
    final int rounded = (totalSeconds / 60).round();
    return rounded < 1 ? 1 : rounded;
  }

  /// e.g. "3 min".
  String get lengthLabel => '$lengthMinutes min';

  /// The original timer-only practices: one timed step, nothing to read out.
  bool get isBreathing => groupId == MeditationGroup.breathingId;

  /// Whether the steps can be read aloud.
  bool get hasVoice => !isBreathing;

  factory MeditationSession.fromMap(Map<String, dynamic> map) {
    final Object? rawSteps = map['steps'];
    if (rawSteps is! List || rawSteps.isEmpty) {
      throw FormatException('Practice "${map['id']}" has no steps.');
    }
    final Object? minutes = map['minutes'];

    return MeditationSession(
      id: _requiredString(map, 'id'),
      title: _requiredString(map, 'title'),
      groupId: _requiredString(map, 'group'),
      technique: _optionalString(map, 'technique'),
      basedOn: _optionalString(map, 'basedOn'),
      minutes: minutes is int ? minutes : 0,
      posture: _optionalString(map, 'posture'),
      goodFor: _optionalString(map, 'goodFor'),
      about: _optionalString(map, 'about'),
      safetyNote: _optionalString(map, 'safetyNote'),
      steps: List<MeditationStep>.unmodifiable(
        rawSteps.map(
          (Object? step) =>
              MeditationStep.fromMap((step as Map).cast<String, dynamic>()),
        ),
      ),
    );
  }
}

/// Everything in the content file.
class MeditationContent {
  const MeditationContent({required this.groups, required this.sessions});

  final List<MeditationGroup> groups;
  final List<MeditationSession> sessions;

  /// Parses the content file. Throws a [FormatException] if it is not valid.
  factory MeditationContent.fromJson(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The practice file is not a JSON object.');
    }
    final Object? groups = decoded['groups'];
    final Object? sessions = decoded['sessions'];
    if (groups is! List || sessions is! List) {
      throw const FormatException(
        'The practice file needs "groups" and "sessions" lists.',
      );
    }

    return MeditationContent(
      groups: List<MeditationGroup>.unmodifiable(
        groups.map(
          (Object? group) =>
              MeditationGroup.fromMap((group as Map).cast<String, dynamic>()),
        ),
      ),
      sessions: List<MeditationSession>.unmodifiable(
        sessions.map(
          (Object? session) => MeditationSession.fromMap(
            (session as Map).cast<String, dynamic>(),
          ),
        ),
      ),
    );
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final Object? value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing "$key" in the practice file.');
  }
  return value;
}

String _optionalString(Map<String, dynamic> map, String key) {
  final Object? value = map[key];
  return value is String ? value : '';
}
