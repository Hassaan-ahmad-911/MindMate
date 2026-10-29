import 'dart:convert';

/// The one unsaved entry kept on the phone while the user writes.
class JournalDraft {
  const JournalDraft({
    required this.type,
    required this.title,
    required this.answers,
    required this.body,
    this.prompt,
    this.moodId,
    this.moodLabel,
    this.moodIntensity,
    this.moodChosen = false,
    required this.savedAt,
  });

  final String type;
  final String title;

  /// Question id -> answer, for guided types.
  final Map<String, String> answers;
  final String body;

  /// The prompt it was started from, if any.
  final String? prompt;
  final String? moodId;
  final String? moodLabel;
  final String? moodIntensity;

  /// True once the user picked a mood (or "No mood") themselves, so the
  /// latest mood is not linked again on top of their choice.
  final bool moodChosen;
  final DateTime savedAt;

  bool get hasText =>
      title.trim().isNotEmpty ||
      body.trim().isNotEmpty ||
      answers.values.any((String a) => a.trim().isNotEmpty);

  String encode() => jsonEncode(<String, dynamic>{
    'type': type,
    'title': title,
    'answers': answers,
    'body': body,
    'prompt': prompt,
    'moodId': moodId,
    'moodLabel': moodLabel,
    'moodIntensity': moodIntensity,
    'moodChosen': moodChosen,
    'savedAt': savedAt.toIso8601String(),
  });

  /// Null if [source] is not a draft (for example, written by an older app).
  static JournalDraft? decode(String? source) {
    if (source == null || source.isEmpty) {
      return null;
    }
    try {
      final Object? map = jsonDecode(source);
      if (map is! Map<String, dynamic>) {
        return null;
      }
      final Object? answers = map['answers'];
      String? text(String key) =>
          map[key] is String ? map[key] as String : null;
      return JournalDraft(
        type: text('type') ?? 'free',
        title: text('title') ?? '',
        answers: answers is Map
            ? <String, String>{
                for (final MapEntry<dynamic, dynamic> e in answers.entries)
                  e.key.toString(): e.value?.toString() ?? '',
              }
            : const <String, String>{},
        body: text('body') ?? '',
        prompt: text('prompt'),
        moodId: text('moodId'),
        moodLabel: text('moodLabel'),
        moodIntensity: text('moodIntensity'),
        moodChosen: map['moodChosen'] == true,
        savedAt: DateTime.tryParse(text('savedAt') ?? '') ?? DateTime.now(),
      );
    } on FormatException {
      return null;
    }
  }
}
