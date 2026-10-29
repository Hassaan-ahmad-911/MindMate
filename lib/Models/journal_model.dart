import 'package:cloud_firestore/cloud_firestore.dart';

import 'journal_content.dart';
import 'mood_catalog.dart';

/// The tone of an entry, read on the phone from its words. It describes the
/// entry, never the person: it is not a mood score or a result.
enum JournalTone {
  light('light'),
  mixed('mixed'),
  heavy('heavy');

  const JournalTone(this.id);

  /// Stored in Firestore and used as the key in the content file.
  final String id;

  static JournalTone? fromId(Object? value) {
    for (final JournalTone tone in values) {
      if (tone.id == value) {
        return tone;
      }
    }
    return null;
  }
}

/// One answer to a guided question.
class JournalAnswer {
  const JournalAnswer({
    required this.questionId,
    required this.question,
    required this.text,
  });

  final String questionId;
  final String question;
  final String text;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'questionId': questionId,
    'question': question,
    'text': text,
  };

  factory JournalAnswer.fromMap(Map<String, dynamic> map) {
    return JournalAnswer(
      questionId: map['questionId']?.toString() ?? '',
      question: map['question']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
    );
  }
}

/// A journal entry, stored at `users/{uid}/journals/{id}`.
class JournalModel {
  const JournalModel({
    this.id = '',
    required this.title,
    required this.type,
    this.answers = const <JournalAnswer>[],
    required this.body,
    this.moodId,
    this.moodLabel,
    this.moodIntensity,
    this.tone,
    this.toneScore,
    this.topics = const <String>[],
    required this.wordCount,
    required this.createdAt,
    required this.updatedAt,
    this.needsAnalysis = false,
  });

  static const int titleMaxLength = 80;
  static const int bodyMaxLength = 5000;

  /// Firestore document id. Empty until the entry is saved.
  final String id;
  final String title;

  /// One of [JournalTypes].
  final String type;

  /// For guided types; empty for free writing.
  final List<JournalAnswer> answers;

  /// The free text, or for guided types the answers joined with blank lines.
  final String body;
  final String? moodId;

  /// One of the 15 moods, e.g. "Tired".
  final String? moodLabel;

  /// "Mild", "Moderate" or "Strong".
  final String? moodIntensity;

  /// Null when the entry is too short to read.
  final JournalTone? tone;

  /// -2 to 2. Kept for reports and the marker on the Saved screen; the number
  /// itself is never shown.
  final double? toneScore;

  /// Up to 3 topic names from the content file.
  final List<String> topics;
  final int wordCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// True for an entry written before tone and topics existed. They are
  /// worked out the first time it is opened or edited.
  final bool needsAnalysis;

  MoodGroup? get moodGroup {
    final String? label = moodLabel;
    if (label == null) {
      return null;
    }
    return MoodCatalog.find(label)?.group;
  }

  bool get hasMood => moodLabel != null && moodLabel!.trim().isNotEmpty;

  /// "Edited" shows only when the entry changed more than a minute after it
  /// was written.
  bool get wasEdited =>
      updatedAt.difference(createdAt) > const Duration(minutes: 1);

  /// The body on one line, for the preview on the list.
  String get preview => body.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Words in [text], as counted under the editor.
  static int countWords(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    return trimmed.split(RegExp(r'\s+')).length;
  }

  /// [title] trimmed, or the first 6 words of [body] when it is empty.
  static String titleOrFallback(String title, String body) {
    String result = title.trim();
    if (result.isEmpty) {
      result = body.trim().split(RegExp(r'\s+')).take(6).join(' ');
    }
    if (result.isEmpty) {
      result = 'Untitled entry';
    }
    if (result.length > titleMaxLength) {
      result = result.substring(0, titleMaxLength).trimRight();
    }
    return result;
  }

  /// The answers that have text, joined with blank lines.
  static String joinAnswers(List<JournalAnswer> answers) {
    return answers
        .map((JournalAnswer a) => a.text.trim())
        .where((String text) => text.isNotEmpty)
        .join('\n\n');
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'type': type,
      'answers': answers.map((JournalAnswer a) => a.toMap()).toList(),
      'body': body,
      'moodId': moodId,
      'moodLabel': moodLabel,
      'moodIntensity': moodIntensity,
      'tone': tone?.id,
      'toneScore': toneScore,
      'topics': topics,
      'wordCount': wordCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Reads a stored entry. Old documents (with `content` and an emoji mood)
  /// become free writes with [needsAnalysis] set.
  factory JournalModel.fromMap(Map<String, dynamic> map, {String id = ''}) {
    final String body = (map['body'] ?? map['content'])?.toString() ?? '';
    final DateTime createdAt = readDate(map['createdAt']) ?? DateTime.now();
    final Object? storedMood = map['moodLabel'];
    final String? moodLabel =
        storedMood is String && storedMood.trim().isNotEmpty
        ? MoodCatalog.normalizeName(storedMood)
        : null;
    final Object? intensity = map['moodIntensity'];
    final Object? score = map['toneScore'];
    final Object? words = map['wordCount'];

    return JournalModel(
      id: id,
      title: titleOrFallback(map['title']?.toString() ?? '', body),
      type: JournalTypes.normalize(map['type']),
      answers: _readAnswers(map['answers']),
      body: body,
      moodId: map['moodId'] is String ? map['moodId'] as String : null,
      moodLabel: moodLabel,
      moodIntensity: intensity is String && intensity.isNotEmpty
          ? MoodCatalog.normalizeIntensity(intensity)
          : null,
      tone: JournalTone.fromId(map['tone']),
      toneScore: score is num ? score.toDouble().clamp(-2.0, 2.0) : null,
      topics: _readStrings(map['topics']),
      wordCount: words is num ? words.round() : countWords(body),
      createdAt: createdAt,
      updatedAt: readDate(map['updatedAt']) ?? createdAt,
      needsAnalysis: words is! num,
    );
  }

  /// The new-format document for an entry from the old top-level `journals`
  /// collection. Keeps `createdAt`; `updatedAt` is the old value or
  /// `createdAt`. Tone and topics are left for the first open.
  static Map<String, dynamic> fromLegacyMap(Map<String, dynamic> old) {
    final String body = (old['body'] ?? old['content'])?.toString() ?? '';
    final Object? createdAt = old['createdAt'] is Timestamp
        ? old['createdAt']
        : Timestamp.fromDate(readDate(old['createdAt']) ?? DateTime.now());
    final Object? updatedAt = old['updatedAt'] is Timestamp
        ? old['updatedAt']
        : createdAt;
    final Object? mood = old['moodLabel'];

    return <String, dynamic>{
      'title': titleOrFallback(old['title']?.toString() ?? '', body),
      'type': JournalTypes.free,
      'answers': const <Map<String, dynamic>>[],
      'body': body.length > bodyMaxLength
          ? body.substring(0, bodyMaxLength)
          : body,
      if (mood is String && mood.trim().isNotEmpty)
        'moodLabel': MoodCatalog.normalizeName(mood),
      'topics': const <String>[],
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  JournalModel copyWith({
    String? id,
    String? title,
    String? type,
    List<JournalAnswer>? answers,
    String? body,
    String? Function()? moodId,
    String? Function()? moodLabel,
    String? Function()? moodIntensity,
    JournalTone? Function()? tone,
    double? Function()? toneScore,
    List<String>? topics,
    int? wordCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? needsAnalysis,
  }) {
    return JournalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      answers: answers ?? this.answers,
      body: body ?? this.body,
      moodId: moodId != null ? moodId() : this.moodId,
      moodLabel: moodLabel != null ? moodLabel() : this.moodLabel,
      moodIntensity: moodIntensity != null
          ? moodIntensity()
          : this.moodIntensity,
      tone: tone != null ? tone() : this.tone,
      toneScore: toneScore != null ? toneScore() : this.toneScore,
      topics: topics ?? this.topics,
      wordCount: wordCount ?? this.wordCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      needsAnalysis: needsAnalysis ?? this.needsAnalysis,
    );
  }

  static DateTime? readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static List<JournalAnswer> _readAnswers(Object? value) {
    if (value is! List) {
      return const <JournalAnswer>[];
    }
    return List<JournalAnswer>.unmodifiable(
      value.whereType<Map>().map(
        (Map item) => JournalAnswer.fromMap(item.cast<String, dynamic>()),
      ),
    );
  }

  static List<String> _readStrings(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return List<String>.unmodifiable(
      value.whereType<String>().where((String s) => s.trim().isNotEmpty),
    );
  }
}

/// The parts of an entry that reports need: no title text beyond the title,
/// no body. Returned by `JournalRepository.getEntriesBetween`.
class JournalSummary {
  const JournalSummary({
    required this.id,
    required this.title,
    required this.type,
    required this.tone,
    required this.toneScore,
    required this.topics,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String type;
  final JournalTone? tone;
  final double? toneScore;
  final List<String> topics;
  final DateTime createdAt;

  factory JournalSummary.fromEntry(JournalModel entry) {
    return JournalSummary(
      id: entry.id,
      title: entry.title,
      type: entry.type,
      tone: entry.tone,
      toneScore: entry.toneScore,
      topics: entry.topics,
      createdAt: entry.createdAt,
    );
  }
}

/// One page of entries, newest first.
class JournalPage {
  const JournalPage({
    required this.entries,
    required this.cursor,
    required this.hasMore,
  });

  final List<JournalModel> entries;

  /// Pass back to get the next page. Opaque to callers (a Firestore
  /// document snapshot here).
  final Object? cursor;
  final bool hasMore;
}
